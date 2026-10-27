"""Read a small journal tail without disturbing the running native playtest."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    args = parser.parse_args()
    state = json.loads((args.folder / 'status.json').read_text(encoding='utf-8-sig'))
    result = {key: state.get(key) for key in [
        'run_elapsed', 'wall_seconds', 'screen', 'done', 'fps_5s', 'hp', 'max_hp',
        'parts', 'actors', 'bullets', 'kills', 'boss_kills', 'boss_distance',
        'ore', 'fuel', 'max_fuel', 'goal_kind', 'pilot_last_decision_us']}
    files = sorted((args.folder / 'collected-logs').rglob('part-*.jsonl'))
    rows = []
    for path in files[-2:]:
        with path.open('rb') as stream:
            stream.seek(max(0, path.stat().st_size - 131072))
            lines = stream.read().splitlines()
        for line in lines:
            try:
                rows.append(json.loads(line))
            except ValueError:
                pass
    summaries = [row for row in rows if row.get('type') == 'summary']
    if summaries:
        latest = summaries[-1]
        result['active_totals'] = latest.get('active_totals')
        result['latest_cpu_ms'] = latest.get('cpu_ms', {}).get('mean')
        result['latest_counts'] = {key: latest.get('counts', {}).get(key) for key in [
            'enemy_core_frame_enabled', 'enemy_core_frame_entries', 'draw_calls',
            'terrain_chunks', 'focused', 'wall_overlap_memo_enabled',
            'ai_component_frame_enabled', 'ai_component_frame_hits',
            'spatial_build_enabled', 'near_contact_probe_enabled', 'near_contact_hits',
            'orbit_observer_pruning_enabled', 'orbit_observers_total', 'orbit_observers_kept']}
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
