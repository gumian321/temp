#!/usr/bin/env python3
"""Run deterministic fixed-step CPU benchmark in isolated user-data directories.

Example:
 python tools/benchmark_dense_combat.py --project ../perf-round10-baseline --label before --repeats 3
 python tools/benchmark_dense_combat.py --project . --label after --repeats 3
Compare matching signatures before interpreting timing differences. This does not measure GPU FPS.
"""
import argparse
import json
import os
from pathlib import Path
import statistics
import shutil
import hashlib
import time
try:
    import resource
except ImportError:
    resource = None
from run_checks import isolated_environment
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument('--label', required=True)
parser.add_argument('--repeats', type=int, default=3)
parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'artifacts')
parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
parser.add_argument('--mode', choices=['cpu', 'render'], default='cpu')
args = parser.parse_args()
if args.repeats < 1:
    parser.error('--repeats must be at least 1')
godot = shutil.which(args.godot)
if not godot:
    parser.error('Godot not found; set GODOT_BIN or pass --godot with its executable path')
project = args.project.resolve()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
git = shutil.which('git')
revision = subprocess.run([git, '-C', str(project), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip() if git else ''
revision = revision or ('frozen-baseline-2e979236680e17349fd13aff6430d372cc97a334' if project.name in ['centipede-perf-baseline', 'perf-round10-baseline'] else 'unversioned-source; see source_hashes')
reports = []
prefix = 'dense-combat' if args.mode == 'cpu' else 'dense-render'
script = 'test_dense_combat_benchmark.gd' if args.mode == 'cpu' else 'test_dense_render_benchmark.gd'
source_hashes = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((project / 'scripts').glob('*.gd'))}
source_hashes['tests/' + script] = hashlib.sha256((project / 'tests' / script).read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='centipede-dense-bench-') as user_dir:
    scratch = Path(user_dir).resolve()
    env = isolated_environment(scratch)
    wrapper = scratch / 'guarded_benchmark.gd'
    wrapper.write_text(
        f'extends "res://tests/{script}"\n'
        'func _initialize():\n'
        '\tvar expected = OS.get_environment("RBPEW_TEST_SANDBOX").replace("\\\\", "/").to_lower() + "/"\n'
        '\tvar actual = OS.get_user_data_dir().replace("\\\\", "/").to_lower() + "/"\n'
        '\tif not actual.begins_with(expected):\n'
        '\t\tprinterr("ERROR: Refusing benchmark outside isolated user directory: ", actual)\n'
        '\t\tquit(2)\n\t\treturn\n'
        '\tprint("BENCHMARK_USER_DIR=", OS.get_user_data_dir())\n'
        '\tsuper._initialize()\n', encoding='utf-8')
    env['RBPEW_REVISION'] = revision
    for iteration in range(args.repeats):
        report_path = output / f'{prefix}-{args.label}-{iteration+1}.json'
        env['RBPEW_DENSE_OUTPUT' if args.mode == 'cpu' else 'RBPEW_DENSE_RENDER_OUTPUT'] = report_path.as_posix()
        log_path = output / f'{prefix}-{args.label}-{iteration+1}.log'
        usage_before = resource.getrusage(resource.RUSAGE_CHILDREN) if resource else None
        wall_before = time.monotonic()
        with log_path.open('w', encoding='utf-8') as log:
            command = [godot, '--path', str(project), '--log-file', str(scratch / 'godot.log'), '--script', str(wrapper)]
            command += ['--headless'] if args.mode == 'cpu' else ['--audio-driver', 'Dummy', '--windowed', '--resolution', '1440x900']
            run = subprocess.run(command, cwd=project, env=env, text=True, stdout=log, stderr=subprocess.STDOUT, timeout=1200)
        if run.returncode or 'SCRIPT ERROR:' in log_path.read_text(encoding='utf-8', errors='replace') or 'BENCHMARK_USER_DIR=' not in log_path.read_text(encoding='utf-8', errors='replace') or not report_path.exists():
            raise SystemExit(f'Benchmark failed: {report_path}; inspect log')
        wall_seconds = time.monotonic() - wall_before
        usage_after = resource.getrusage(resource.RUSAGE_CHILDREN) if resource else None
        report = json.loads(report_path.read_text(encoding='utf-8'))
        report['process_timing'] = {'wall_seconds': wall_seconds, 'user_cpu_seconds': usage_after.ru_utime - usage_before.ru_utime if resource else None, 'system_cpu_seconds': usage_after.ru_stime - usage_before.ru_stime if resource else None, 'scope': 'Entire Godot subprocess: startup, fixture setup, warmup, measured steps, projectile replenishment and output. CPU counters use POSIX child resource usage; unavailable on Windows is null.'}
        report_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        reports.append(report)
        print(args.label, iteration+1, [(r['config']['name'], r['step_ms']['p50'], r['step_ms']['p95']) for r in report['results']] if args.mode == 'cpu' else report['frame_ms'], flush=True)
if args.mode == 'render':
    summary = {'label': args.label, 'revision': revision, 'source_hashes': source_hashes, 'runs': reports, 'signatures_match': all(r['signature'] == reports[0]['signature'] for r in reports)}
    (output / f'{prefix}-{args.label}-summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(summary, indent=2))
    raise SystemExit(0 if summary['signatures_match'] else 1)
summary = {'process_timing': [r.get('process_timing') for r in reports], 'source_hashes': source_hashes, 'label': args.label, 'revision': revision, 'repeats': len(reports), 'scope': reports[0]['scope'], 'scenarios': []}
for index, first in enumerate(reports[0]['results']):
    runs = [report['results'][index] for report in reports]
    signatures_match = all(run['signature'] == first['signature'] for run in runs)
    summary['scenarios'].append({'config': first['config'], 'signatures_match': signatures_match, 'signature': first['signature'], 'median_run_p50_ms': statistics.median(r['step_ms']['p50'] for r in runs), 'median_run_p95_ms': statistics.median(r['step_ms']['p95'] for r in runs), 'median_run_mean_ms': statistics.median(r['step_ms']['mean'] for r in runs), 'phase_mean_ms': {key: statistics.median(r['phases_ms'][key]['mean'] for r in runs) for key in first['phases_ms']}, 'entities': first['entities']})
(output / f'{prefix}-{args.label}-summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
print(json.dumps(summary, indent=2))
if not all(s['signatures_match'] for s in summary['scenarios']):
    raise SystemExit('Non-deterministic signatures: timing comparison is invalid')
