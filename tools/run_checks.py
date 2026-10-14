"""Run bounded Godot checks with a fresh, verified user-data directory per suite."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SUITES = [
    "radial_formations", "crystal_loot_scene", "hostile_readability", "soft_organs", "fusion_flagella", "camera_stability_scene", "centipede_coil", "centipede_coil_scene", "character_selection", "debug_characters", "direct_body_assembly", "insect_projectiles",
    "spider_leg_modules", "spider_rig", "spider_segments", "spider_visibility_scene", "spider_assembly_ui", "spider_motion_scene", "expedition_briefing", "character_roster", "character_abilities", "character_integration", "character_scene", "character_ui_integration", "brood", "armament_art", "generated_light_ui", "main_autofire", "main_autofire_scene", "passive_feedback_state", "passive_upgrade_effects", "passive_visual_feedback", "reward_progress_badges", "tooltip_theme", "contact_impacts", "insect_armaments", "insect_art_routes", "insect_controls", "insect_attack_fx", "game_ui_shell", "meta_ui_redesign", "battle_hud", "reward_cards", "mission_select",
    "core", "missions", "map", "rewards", "specials", "regressions", "drones",
    "reward_pool", "controller", "long_body", "shields", "turret_tracking",
    "achievements", "fuel_tutorial", "enemy_drones", "radar", "weapon_catalog",
    "particles", "presentation", "loot", "centipede_segments", "centipede_support", "chinese", "chain_segments", "chain_scene", "chain_ui_redesign", "segment_feedback", "reward_flow", "blue_ink", "grid_mounts", "centipede_motion", "weapon_feedback", "weapon_readability",
]


def isolated_environment(scratch: Path) -> dict[str, str]:
    """Godot uses APPDATA on Windows and XDG data locations on Linux."""
    directories = {
        "APPDATA": scratch / "roaming",
        "LOCALAPPDATA": scratch / "local",
        "USERPROFILE": scratch / "profile",
        "HOME": scratch / "profile",
        "XDG_DATA_HOME": scratch / "data",
        "XDG_CONFIG_HOME": scratch / "config",
        "XDG_CACHE_HOME": scratch / "cache",
        "TEMP": scratch / "tmp",
        "TMP": scratch / "tmp",
        "TMPDIR": scratch / "tmp",
    }
    for directory in directories.values():
        directory.mkdir(parents=True, exist_ok=True)
    return os.environ | {key: str(value) for key, value in directories.items()} | {
        "RBPEW_TEST_SANDBOX": scratch.as_posix(),
    }


def run_suite(godot: str, name: str, timeout: float, render: bool, verbose: bool = False) -> dict:
    script = ROOT / "tests" / f"test_{name}.gd"
    if not script.is_file():
        return {"suite": name, "passed": False, "error": f"Missing test: {script}"}
    start = time.monotonic()
    output = ""
    # A subclass guard runs before the suite's _initialize(), including before a
    # SaveStore or main scene is instantiated. Never trust env overrides alone.
    with tempfile.TemporaryDirectory(prefix="centipede-checks-") as directory:
        scratch = Path(directory).resolve()
        environment = isolated_environment(scratch)
        wrapper = scratch / "guarded_suite.gd"
        wrapper.write_text(
            f'extends "res://tests/test_{name}.gd"\n'
            'func _initialize():\n'
            '\tvar expected = OS.get_environment("RBPEW_TEST_SANDBOX").replace("\\\\", "/").to_lower() + "/"\n'
            '\tvar actual = OS.get_user_data_dir().replace("\\\\", "/").to_lower() + "/"\n'
            '\tif not actual.begins_with(expected):\n'
            '\t\tprinterr("ERROR: Refusing test outside isolated user directory: ", actual)\n'
            '\t\tquit(2)\n'
            '\t\treturn\n'
            '\tprint("TEST_USER_DIR=", OS.get_user_data_dir())\n'
            '\tsuper._initialize()\n',
            encoding="utf-8",
        )
        command = [godot, "--path", str(ROOT), "--log-file", str(scratch / "godot.log")]
        if verbose:
            command.append("--verbose")
        if render:
            command += ["--audio-driver", "Dummy", "--windowed", "--resolution", "1440x900",
                        "--position", "-10000,-10000", "--fixed-fps", "60"]
        else:
            command += ["--headless"]
        command += ["--script", str(wrapper)]
        startupinfo = None
        if os.name == "nt":
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = subprocess.SW_HIDE
        try:
            process = subprocess.run(
                command, cwd=ROOT, env=environment, capture_output=True,
                text=True, encoding="utf-8", errors="replace", timeout=timeout,
                startupinfo=startupinfo,
            )
            output = process.stdout + process.stderr
            # This Windows engine warning also occurs in an otherwise empty
            # SceneTree on hosts without a readable certificate store. These
            # local gameplay suites do not use TLS; retain it in the log/report.
            checked_output, certificate_warnings = re.subn(
                r"ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\r?\n?",
                "", output,
            ) if os.name == "nt" else (output, 0)
            passed = process.returncode == 0 and "ERROR:" not in checked_output and "TEST_USER_DIR=" in output
            record = {"suite": name, "exit_code": process.returncode, "passed": passed}
            if certificate_warnings:
                record["platform_warnings"] = ["Windows root certificate store unavailable; local suite does not use TLS"]
        except subprocess.TimeoutExpired as error:
            stdout = error.stdout or b""
            stderr = error.stderr or b""
            output = (stdout.decode("utf-8", "replace") if isinstance(stdout, bytes) else stdout)
            output += (stderr.decode("utf-8", "replace") if isinstance(stderr, bytes) else stderr)
            record = {"suite": name, "passed": False, "error": f"{timeout:g}-second timeout"}
        except OSError as error:
            output = str(error)
            record = {"suite": name, "passed": False, "error": str(error)}
        record["seconds"] = round(time.monotonic() - start, 3)
        record["isolated_user_data"] = "TEST_USER_DIR=" in output
    (ROOT / "artifacts" / f"{name}-suite.log").write_text(output, encoding="utf-8")
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suites", nargs="*", help="Suite names without test_ or .gd (default: regression set)")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"), help="Godot executable; defaults to GODOT_BIN or PATH")
    parser.add_argument("--timeout", type=float, default=45)
    parser.add_argument("--render", action="store_true", help="Use the real renderer in an offscreen window for screenshot suites")
    parser.add_argument("--verbose", action="store_true", help="Include Godot's resource and renderer diagnostics in suite logs")
    parser.add_argument("--report", default="consolidated-test-report.json", help="Report filename within artifacts")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    names = args.suites or DEFAULT_SUITES
    if any(not name.replace("_", "").isalnum() for name in names):
        parser.error("suite names may contain only letters, numbers and underscores")
    if Path(args.report).name != args.report or not args.report.endswith(".json"):
        parser.error("--report must be a .json filename within artifacts")
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error("Godot not found; set GODOT_BIN or pass --godot with its executable path")
    (ROOT / "artifacts").mkdir(exist_ok=True)
    (ROOT / "artifacts" / ".gdignore").touch(exist_ok=True)
    results = []
    for name in names:
        record = run_suite(godot, name, args.timeout, args.render, args.verbose)
        results.append(record)
        print(json.dumps(record, ensure_ascii=False), flush=True)
    report = {"suites": results, "passed": all(result["passed"] for result in results)}
    (ROOT / "artifacts" / args.report).write_text(json.dumps(report, indent=2), encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
