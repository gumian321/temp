"""Build a standalone Windows playtest EXE and verify its actual Debug UI."""
import argparse
from datetime import date
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


def run(command, environment, label, timeout=120, cwd=ROOT):
    startupinfo = None
    if os.name == "nt":
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = subprocess.SW_HIDE
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot 4.6.3 editor executable")
    parser.add_argument("--label", default="", help="Optional build suffix, such as fusion")
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error("Godot executable not found")
    template = BUILD / "templates" / "windows_release_x86_64.exe"
    if not template.is_file():
        parser.error(f"Official Godot 4.6.3 Windows x64 export template required: {template}")
    BUILD.mkdir(parents=True, exist_ok=True)
    (ROOT / "artifacts" / ".gdignore").touch(exist_ok=True)
    stamp = date.today().strftime("%Y%m%d")
    if args.label and not re.fullmatch(r"[a-zA-Z0-9-]+", args.label):
        parser.error("--label accepts only letters, digits and hyphens")
    suffix = f"-{args.label}" if args.label else ""
    package = ROOT / "artifacts" / f"Centipede-Review-{stamp}{suffix}"
    if package.exists():
        parser.error(f"Package directory already exists; retain or rename it before rebuilding: {package}")
    package.mkdir()
    executable = package / "RunBuildPew.exe"
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
        # Also launch the unmodified shipped entry point with a fresh profile.
        clean_profile = isolated_environment(scratch / "normal-launch")
        exit_output = run([str(executable), "--audio-driver", "Dummy", "--windowed", "--resolution", "1440x900",
                           "--position", "-10000,-10000", "--fixed-fps", "60", "--", "--review-exit-check"],
                          clean_profile, "normal-launch", timeout=45)
        if '"startup_exit":true' not in exit_output or '"passed":true' not in exit_output or '"passed":false' in exit_output:
            raise RuntimeError("Normal entry point/exit button validation did not pass")
    quickstart = """蜈蚣：逐节武装 · 同事体验版
Windows 64 位 / 2026-10-14

启动
将 ZIP 解压到一个文件夹，双击 RunBuildPew.exe。
游戏资源已装进 EXE，无需安装 Godot。

体验双角色
主菜单 → 虫巢 → 右上角「DEBUG · 解锁双角色」。
点选蜈蚣或蜘蛛，再点「前往远征」→「出发」。
解锁与角色选择会自动保存，下一次启动仍然有效。
设置里重置进度后，可以再次点击 Debug 按钮开放角色。

操作
WASD：移动；鼠标：瞄准；左键：主武器射击。
Shift：加速；空格：角色技能；E：装配；Esc：暂停。
Tab / 鼠标右键：雷达。
蜈蚣：蜷缩聚火；蜘蛛：织网牵引。
新元素奖励可以装上身体；在装配窗口拖动调整位置，手动完成后继续战斗。
拖动整节到前后侧：相邻节段平滑让位，松手插入。
拖到同元素、同阶节段的中央：二合一进化，最高四阶。
每次合成单节攻击 ×2.2；二/三/四阶分别有 2/3/4 条侧鞭毛。
拖动时按 Esc 或右键取消；装配完成后手动点「出击」。

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
        "debug_unlock": ["centipede", "spider"],
        "files": {path.relative_to(package).as_posix(): {"bytes": path.stat().st_size, "sha256": sha256(path)}
                  for path in package.rglob("*") if path.is_file()},
        "validated_checks": len(report["checks"]),
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
                "validated_checks": len(report["checks"])}
    (BUILD / "delivery-report.json").write_text(json.dumps(delivery, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(delivery, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
