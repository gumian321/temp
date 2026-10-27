"""Summarize local performance journals or a ZIP without extracting its contents."""
import argparse
from collections import defaultdict
from contextlib import contextmanager
import json
import math
from pathlib import Path
import zipfile

MAX_INPUT_BYTES = 128 * 1024 * 1024
MAX_LINE_BYTES = 2 * 1024 * 1024


def number(value):
    return float(value) if isinstance(value, (int, float)) and math.isfinite(value) else None


@contextmanager
def inputs(path):
    if path.suffix.lower() == ".zip":
        with zipfile.ZipFile(path) as archive:
            files = sorted((info for info in archive.infolist() if info.filename.endswith(".jsonl")), key=lambda x: x.filename)
            if sum(info.file_size for info in files) > MAX_INPUT_BYTES:
                raise ValueError("Journal archive exceeds 128 MiB")
            yield [(info.filename, lambda info=info: archive.open(info)) for info in files]
    else:
        files = [path] if path.is_file() else sorted(path.rglob("*.jsonl"))
        if sum(file.stat().st_size for file in files) > MAX_INPUT_BYTES:
            raise ValueError("Journal input exceeds 128 MiB")
        yield [(str(file), lambda file=file: file.open("rb")) for file in files]


def analyze(path):
    sessions = defaultdict(lambda: {"headers": [], "summaries": [], "details": [], "markers": [], "loadouts": [], "captures": 0, "bad_lines": 0})
    with inputs(path) as files:
        for name, opener in files:
            session = sessions[str(Path(name).parent)]
            with opener() as raw:
                while True:
                    line = raw.readline(MAX_LINE_BYTES + 1)
                    if not line:
                        break
                    if len(line) > MAX_LINE_BYTES:
                        session["bad_lines"] += 1
                        while line and not line.endswith(b"\n"):
                            line = raw.readline(MAX_LINE_BYTES + 1)
                        continue
                    try:
                        row = json.loads(line)
                    except (ValueError, UnicodeDecodeError):
                        session["bad_lines"] += 1
                        continue
                    if not isinstance(row, dict):
                        continue
                    kind = row.get("type")
                    if kind == "header":
                        session["headers"].append(row)
                    elif kind == "summary" and isinstance(row.get("frame_ms"), dict):
                        session["summaries"].append(row)
                    elif kind == "detail":
                        session["details"].append(row)
                    elif kind in ["marker", "slow_trigger", "state", "session_end"]:
                        session["markers"].append(row)
                    elif kind == "f3_capture":
                        session["captures"] += 1
                    elif kind == "loadout":
                        session["loadouts"].append(row)
    results = []
    for name, session in sessions.items():
        header = session["headers"][-1] if session["headers"] else {}
        rows = sorted(session["summaries"], key=lambda row: row.get("run_elapsed", 0))
        frames = sum(row.get("frames", 0) for row in rows)
        total = sum(row.get("frames", 0) * row["frame_ms"].get("mean", 0) for row in rows)
        count_rows = [row for row in rows if isinstance(row.get("counts"), dict)]
        growth = {}
        for key in {key for row in count_rows for key in row["counts"]}:
            values = [number(row["counts"].get(key)) for row in count_rows]
            values = [value for value in values if value is not None]
            if values:
                growth[key] = {"first": values[0], "last": values[-1], "max": max(values), "change": values[-1] - values[0]}
        phases = {}
        for group in ["main_us", "combat_us"]:
            totals = defaultdict(float)
            observations = defaultdict(int)
            for detail in session["details"]:
                for key, value in detail.get(group, {}).items():
                    value = number(value)
                    if value is not None:
                        totals[key] += value
                        observations[key] += 1
            phases[group] = sorted(({"phase": key, "sample_mean_ms": value / observations[key] / 1000, "samples": observations[key]} for key, value in totals.items()), key=lambda x: -x["sample_mean_ms"])
        worst = sorted(rows, key=lambda row: row["frame_ms"].get("mean", 0), reverse=True)[:12]
        results.append({"session": name, "build_id": header.get("build_id"), "synthetic_clock": header.get("synthetic_clock", False), "fixture": header.get("fixture", False), "mission": header.get("mission"), "character": header.get("character"), "sources": header.get("sources"), "coverage_start_elapsed": rows[0].get("run_elapsed") if rows else None, "coverage_end_elapsed": rows[-1].get("run_elapsed") if rows else None, "recorded_active_frames": frames, "weighted_mean_frame_ms": total / frames if frames else None, "summary_rows": len(rows), "detail_rows": len(session["details"]), "f3_captures": session["captures"], "invalid_or_truncated_lines": session["bad_lines"], "worst_recorded_seconds": worst, "counter_growth": growth, "sampled_nested_phases": phases, "events": session["markers"], "loadout_history": session["loadouts"]})
    return {"schema": 1, "scope": "Summary means are frame-weighted over retained parts. Per-second percentiles are not pooled into an invented global percentile. Phase samples are nested and biased toward profiling/slow windows. Synthetic-clock fixtures are labeled.", "sessions": results}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Session folder, performance-logs folder, .jsonl file or ZIP")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = analyze(args.input)
    output = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output + "\n", encoding="utf-8")
        print(json.dumps({"sessions": len(report["sessions"]), "output": str(args.output)}, ensure_ascii=False))
    else:
        print(output)


if __name__ == "__main__":
    main()
