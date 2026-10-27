"""Retain closed diagnostic segments and continue the same normal-rules run."""
import argparse
import json
from pathlib import Path
import shutil
import time


def read(path):
    try:
        return json.loads(path.read_text(encoding='utf-8-sig'))
    except (OSError, ValueError):
        return None


def end_reason(session):
    files = sorted(session.glob('part-*.jsonl'))
    if not files:
        return None
    for line in reversed(files[-1].read_text(encoding='utf-8').splitlines()):
        try:
            row = json.loads(line)
        except ValueError:
            continue
        if row.get('type') == 'session_end':
            return row.get('reason')
    return None


def command(folder, action):
    temporary = folder/'watch-command.tmp'
    temporary.write_text(json.dumps({'action': action, 'nonce': time.time_ns()}), encoding='utf-8')
    temporary.replace(folder/'command.json')


def retain(folder, log_root, elapsed):
    archive = folder/'collected-logs'
    archive.mkdir(exist_ok=True)
    for session in log_root.glob('run-*'):
        marker = read(session/'session.json')
        if marker and marker.get('owner') == 'rbpew-performance-log-v1' and marker.get('closed'):
            target = archive/session.name
            if not target.exists():
                shutil.copytree(session, target)
    evidence = folder/'stop-states'
    evidence.mkdir(exist_ok=True)
    for filename in ['gameplay-state.json', 'status.json', 'collision-replay.bin', 'battle-state.bin']:
        if (folder/filename).is_file():
            shutil.copy2(folder/filename, evidence/f'{int(elapsed):04d}-{filename}')
    image = folder/'sustained_slow_frames.png'
    if image.is_file():
        shutil.copy2(image, evidence/f'{int(elapsed):04d}.png')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--seconds', type=float, default=1800)
    args = parser.parse_args()
    folder = args.folder.resolve()
    last_resumed = ''
    requested_pause = False
    next_notice = 0
    while not (folder/'watch-stop.request').exists():
        status = read(folder/'status.json')
        if not status or not status.get('log_path'):
            time.sleep(2)
            continue
        session = Path(status['log_path']).resolve()
        if not session.is_relative_to(folder):
            raise RuntimeError('Journal escaped the isolated playtest directory')
        elapsed = status['run_elapsed']
        if elapsed >= args.seconds and not status['done'] and not requested_pause:
            command(folder, 'pause')
            requested_pause = True
        if status['done']:
            marker = read(session/'session.json')
            if not marker or not marker.get('closed'):
                time.sleep(2)
                continue
            retain(folder, session.parent, elapsed)
            reason = end_reason(session)
            if str(session) != last_resumed:
                print(json.dumps({'run_elapsed': elapsed, 'hp': status['hp'], 'parts': status['parts'],
                                  'actors': status['actors'], 'reason': reason,
                                  'same_run_continues': elapsed < args.seconds and reason == 'sustained_slow_frames'}, ensure_ascii=False), flush=True)
            if elapsed >= args.seconds or reason != 'sustained_slow_frames':
                break
            if str(session) != last_resumed:
                last_resumed = str(session)
                command(folder, 'resume')
        if time.monotonic() >= next_notice:
            next_notice = time.monotonic()+60
            print(json.dumps({k:status[k] for k in ['run_elapsed','hp','parts','actors','fps_5s','done']}, ensure_ascii=False), flush=True)
        time.sleep(2)


if __name__ == '__main__':
    main()
