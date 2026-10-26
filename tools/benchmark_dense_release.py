"""Compare dense combat paths in one release build with isolated user data."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
from run_checks import ROOT, isolated_environment


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path, default=ROOT / "artifacts/dense60-release/RunBuildPew.exe")
    parser.add_argument("--tag", default="dense60-20261025")
    parser.add_argument("--case", choices=["medium", "heavy"], default="medium")
    parser.add_argument("--order", default="before,after,after,before")
    parser.add_argument("--renderer", choices=["gl_compatibility", "mobile"])
    parser.add_argument("--baseline", choices=["original", "previous"], default="original", help="original: before 2026-10-25 changes; previous: 2026-10-25 optimized paths")
    parser.add_argument("--warmup", type=int, default=60)
    parser.add_argument("--samples", type=int, default=180)
    args = parser.parse_args()
    if not re.fullmatch(r"[\w-]+", args.tag):
        parser.error("Invalid report tag")
    order = args.order.split(",")
    if any(mode not in ["before", "after"] for mode in order):
        parser.error("--order accepts before/after modes")
    actors, bullets, parts = (32, 128, 13) if args.case == "medium" else (64, 256, 31)
    results = []
    for iteration, mode in enumerate(order, 1):
        label = f"{args.tag}-{args.case}-{mode}-{iteration}"
        path = ROOT / "artifacts" / f"{label}.json"
        with tempfile.TemporaryDirectory(prefix="dense60-release-") as directory:
            scratch = Path(directory)
            env = isolated_environment(scratch)
            legacy = "1" if mode == "before" and args.baseline == "original" else "0"
            env.update({"RBPEW_PRESSURE_TAG": label, "RBPEW_PRESSURE_ENEMIES": str(actors),
                        "RBPEW_PRESSURE_BULLETS": str(bullets), "RBPEW_PRESSURE_PARTS": str(parts),
                        "RBPEW_PRESSURE_OUTPUT": str(path), "RBPEW_LEGACY_BULLET_DRAW": legacy,
                        "RBPEW_LEGACY_PLAYER_HULL": legacy, "RBPEW_LEGACY_SHIELD_RAYS": legacy,
                        "RBPEW_LEGACY_MUZZLE_DRAW": legacy, "RBPEW_LEGACY_EQUIPMENT_CACHE": legacy,
                        "RBPEW_LEGACY_COMPACT_TREE": legacy,
                        "RBPEW_LEGACY_FLIGHT_BATCH": "1" if mode == "before" else "0",
                        "RBPEW_LEGACY_RIG_POOL": "1" if mode == "before" else "0",
                        "RBPEW_LEGACY_QUERY_CACHE":"1" if mode == "before" else "0",
                        "RBPEW_LEGACY_UPGRADE_CACHE":"1" if mode == "before" else "0",
                        "RBPEW_PRESSURE_WARMUP":str(args.warmup),"RBPEW_PRESSURE_SAMPLES":str(args.samples)})
            command = [str(args.executable.resolve()), "--audio-driver", "Dummy", "--windowed",
                       "--resolution", "1440x900", "--position", "-10000,-10000",
                       "--log-file", str(scratch / "runtime.log")]
            if args.renderer:
                command += ["--rendering-method", args.renderer, "--rendering-driver", "vulkan" if args.renderer == "mobile" else "opengl3"]
            command += ["--", "--review-dense-check"]
            run = subprocess.run(command,
                                 cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8",
                                 errors="replace", timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
            output = run.stdout + run.stderr
            (ROOT / "artifacts" / f"{label}.log").write_text(output, encoding="utf-8")
            if run.returncode or "TEST_USER_DIR=" not in output or not path.exists():
                raise RuntimeError(f"Release probe failed: {label}\n{output[-3000:]}")
            report = json.loads(path.read_text("utf-8"))
            if report["debug_build"] or not report["exported"]:
                raise RuntimeError("Expected actual release runtime")
            result = {"mode": mode, "report": str(path), "summary": report["summary"],
                      "phases_mean_ms": report["phases_mean_ms"], "signature": report["signature"]}
            results.append(result)
            print(json.dumps({"case": args.case, "mode": mode, "frame_ms": report["summary"]["frame_ms"],
                              "draw_calls": report["summary"]["draw_calls"]["mean"]}), flush=True)
    destination = ROOT / "artifacts" / f"{args.tag}-{args.case}-comparison.json"
    destination.write_text(json.dumps({"baseline":args.baseline,"renderer_override": args.renderer, "scope": "Same release EXE; alternating baseline/optimized paths, fixed-tick production combat with projectile floor. Not natural real-delta gameplay FPS.",
                                       "isolated_user_data": True, "results": results}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
