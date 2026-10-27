"""Read a compact, recent window from a running isolated playtest journal."""
import argparse
import json
from pathlib import Path

from analyze_playtest import window


def inspect(folder, seconds):
    status = json.loads((folder / 'status.json').read_text(encoding='utf-8-sig'))
    session = Path(status['log_path']).resolve()
    if not session.is_relative_to(folder):
        raise ValueError('Journal is outside the isolated playtest directory')
    sessions = {p.name: p for p in (folder / 'collected-logs').glob('run-*')}
    sessions.update({p.name: p for p in session.parent.glob('run-*')})
    rows = []
    start = max(0, status['run_elapsed'] - seconds)
    # Most summaries are tiny; skip old sessions by reading newest first.
    for path in sorted(sessions.values(), key=lambda p: p.name, reverse=True):
        values = []
        for part in sorted(path.glob('part-*.jsonl')):
            for line in part.read_text(encoding='utf-8').splitlines():
                try:
                    row = json.loads(line)
                except ValueError:
                    continue  # A still-open writer can have an incomplete last line.
                values.append(row)
        rows.extend(values)
        elapsed = [r['run_elapsed'] for r in values if 'run_elapsed' in r]
        if elapsed and min(elapsed) <= start:
            break
    rows.sort(key=lambda r: r.get('run_elapsed', -1))
    summary = window(rows, start, status['run_elapsed'] + .001)
    result = {'status': {k: status.get(k) for k in [
        'run_elapsed', 'wall_seconds', 'screen', 'done', 'fps_5s', 'hp',
        'parts', 'actors', 'actor_kinds', 'boss_kills', 'boss_distance',
        'kills', 'ore', 'goal_kind', 'position', 'pilot_last_decision_us']}}
    if summary:
        result['recent'] = {k: summary[k] for k in [
            'start', 'end', 'frames', 'fps_from_mean_interval', 'weighted_main_cpu_ms']}
        result['phases'] = summary['sampled_nested_phases']
        counts = summary['last_counts']
        result['counts'] = {k: counts.get(k) for k in [
            'sweep_result_entries', 'sweep_result_hits', 'sweep_result_misses',
            'visible_actors_sample', 'bullets', 'effects', 'draw_calls',
            'nav_prepare_us', 'terrain_geometry', 'collision_rows', 'video_memory_bytes']}
        counted = [r for r in rows if r.get('type') == 'summary'
                   and r.get('counts') and r.get('run_elapsed', -1) >= start]
        if len(counted) >= 2:
            first, last = counted[0]['counts'], counted[-1]['counts']
            hits = last.get('sweep_result_hits', 0) - first.get('sweep_result_hits', 0)
            misses = last.get('sweep_result_misses', 0) - first.get('sweep_result_misses', 0)
            result['recent_sweep_queries'] = {'hits': hits, 'misses': misses,
                                             'hit_percent': 100 * hits / max(1, hits + misses)}
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--seconds', type=float, default=60)
    args = parser.parse_args()
    print(json.dumps(inspect(args.folder.resolve(), args.seconds), ensure_ascii=False, indent=2))
