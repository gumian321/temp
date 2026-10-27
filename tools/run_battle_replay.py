"""Compare a diagnostic battle snapshot in isolated native-rendered processes."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess

from run_checks import ROOT, isolated_environment
from analyze_playtest import read_rows
from build_deep_candidate import sources

INITIAL_FLAGS = [
    'RBPEW_LEGACY_MATERIAL_CERTIFICATES', 'RBPEW_LEGACY_NAV_ROW_SKIP',
    'RBPEW_LEGACY_PASSIVE_RENDER_SNAPSHOT', 'RBPEW_LEGACY_ORGAN_SUBMISSION',
    'RBPEW_LEGACY_SOFT_CLOCK', 'RBPEW_LEGACY_PARENT_POSE',
]
LATER_FLAGS = [
    'RBPEW_LEGACY_UID_HINTS', 'RBPEW_LEGACY_STATIONARY_ROOT',
    'RBPEW_LEGACY_ATTACHED_RECONCILE', 'RBPEW_LEGACY_ENEMY_GUN_INPUTS',
    'RBPEW_LEGACY_SWEEP_LOCAL_INVALIDATION', 'RBPEW_LEGACY_NAV_INVALIDATION',
    'RBPEW_LEGACY_SHIELD_PRESENTATION', 'RBPEW_LEGACY_HIDDEN_RIG_PARKING',
    'RBPEW_LEGACY_PIT_CLEARANCE',
    'RBPEW_LEGACY_FRACTURED_TEMPLATES',
    'RBPEW_LEGACY_VISUAL_SETTLING', 'RBPEW_LEGACY_SPATIAL_CELL_REUSE',
    'RBPEW_LEGACY_HOSTILE_GEOMETRY_BATCH', 'RBPEW_LEGACY_HOSTILE_INSTANCING',
    'RBPEW_LEGACY_TERRAIN_SURFACE_BATCH',
    'RBPEW_LEGACY_POD_GEOMETRY_BATCH',
    'RBPEW_LEGACY_RADAR_ICON_ATLAS',
    'RBPEW_LEGACY_EMPTY_WEAPON_NECK',
    'RBPEW_LEGACY_NECK_GEOMETRY_BATCH',
    'RBPEW_LEGACY_POINTER_GEOMETRY_BATCH',
    'RBPEW_LEGACY_REPAIR_TETHER_BATCH',
    'RBPEW_LEGACY_ACTOR_FLIGHT_BATCH',
    'RBPEW_LEGACY_RADAR_ICON_BATCH',
    'RBPEW_LEGACY_ENEMY_CORE_FRAME',
    'RBPEW_LEGACY_WALL_OVERLAP_MEMO',
    'RBPEW_LEGACY_AI_COMPONENT_FRAME', 'RBPEW_LEGACY_SPATIAL_BUILD',
    'RBPEW_LEGACY_NEAR_CONTACT_PROBE', 'RBPEW_LEGACY_ORBIT_OBSERVER_PRUNING',
    'RBPEW_LEGACY_NATIVE_CAVE_SWEEP', 'RBPEW_LEGACY_WIDE_NEAR_CONTACT',
    'RBPEW_LEGACY_NATIVE_OVERLAP', 'RBPEW_LEGACY_ABSENT_KNOCKBACK',
]
FLAGS = INITIAL_FLAGS + LATER_FLAGS
ENABLES = {'RBPEW_ENABLE_VISUAL_SETTLING': '1', 'RBPEW_ENABLE_SPATIAL_CELL_REUSE': '1',
           'RBPEW_ENABLE_HOSTILE_GEOMETRY_BATCH': '1', 'RBPEW_ENABLE_TERRAIN_SURFACE_BATCH': '1',
           'RBPEW_ENABLE_POD_GEOMETRY_BATCH': '1', 'RBPEW_ENABLE_RADAR_ICON_ATLAS': '1'}
ENABLES.update(RBPEW_ENABLE_NECK_GEOMETRY_BATCH='1', RBPEW_ENABLE_POINTER_GEOMETRY_BATCH='1')
ENABLES.update(RBPEW_ENABLE_REPAIR_TETHER_BATCH='1')
ENABLES.update(RBPEW_ENABLE_ACTOR_FLIGHT_BATCH='1')
ENABLES.update(RBPEW_ENABLE_RADAR_ICON_BATCH='1')
ENABLES.update(RBPEW_ENEMY_CORE_FRAME='1', RBPEW_ENABLE_WALL_OVERLAP_MEMO='1')
ENABLES.update(RBPEW_ENABLE_AI_COMPONENT_FRAME='1', RBPEW_ENABLE_SPATIAL_BUILD='1',
               RBPEW_ENABLE_NEAR_CONTACT_PROBE='1', RBPEW_ENABLE_ORBIT_OBSERVER_PRUNING='1')
ENABLES.update(RBPEW_ENABLE_NATIVE_CAVE_SWEEP='1', RBPEW_ENABLE_WIDE_NEAR_CONTACT='1')
ENABLES.update(RBPEW_ENABLE_NATIVE_OVERLAP='1')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=Path)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--executable', type=Path)
    parser.add_argument('--godot', default='D:/godot/Godot_v4.6.3-stable_win64.exe')
    parser.add_argument('--order', default='legacy,optimized,optimized,legacy')
    parser.add_argument('--warmup', type=int, default=120)
    parser.add_argument('--samples', type=int, default=180)
    parser.add_argument('--only', choices=FLAGS)
    parser.add_argument('--baseline', choices=['initial', 'candidate1', 'candidate3', 'candidate4', 'candidate5', 'candidate6', 'candidate7', 'candidate8', 'candidate9', 'candidate10'], default='initial')
    parser.add_argument('--terrain-kernels', action='store_true', help='Instrument nested terrain calls; diagnostic overhead changes timing')
    parser.add_argument('--render-timing', action='store_true', help='Request engine CPU/GPU render timers when supported')
    parser.add_argument('--world-mode', choices=['production', 'capacity', 'empty', 'segmented', 'native-sweep'], default='production', help='Compare an isolated source-only geometry prototype against production')
    parser.add_argument('--geometry-capacity', type=int, default=32768)
    parser.add_argument('--row-capacity', type=int, default=4096)
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--offscreen', action='store_true')
    parser.add_argument('--native-dt', action='store_true')
    parser.add_argument('--production-defaults', action='store_true', help='Keep optional visual settling and spatial cell reuse disabled, as in the shipped game')
    parser.add_argument('--disable-feature', action='append', choices=sorted(ENABLES), default=[], help='Keep this experimental enable flag off on both sides of the comparison')
    args = parser.parse_args()
    if args.world_mode != 'production' and (args.executable or args.terrain_kernels or args.only):
        parser.error('World prototypes require source execution and cannot combine with terrain-kernels or --only')
    if not args.tag.replace('-', '').isalnum():
        parser.error('Invalid tag')
    modes = args.order.split(',')
    if any(m not in ['legacy', 'optimized'] for m in modes):
        parser.error('Order must contain legacy/optimized')
    snapshot = args.snapshot.resolve()
    if not snapshot.is_file():
        parser.error('Missing snapshot')
    context = snapshot.parent.parent if snapshot.parent.name == 'stop-states' else snapshot.parent
    view = {}
    if (context / 'collected-logs').is_dir():
        rows, _ = read_rows(context)
        counted = [r for r in rows if r.get('counts') and 'zoom' in r['counts']]
        # An archived checkpoint uses the elapsed prefix, rather than a later
        # overwritten status file from the same continued battle.
        elapsed = float(snapshot.name.split('-')[0]) if snapshot.parent.name == 'stop-states' else 0
        if counted:
            closest = min(counted, key=lambda r: abs(r.get('run_elapsed', 0) - elapsed))
            view = {'zoom': closest['counts']['zoom']}
    folder = ROOT / 'artifacts' / args.tag
    folder.mkdir(exist_ok=False)
    source_manifest = sources() if not args.executable else None
    if source_manifest is not None:
        (folder / 'source-manifest.json').write_text(json.dumps(source_manifest, indent=2), encoding='utf-8')
    results = []
    feature_enables = dict(ENABLES)
    if args.production_defaults:
        feature_enables.update(RBPEW_ENABLE_VISUAL_SETTLING='0', RBPEW_ENABLE_SPATIAL_CELL_REUSE='0')
    feature_enables.update({flag: '0' for flag in args.disable_feature})
    baseline_flags = [args.only] if args.only else (LATER_FLAGS if args.baseline == 'candidate1' else FLAGS)
    if not args.only and args.baseline == 'candidate3':
        baseline_flags = ['RBPEW_LEGACY_VISUAL_SETTLING', 'RBPEW_LEGACY_SPATIAL_CELL_REUSE']
    if not args.only and args.baseline == 'candidate4':
        baseline_flags = ['RBPEW_LEGACY_HOSTILE_GEOMETRY_BATCH', 'RBPEW_LEGACY_HOSTILE_INSTANCING',
                          'RBPEW_LEGACY_TERRAIN_SURFACE_BATCH', 'RBPEW_LEGACY_POD_GEOMETRY_BATCH',
                          'RBPEW_LEGACY_RADAR_ICON_ATLAS', 'RBPEW_LEGACY_EMPTY_WEAPON_NECK']
    if not args.only and args.baseline == 'candidate5':
        baseline_flags = ['RBPEW_LEGACY_NECK_GEOMETRY_BATCH', 'RBPEW_LEGACY_POINTER_GEOMETRY_BATCH',
                          'RBPEW_LEGACY_REPAIR_TETHER_BATCH', 'RBPEW_LEGACY_ACTOR_FLIGHT_BATCH', 'RBPEW_LEGACY_RADAR_ICON_BATCH']
    if not args.only and args.baseline == 'candidate6':
        baseline_flags = ['RBPEW_LEGACY_ENEMY_CORE_FRAME', 'RBPEW_LEGACY_WALL_OVERLAP_MEMO']
    if not args.only and args.baseline == 'candidate7':
        baseline_flags = ['RBPEW_LEGACY_AI_COMPONENT_FRAME', 'RBPEW_LEGACY_SPATIAL_BUILD',
                          'RBPEW_LEGACY_NEAR_CONTACT_PROBE', 'RBPEW_LEGACY_ORBIT_OBSERVER_PRUNING']
    if not args.only and args.baseline == 'candidate8':
        baseline_flags = ['RBPEW_LEGACY_NATIVE_CAVE_SWEEP', 'RBPEW_LEGACY_WIDE_NEAR_CONTACT']
    if not args.only and args.baseline == 'candidate9':
        baseline_flags = ['RBPEW_LEGACY_NATIVE_CAVE_SWEEP', 'RBPEW_LEGACY_WIDE_NEAR_CONTACT', 'RBPEW_LEGACY_NATIVE_OVERLAP']
    if not args.only and args.baseline == 'candidate10':
        baseline_flags = ['RBPEW_LEGACY_ABSENT_KNOCKBACK', 'RBPEW_LEGACY_NATIVE_OVERLAP']
    if args.world_mode != 'production':
        baseline_flags = []
    for index, mode in enumerate(modes):
        case = folder / f'{index+1:02d}-{mode}'
        case.mkdir()
        env = isolated_environment(case)
        env.update(RBPEW_REPLAY_ROOT=case.as_posix(), RBPEW_BATTLE_SNAPSHOT=str(snapshot),
                   RBPEW_REPLAY_WARMUP=str(args.warmup), RBPEW_REPLAY_SAMPLES=str(args.samples),
                   RBPEW_RUNTIME_LOG='1', RBPEW_PROFILE='1', RBPEW_REPLAY_VIEW=json.dumps(view))
        if args.terrain_kernels:
            env['RBPEW_REPLAY_TERRAIN_KERNELS'] = '1'
        if args.render_timing:
            env['RBPEW_REPLAY_RENDER_TIMING'] = '1'
        env.update({flag: '0' for flag in FLAGS})
        env.update(feature_enables)
        if args.world_mode != 'production':
            env['RBPEW_REPLAY_WORLD_MODE'] = args.world_mode if mode == 'optimized' else 'production'
            env['RBPEW_GEOMETRY_CAPACITY'] = str(args.geometry_capacity)
            env['RBPEW_COLLISION_ROW_CAPACITY'] = str(args.row_capacity)
        if mode == 'legacy':
            env.update({flag: '1' for flag in baseline_flags})
        relative = Path('Godot/app_userdata/Run Build Pew! — Centipede/centipede-save.json')
        source = context / 'original-save-copy.json'
        if not source.is_file():
            source = Path(os.environ['APPDATA']) / relative
        target = Path(env['APPDATA']) / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        command = [str(args.executable.resolve())] if args.executable else [args.godot, '--path', str(ROOT)]
        command += ['--audio-driver', 'Dummy', '--log-file', str(case/'engine.log')]
        if args.headless:
            command += ['--headless']
        else:
            command += ['--windowed', '--resolution', '1440x900', '--position', '-10000,-10000' if args.offscreen else '80,50']
        if not args.native_dt:
            command += ['--fixed-fps', '60']
        command += ['--', '--battle-replay']
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE if args.headless or args.offscreen else 5
        try:
            process = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                                     text=True, encoding='utf-8', errors='replace',
                                     timeout=120, startupinfo=startup)
            output = process.stdout + process.stderr
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b'').decode('utf-8', 'replace') + (error.stderr or b'').decode('utf-8', 'replace')
            (case/'stdout.log').write_text(output, encoding='utf-8')
            raise RuntimeError(f'Replay timeout: {case}; {output[-3000:]}') from error
        (case/'stdout.log').write_text(output, encoding='utf-8')
        path = case / 'replay-report.json'
        checked = re.sub(r'ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\r?\n?', '', output)
        if process.returncode or 'ERROR:' in checked or not path.is_file():
            raise RuntimeError(f'Replay failed: {case}; {output[-4000:]}')
        report = json.loads(path.read_text(encoding='utf-8'))
        if not report['passed']:
            raise RuntimeError(f'Replay did not complete: {case}')
        results.append({'mode': mode, 'report': report, 'command': command})
        if source_manifest is not None and sources() != source_manifest:
            raise RuntimeError('Runtime sources changed during the comparison; do not use mixed-source timings')
        print(json.dumps({'mode': mode, 'frame': report['frame'], 'actors': report['counts']['actors'], 'parts': report['counts']['parts']}, ensure_ascii=False), flush=True)
    result = {'scope': 'Same snapshot and frame-indexed input, rebuilt derived caches, fixed simulation step unless native-dt requested. Diagnostic fixture, not real-clock thirty-minute acceptance.',
              'snapshot': str(snapshot), 'snapshot_sha256': hashlib.sha256(snapshot.read_bytes()).hexdigest(),
              'view': view, 'headless': args.headless, 'native_dt': args.native_dt, 'flags': FLAGS,
              'only': args.only, 'baseline': args.baseline, 'baseline_flags': baseline_flags,
              'feature_enables': feature_enables, 'production_defaults': args.production_defaults,
              'terrain_kernels': args.terrain_kernels, 'results': results}
    result['render_timing'] = args.render_timing
    result['world_prototype'] = {'mode': args.world_mode, 'geometry_capacity': args.geometry_capacity, 'row_capacity': args.row_capacity}
    (folder/'comparison.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
