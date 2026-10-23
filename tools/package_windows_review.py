"""Build a standalone Windows playtest and verify its UI and optional mining flow."""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

from run_checks import isolated_environment

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "artifacts" / "windows-build"


def run(command, environment, label, timeout=120, cwd=ROOT, visible=False):
    startupinfo = None
    if os.name == "nt":
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 5 if visible else subprocess.SW_HIDE  # Win32 SW_SHOW
    process = subprocess.run(command, cwd=cwd, env=environment, capture_output=True,
                             text=True, encoding="utf-8", errors="replace", timeout=timeout,
                             startupinfo=startupinfo)
    output = process.stdout + process.stderr
    (BUILD / f"{label}.log").write_text(output, encoding="utf-8")
    checked = re.sub(
        r"ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\r?\n?",
        "", output,
    ) if os.name == "nt" else output
    if process.returncode != 0 or "ERROR:" in checked:
        raise RuntimeError(f"{label} failed ({process.returncode}):\n{output[-10000:]}")
    print(f"{label}: passed", flush=True)
    return output


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_snapshot():
    paths = [ROOT / name for name in ("project.godot", "main.tscn", "export_presets.cfg")]
    for directory in ("scripts", "shaders", "data", "assets"):
        paths.extend(path for path in (ROOT / directory).rglob("*")
                     if path.is_file() and path.suffix not in (".uid", ".import"))
    return {path.relative_to(ROOT).as_posix(): sha256(path) for path in sorted(paths)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot 4.6.3 editor executable")
    parser.add_argument("--label", default="", help="Optional build suffix, such as fusion")
    parser.add_argument("--benchmark", action="store_true", help="Measure 80-actor excavation and a longer 24-actor expedition in the actual exported EXE")
    parser.add_argument("--visible-benchmark", action="store_true", help="Show native benchmark windows for foreground GPU measurements")
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error("Godot executable not found")
    template = BUILD / "templates" / "windows_release_x86_64.exe"
    if not template.is_file():
        parser.error(f"Official Godot 4.6.3 Windows x64 export template required: {template}")
    BUILD.mkdir(parents=True, exist_ok=True)
    (ROOT / "artifacts" / ".gdignore").touch(exist_ok=True)
    stamp = datetime.now(timezone(timedelta(hours=8))).strftime("%Y%m%d")
    if args.label and not re.fullmatch(r"[a-zA-Z0-9-]+", args.label):
        parser.error("--label accepts only letters, digits and hyphens")
    suffix = f"-{args.label}" if args.label else ""
    package = ROOT / "artifacts" / f"Centipede-Review-{stamp}{suffix}"
    if package.exists():
        parser.error(f"Package directory already exists; retain or rename it before rebuilding: {package}")
    package.mkdir()
    executable = package / "RunBuildPew.exe"
    sources = source_snapshot()
    # Import/export and all runtime checks use disposable profiles, never the
    # local player's progress. The GDScript guard verifies this before loading.
    import tempfile
    with tempfile.TemporaryDirectory(prefix="centipede-windows-build-") as temporary:
        scratch = Path(temporary).resolve()
        environment = isolated_environment(scratch)
        run([godot, "--headless", "--path", str(ROOT), "--editor", "--import"], environment, "import")
        run([godot, "--headless", "--path", str(ROOT), "--export-release", "Windows Review", str(executable)],
            environment, "export")
        if not executable.is_file() or executable.stat().st_size <= template.stat().st_size:
            raise RuntimeError("Export did not embed the game data")
        if source_snapshot() != sources:
            raise RuntimeError("Runtime sources changed during export; rebuild from the updated files")
        # Official export templates disable CLI script/path overrides. The
        # review-only entry point runs the same guarded probe as editor tests.
        verification = isolated_environment(scratch / "verification")
        verification["RBPEW_TEST_EXPORTED"] = "1"
        output = run([str(executable), "--audio-driver", "Dummy", "--windowed", "--resolution", "1440x900",
                      "--position", "-10000,-10000", "--fixed-fps", "60", "--", "--review-ui-check"],
                     verification, "exported-ui-test", timeout=90)
        records = []
        for line in output.splitlines():
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(value, dict) and "checks" in value:
                records.append(value)
        if not records or not records[-1]["passed"] or not records[-1]["exported"]:
            raise RuntimeError("Actual exported Debug/two-character UI validation did not pass")
        report = records[-1]
        for capture in report["captures"]:
            shutil.copy2(capture, BUILD / Path(capture).name)
        (BUILD / "exported-ui-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        cave_report = None
        if args.label.startswith("mining"):
            cave_output = run(
                [str(executable), "--audio-driver", "Dummy", "--windowed", "--resolution", "1440x900",
                 "--position", "-10000,-10000", "--fixed-fps", "60", "--", "--review-cave-check"],
                isolated_environment(scratch / "cave-verification"), "exported-cave-test", timeout=90,
            )
            for line in cave_output.splitlines():
                try:
                    candidate = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(candidate, dict) and "mined_cells" in candidate:
                    cave_report = candidate
            if not cave_report or not cave_report["passed"] or not cave_report["exported"]:
                raise RuntimeError("Actual exported excavation, ore, body-following and monster chase validation failed")
            for capture in cave_report["captures"]:
                shutil.copy2(capture, BUILD / Path(capture).name)
            (BUILD / "exported-cave-report.json").write_text(json.dumps(cave_report, ensure_ascii=False, indent=2), encoding="utf-8")
        native_performance = {}
        if args.benchmark:
            for case, actors, frames in (("stress-80",80,240),("excavation-24",24,2400)):
                profile = isolated_environment(scratch / ("native-"+case))
                profile.update({"RBPEW_MINING_ACTORS":str(actors),"RBPEW_MINING_FRAMES":str(frames)})
                if case=="excavation-24":profile.update({"RBPEW_MINING_MISSION":"Endless Mission","RBPEW_MINING_ROUTE":"excavate"})
                output = run([str(executable),"--audio-driver","Dummy","--windowed","--resolution","1440x900",
                              "--position","80,50" if args.visible_benchmark else "-10000,-10000","--fixed-fps","60","--","--review-performance-check"],
                             profile,"native-performance-"+case,timeout=120,visible=args.visible_benchmark)
                records = []
                for line in output.splitlines():
                    try:
                        record = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if isinstance(record,dict) and "native_performance_report" in record:records.append(record)
                if not records or not records[-1]["passed"] or not records[-1]["exported"]:
                    raise RuntimeError("Native exported performance fixture failed: "+case)
                record = json.loads(Path(records[-1]["native_performance_report"]).read_text(encoding="utf-8"))
                record["visible_window"]=args.visible_benchmark
                for capture in record["captures"]:
                    shutil.copy2(capture,BUILD/("native-performance-"+case+".png"))
                (BUILD/("native-performance-"+case+".json")).write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding="utf-8")
                native_performance[case] = {key:record[key] for key in ("conditions","frame_ms","cpu_ms","bite_frame_ms","drop_frame_ms","counter","mined_cells","ore_value")}
        # Also launch the unmodified shipped entry point with a fresh profile.
        clean_profile = isolated_environment(scratch / "normal-launch")
        exit_output = run([str(executable), "--audio-driver", "Dummy", "--windowed", "--resolution", "1440x900",
                           "--position", "-10000,-10000", "--fixed-fps", "60", "--", "--review-exit-check"],
                          clean_profile, "normal-launch", timeout=45)
        if '"startup_exit":true' not in exit_output or '"passed":true' not in exit_output or '"passed":false' in exit_output:
            raise RuntimeError("Normal entry point/exit button validation did not pass")
    quickstart = f"""蜈蚣：逐节武装 · 性能与加载进度试玩
Windows 64 位 / {stamp[:4]}-{stamp[4:6]}-{stamp[6:]}

启动
将 ZIP 解压到一个文件夹，双击 RunBuildPew.exe。
游戏资源已装进 EXE，无需安装 Godot。

先试玩挖矿
选择「蜈蚣」并出击。起点是一间洞室，右侧黑白岩壁中有带少量青蓝矿粒的碎岩矿斑，北侧有现成绕路。
按住方向顶住岩壁，头部会自动啃挖；挖穿后可以前进，身体沿新洞道跟进。
普通挖掘免费，松开方向就停止；有燃料时按 Shift 可以加快钻进。
窄道里按与头部朝向相反的方向，可以沿来路后退。
矿脉会逐步掉出原有能量水晶，沿用拾取与蜂群搬运；普通岩层主要提供路线变化。
怪物也会走你挖出的新通道，岩壁会挡住普通子弹。黑色深坑继续不可通行、不可开挖。
首版洞穴地图用于蜈蚣；蜘蛛保留现有地图。每次重开会生成完整岩层，本局挖掘不会跨局保存。

一键开放全部内容
主菜单 →「DEBUG · 一键全开」。
全部角色、技能奖励、进化阶段及任务立即解锁并自动保存。
点击「虫巢」，选择蜈蚣或蜘蛛，再点「前往远征」→「出发」。
也可以直接点击「出击」，体验普通成长过程。
解锁与角色选择会自动保存，下一次启动仍然有效。
设置里重置进度后，可以再次点击首页 Debug 按钮开放全部内容。

操作
WASD：移动；默认自动开火；按住鼠标左键可手动瞄准主武器。
Shift：加速；空格：角色技能；E：装配；Esc：暂停。
Tab / 鼠标右键：雷达。
蜈蚣：盘绕聚火；蜘蛛：软丝牵引。
新元素奖励可以装上身体；在装配窗口拖动调整位置，手动完成后继续战斗。
获得奖励时自动暂停并弹出三选一。选到模块后进入装配，属性奖励立即生效。
拖动整节到前后侧：相邻节段平滑让位，松手插入。
拖到同元素、同阶节段的中央：二合一进化，最高四阶。
每次合成单节攻击 ×2.2；二/三/四阶分别有 2/4/6 条侧鞭毛。
拖动时按 Esc 或右键取消；装配完成后手动点「出击」。

本版内容
撞墙扫描发现近处首次接触后，跳过后方不可能影响结果的岩石；保留原碰撞位置、法线和挖掘形状。
原地顶墙时复用已确认无岩石重叠的精确位置和半径；缓存有数量上限，重开后清空。
怪物受击回弹只跳过已证明不会改变结果的约束检查，保留完整回弹、余震和受击反馈。
卵环的原图、光圈和光晕各合为一个绘制批次，保留每枚卵的颜色、位置、数量和触碰爆炸。
远处裂隙按原有区域复用同一组碰撞几何，减少地图守卫和据点每帧重复枚举；缓存有上限，重开时清空。
岩壁描线使用抗锯齿网格，减少重复三角形；挖掘只更新变化的小块，保持现有岩石和露色矿粒。
提前分批准备镜头前方的岩层；新区域的完整敌人队形也先分批准备碰撞，再生成，减少换区停顿。
出击时显示实际加载阶段和完成数量，分帧准备矿区、整屏岩层与虫群素材，完成后自动进入。
岩壁轮廓、碎石和裂纹合并绘制，碰撞只检查暴露的岩边，远处小虫使用轻量动画。
近身、受击、牵引和死亡继续使用完整骨骼；加载阶段预热首次开火和命中的渲染路径。
洞穴矿脉替代旧版独立巨石矿场，减少进图时反复寻找巨石出生位置的耗时。
右下角新增实时 FPS 与平均每帧毫秒数；1s MAX 表示最近一秒最慢一帧的耗时，便于观察短暂卡顿。
DC 为当前整帧 draw call 数量，和帧率一起每秒刷新四次。
60 FPS 约为 16.7 ms/帧，30 FPS 约为 33.3 ms/帧；读数每秒刷新四次，暂停时继续显示。
挖穿岩层时分批更新怪物寻路；啃挖裂纹单独更新，岩壁绘制缓存复用，减少掉矿时的卡顿。
连续岩壁增加固定在世界坐标的凹凸、崩口、断续浅边和少量裂纹碎石；弧形啃挖保留自然的洞口和转弯。
矿物采用 A 方案：黑白碎岩中嵌着大小不一的矿粒，少量露出青蓝、暗金或灰粉色，提示可开采资源。
露出的矿粒颜色更鲜明，露色面积不变，正常游戏倍率下更容易认出；普通岩石仍保持黑白。
六种手绘矿斑变体按整团矿床分布，随真实岩壁裁切，挖掉的位置不会残留矿粒；矿斑绘制和裁切结果继续缓存。
画面与身体、子弹和怪物碰撞共用岩层形状；细小斜边挡住前进时同样可以啃开，避免顶住碎岩后停挖。
正俯视灰白排线岩层、窄边缘阴影、顶墙啃挖、嵌入矿脉、逐步掉矿与新洞道寻路。
支持长身体跟随、窄道后退，盘绕技能在狭窄空间保持地形约束。
炽嗉改为连续柔性鞭体；拾取蜂群会减速靠近水晶并带回，已送达的水晶不会再次被占用。
敌方弹丸改为细胞膜与内核的孢子形态；奖励包、资源容器和虫巢底座换为生物囊体。
首领使用骨白/桃红边缘方向指引和距离；致命命中后播放约 1.15 秒慢镜头再显示结算。
黑白排线地形与虫体美术；武器、子弹和攻击效果保留原色。
带白色崖壁的大块黑色深坑不可通行，玩家和怪物都会受到岸线阻挡。
矿石从弹着点逐渐崩解，不显示血条，子弹能穿过已经开采出的缺口。
5 / 10 连杀返还技能冷却；18 连杀触发 6 秒狂热，伤害 +25%、装填 +35%。
特殊敌人：蓄力后锁定方向的冲锋虫、死亡分裂的母虫、限时追猎的藏宝虫。
装配界面身上元素已放大到与战斗中一致的相对比例，拖动预览同步。
特殊敌人、预警及相关 HUD 使用 ImageGen 贴图与现有骨骼动画。

存档保存在 Windows 当前账户的 Godot 应用数据目录。
本包包含 Debug 解锁功能，供内部体验。
"""
    (package / "先读我.txt").write_text(quickstart, encoding="utf-8-sig")
    licenses = package / "Licenses"
    licenses.mkdir()
    shutil.copy2(ROOT / "distribution" / "GODOT_LICENSE.txt", licenses)
    shutil.copy2(ROOT / "assets" / "fonts" / "NotoSansCJK-LICENSE.txt", licenses)
    notices = """Godot Engine license: GODOT_LICENSE.txt
Godot Engine third-party license information: https://godotengine.org/license/
Noto Sans CJK font license: NotoSansCJK-LICENSE.txt
This experimental game uses recovered Run Build Pew! source assets. Those
assets retain their original rights; the Godot MIT license applies to the
engine, not to the original game assets. This package is for internal playtesting.
"""
    (licenses / "NOTICE.txt").write_text(notices, encoding="utf-8")
    manifest = {
        "package": package.name,
        "engine": "Godot 4.6.3.stable",
        "platform": "Windows x86_64",
        "embedded_game_data": True,
        "source_files_sha256": sources,
        "debug_unlock": {"location": "home", "characters": ["centipede", "spider"],
                         "skills": "all", "evolution_tiers": "all", "missions": "all"},
        "files": {path.relative_to(package).as_posix(): {"bytes": path.stat().st_size, "sha256": sha256(path)}
                  for path in package.rglob("*") if path.is_file()},
        "validated_checks": len(report["checks"]) + (len(cave_report["checks"]) if cave_report else 0),
        "cave_mining_validation": cave_report,
        "native_performance": native_performance,
    }
    (package / "build-info.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    archive = package.with_suffix(".zip")
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in sorted(package.rglob("*")):
            if path.is_file():
                bundle.write(path, Path(package.name) / path.relative_to(package))
    with zipfile.ZipFile(archive) as bundle:
        if bundle.testzip() is not None:
            raise RuntimeError("ZIP integrity check failed")
        if any(name.endswith(("centipede-save.json", ".log", ".gd", ".tmp")) for name in bundle.namelist()):
            raise RuntimeError("Package unexpectedly contains profile or test files")
        with tempfile.TemporaryDirectory(prefix="centipede-review-unpacked-") as temporary:
            scratch = Path(temporary).resolve()
            bundle.extractall(scratch)
            unpacked = scratch / package.name
            unpacked_output = run([str(unpacked / executable.name), "--audio-driver", "Dummy", "--windowed",
                                   "--resolution", "1440x900", "--position", "-10000,-10000", "--fixed-fps", "60",
                                   "--", "--review-exit-check"], isolated_environment(scratch / "profile-check"),
                                  "unpacked-launch", timeout=45, cwd=unpacked)
            if '"startup_exit":true' not in unpacked_output or '"passed":true' not in unpacked_output or '"passed":false' in unpacked_output:
                raise RuntimeError("Independent unpacked entry point/exit button validation did not pass")
    delivery = {"archive": str(archive), "executable": str(executable), "bytes": archive.stat().st_size,
                "sha256": sha256(archive), "passed": True, "unpacked_launch": True,
                "validated_checks": len(report["checks"]) + (len(cave_report["checks"]) if cave_report else 0),
                "cave_mining_validated": bool(cave_report and cave_report["passed"])}
    delivery["native_performance"] = native_performance
    (BUILD / "delivery-report.json").write_text(json.dumps(delivery, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(delivery, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
