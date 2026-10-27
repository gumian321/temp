"""Archive complete live journal lines before rotation and finish a bounded pilot run."""
import argparse
import datetime
import json
from pathlib import Path
import shutil
import time


def read(path):
    try:
        return json.loads(path.read_text(encoding='utf-8-sig'))
    except (OSError, ValueError):
        return None


def archive_parts(folder, state, retained):
    session = Path(state['log_path']).resolve()
    if not session.is_relative_to(folder):
        raise RuntimeError('Log session escaped isolated playtest folder')
    destination = folder / 'collected-logs' / session.name
    destination.mkdir(parents=True, exist_ok=True)
    for source in sorted(session.glob('part-*.jsonl')):
        target = destination / source.name
        offset = target.stat().st_size if target.exists() else 0
        with source.open('rb') as input_file:
            input_file.seek(offset)
            tail = input_file.read()
        complete = tail.rfind(b'\n') + 1
        if complete:
            with target.open('ab') as output:
                output.write(tail[:complete])
        retained.add((session.name, source.name))
    marker = session / 'session.json'
    if marker.is_file():
        shutil.copy2(marker, destination / marker.name)
    return session


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--seconds', type=float, default=1800)
    parser.add_argument('--maximum-wall-seconds', type=float, default=7200)
    args = parser.parse_args()
    folder = args.folder.resolve()
    began = time.monotonic()
    next_notice = 0
    retained = set()
    while time.monotonic() - began < args.maximum_wall_seconds:
        state = read(folder / 'status.json')
        if state and state.get('log_path'):
            session = archive_parts(folder, state, retained)
            if time.monotonic() >= next_notice:
                next_notice = time.monotonic() + 45
                print(json.dumps({key: state.get(key) for key in ['run_elapsed', 'hp', 'parts', 'actors', 'fps_5s', 'done']}), flush=True)
            marker = read(session / 'session.json')
            if state.get('done') and marker and marker.get('closed'):
                archive_parts(folder, state, retained)
                evidence = folder / 'stop-states'
                evidence.mkdir(exist_ok=True)
                for name in ['status.json', 'gameplay-state.json', 'battle-state.bin', 'collision-replay.bin']:
                    source = folder / name
                    if source.is_file():
                        shutil.copy2(source, evidence / f'{int(state["run_elapsed"]):04d}-{name}')
                result = {'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                          'completed_duration': state['run_elapsed'] >= args.seconds,
                          'requested_active_seconds': args.seconds, 'final_status': state,
                          'retained_parts': len(retained), 'scope': 'Native normal-rules real-clock run; menus and pauses excluded by runtime active-frame counters.'}
                (folder / 'acceptance-stop.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
                temporary = folder / 'recorder-command.tmp'
                temporary.write_text(json.dumps({'action': 'quit', 'nonce': time.time_ns()}), encoding='utf-8')
                temporary.replace(folder / 'command.json')
                print(json.dumps({'completed_duration': result['completed_duration'], 'elapsed': state['run_elapsed'], 'recorded_parts': len(retained)}), flush=True)
                return 0
        time.sleep(2)
    raise RuntimeError('Acceptance recorder wall-clock limit reached; inspect the isolated run')


if __name__ == '__main__':
    raise SystemExit(main())
