"""Run a paused-scene roster micro-profile in a verified isolated Godot profile."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from run_checks import ROOT, isolated_environment


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('roster', type=Path)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--godot', default='D:/godot/Godot_v4.6.3-stable_win64.exe')
    parser.add_argument('--extended', action='store_true')
    args = parser.parse_args()
    if not args.tag.replace('-', '').isalnum():
        parser.error('Invalid tag')
    folder = ROOT / 'artifacts' / args.tag
    folder.mkdir(exist_ok=False)
    env = isolated_environment(folder)
    env.update(RBPEW_ROSTER_REPLAY=str(args.roster.resolve()), RBPEW_CAVE_RECOVERY_CACHE='1')
    if args.extended:
        env['RBPEW_CAVE_EXTENDED_SWEEPS'] = '1'
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE
    command = [args.godot, '--headless', '--path', str(ROOT), '--script', 'res://tools/profile_late_cave.gd']
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                            text=True, encoding='utf-8', errors='replace',
                            timeout=180, startupinfo=startup)
    (folder / 'engine.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    if result.returncode:
        print(result.stdout + result.stderr)
        return result.returncode
    reports = []
    for line in result.stdout.splitlines():
        try:
            row = json.loads(line)
        except ValueError:
            continue
        if isinstance(row, dict) and 'tests' in row and 'snapshot_elapsed' in row:
            reports.append(row)
    if not reports:
        raise RuntimeError(f'No fresh micro-profile report; see {folder / "engine.log"}')
    report = reports[-1]
    report['roster_sha256'] = hashlib.sha256(args.roster.read_bytes()).hexdigest()
    report['source_sha256'] = {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
                               for name in ['scripts/cave_world.gd', 'tools/profile_late_cave.gd']}
    (folder / 'profile.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
