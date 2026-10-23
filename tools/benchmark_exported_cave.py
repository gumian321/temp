"""Time actual exported cave gameplay with an isolated profile and retain evidence."""
import argparse
import json
from pathlib import Path
import re
import shutil
import tempfile

from package_windows_review import run, ROOT
from run_checks import isolated_environment


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--actors", type=int, default=24)
    parser.add_argument("--frames", type=int, default=1200)
    parser.add_argument("--mission", default="Endless Mission")
    parser.add_argument("--route", choices=("straight", "excavate", "roam"), default="excavate")
    parser.add_argument("--mixed", action="store_true")
    parser.add_argument("--natural-actors", action="store_true")
    parser.add_argument("--native-pacing", action="store_true")
    parser.add_argument("--legacy-eggs", action="store_true")
    parser.add_argument("--legacy-cpu", action="store_true", help="Use original spring constraints and 32px movement certificates for same-build A/B")
    parser.add_argument("--seed", type=int, default=20261021)
    parser.add_argument("--full-orbits", action="store_true", help="Disable remote map orbit collision cadence for an isolated comparison")
    parser.add_argument("--render-thread", choices=("safe", "separate"), help="Diagnostic engine render-thread override")
    parser.add_argument("--renderer", choices=("gl_compatibility", "mobile", "forward_plus"), help="Diagnostic renderer override")
    parser.add_argument("--seconds", type=float, default=0)
    parser.add_argument("--visible", action="store_true")
    parser.add_argument("--profile", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-zA-Z0-9-]+", args.tag): parser.error("Invalid tag")
    executable = args.executable.resolve()
    if not executable.is_file(): parser.error("Missing executable")
    with tempfile.TemporaryDirectory(prefix="centipede-export-benchmark-") as directory:
        scratch = Path(directory).resolve()
        environment = isolated_environment(scratch)
        environment.update({"RBPEW_MINING_ACTORS":str(args.actors),"RBPEW_MINING_FRAMES":str(args.frames),
                            "RBPEW_MINING_MISSION":args.mission,"RBPEW_MINING_ROUTE":args.route,
                            "RBPEW_PROFILE":"1" if args.profile else "0"})
        environment.update({"RBPEW_MINING_LOADOUT":"mixed" if args.mixed else "",
                            "RBPEW_MINING_NATIVE_ACTORS":"1" if args.natural_actors else "0",
                            "RBPEW_MINING_NATIVE_PACING":"1" if args.native_pacing else "0",
                            "RBPEW_MINING_LEGACY_EGGS":"1" if args.legacy_eggs else "0",
                            "RBPEW_MINING_LEGACY_CPU":"1" if args.legacy_cpu else "0",
                            "RBPEW_MINING_SEED":str(args.seed),
                            "RBPEW_MINING_FULL_ORBITS":"1" if args.full_orbits else "0",
                            "RBPEW_MINING_SECONDS":str(args.seconds)})
        command = [str(executable),"--audio-driver","Dummy","--windowed","--resolution","1440x900",
                      "--position","80,50" if args.visible else "-10000,-10000",
                  ]
        if not args.native_pacing:command += ["--fixed-fps","60"]
        if args.render_thread:command += ["--render-thread",args.render_thread]
        if args.renderer:command += ["--rendering-method",args.renderer,"--rendering-driver","opengl3" if args.renderer=="gl_compatibility" else "vulkan"]
        command += ["--","--review-performance-check"]
        output = run(command,environment,args.tag,timeout=210,visible=args.visible)
        records = []
        for line in output.splitlines():
            try: record = json.loads(line)
            except json.JSONDecodeError: continue
            if isinstance(record,dict) and "native_performance_report" in record: records.append(record)
        if not records or not records[-1]["passed"] or not records[-1]["exported"]:
            raise RuntimeError("Exported gameplay benchmark failed")
        source = Path(records[-1]["native_performance_report"]).resolve()
        if not source.is_relative_to(scratch): raise RuntimeError("Report escaped isolated profile")
        report = json.loads(source.read_text(encoding="utf-8"))
        report["visible_window"] = args.visible
        report["cpu_phase_profiling"] = args.profile
        report["render_thread_override"] = args.render_thread
        report["renderer_override"] = args.renderer
        destination = ROOT/"artifacts"/(args.tag+".json")
        captures=[]
        for index,capture in enumerate(report["captures"]):
            target=destination.with_suffix(".png") if index==0 else destination.with_name(args.tag+"-"+Path(capture).name)
            shutil.copy2(capture,target);captures.append(str(target))
        report["captures"] = captures
        destination.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
        print(json.dumps({"report":str(destination),"frame_ms":report["frame_ms"],"cpu_ms":report["cpu_ms"],"counter":report["counter"]}))


if __name__ == "__main__":main()
