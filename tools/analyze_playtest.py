"""Combine retained log segments from one continued conservative playtest."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import statistics


def read_rows(folder):
    rows = []
    bad = 0
    for path in sorted((folder/'collected-logs').rglob('part-*.jsonl')):
        for line in path.read_text(encoding='utf-8').splitlines():
            if not line:
                continue
            try:
                row = json.loads(line)
            except ValueError:
                bad += 1
                continue
            rows.append(row)
    return rows, bad


def window(rows, start, end):
    selected = [r for r in rows if start <= r.get('run_elapsed', -1) < end]
    summaries = [r for r in selected if r.get('type') == 'summary']
    detail = [r for r in selected if r.get('type') == 'detail']
    frames = sum(r['frames'] for r in summaries)
    if not frames:
        return None
    mean = sum(r['frames']*r['frame_ms']['mean'] for r in summaries)/frames
    phases = {}
    for group in ['main_us', 'combat_us']:
        values = defaultdict(list)
        for r in detail:
            for key, value in r.get(group, {}).items():
                values[key].append(value/1000)
        phases[group] = sorted([{'phase':k, 'sample_mean_ms':statistics.mean(v), 'samples':len(v)} for k,v in values.items()], key=lambda x:-x['sample_mean_ms'])
    counted = sorted([r for r in summaries if r.get('counts')], key=lambda r:r['run_elapsed'])
    statuses = [r['data'] for r in selected if r.get('type') == 'pilot_status']
    return {'start':start, 'end':end, 'frames':frames, 'weighted_mean_frame_ms':mean, 'fps_from_mean_interval':1000/mean,
            'weighted_main_cpu_ms':sum(r['frames']*r['cpu_ms']['mean'] for r in summaries)/frames,
            'sampled_nested_phases':phases, 'last_counts':counted[-1]['counts'] if counted else {},
            'last_actor_kinds':statuses[-1].get('actor_kinds',{}) if statuses else {}}


def plot(report, output):
    # A self-contained SVG for this engineering trace; no web/CDN dependency.
    from html import escape
    import math
    bins = report['thirty_second_windows']
    xvalues = [(b['start']+b['end'])/120 for b in bins]
    width, height, left, right = 1100, 950, 90, 40
    chart_width = width-left-right
    chunks = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
              '<style>text{font-family:Arial,Segoe UI,sans-serif;fill:#26323b} .small{font-size:13px} .tick{font-size:12px;fill:#6c747b}</style>',
              '<rect width="100%" height="100%" fill="#faf9f6"/>',
              '<text x="90" y="38" font-size="24" font-weight="bold">30-minute real-time cautious playtest</text>',
              '<text x="90" y="63" class="small">Normal rules / no boss kills / isolated progress copy / active time, pauses excluded</text>']
    ai = [next((p['sample_mean_ms'] for p in b['sampled_nested_phases']['combat_us'] if p['phase']=='enemy_ai'),float('nan')) for b in bins]
    panels = [
        (115,120,'FPS (30-second weighted mean)',[(60,'60 FPS')],[(xvalues,[b['fps_from_mean_interval'] for b in bins],'#b83152','FPS')]),
        (385,50,'Time (ms)',[(1000/60,'16.67 ms budget')],[(xvalues,[b['weighted_main_cpu_ms'] for b in bins],'#355f7c','Main process CPU'),(xvalues,ai,'#ac811f','Enemy AI (sampled, nested)')]),
        (655,400,'Actor / module count',[],[(xvalues,[b['last_counts'].get('actors',float('nan')) for b in bins],'#754d86','Total actors'),(xvalues,[b['last_counts'].get('parts',float('nan'))-1 for b in bins],'#347f72','Body modules')])]
    panel_height = 180
    for top, maximum, title, reference, series in panels:
        ycoord=lambda value:top+panel_height-value/maximum*panel_height
        xcoord=lambda value:left+value/30.5*chart_width
        chunks.append(f'<text x="{left}" y="{top-32}" font-size="17" font-weight="bold">{escape(title)}</text>')
        for value in [maximum*i/(6 if top==115 else 5) for i in range(7 if top==115 else 6)]:
            y=ycoord(value)
            chunks.append(f'<line x1="{left}" x2="{width-right}" y1="{y}" y2="{y}" stroke="#d9dddf" stroke-width=".8"/>')
            chunks.append(f'<text x="{left-12}" y="{y+4}" text-anchor="end" class="tick">{value:g}</text>')
        for minute in range(0,31,5):
            x=xcoord(minute)
            chunks.append(f'<line x1="{x}" x2="{x}" y1="{top}" y2="{top+panel_height}" stroke="#e1e3e4" stroke-width=".8"/>')
            if top==655:chunks.append(f'<text x="{x}" y="{top+panel_height+23}" text-anchor="middle" class="tick">{minute}</text>')
        if top==115:
            chunks.append(f'<rect x="{left}" y="{ycoord(30)}" width="{chart_width}" height="{ycoord(20)-ycoord(30)}" fill="#b83152" opacity=".09"/>')
        for value,label in reference:
            y=ycoord(value)
            chunks.append(f'<line x1="{left}" x2="{width-right}" y1="{y}" y2="{y}" stroke="#51836a" stroke-dasharray="5 4"/>')
            chunks.append(f'<text x="{width-right}" y="{y-5}" text-anchor="end" class="tick">{escape(label)}</text>')
        for index,(xs,ys,color,label) in enumerate(series):
            points=[(xcoord(x),ycoord(y),x,y) for x,y in zip(xs,ys) if math.isfinite(y)]
            path=' '.join(('M' if i==0 else 'L')+f'{x:.2f},{y:.2f}' for i,(x,y,_,__) in enumerate(points))
            chunks.append(f'<path d="{path}" fill="none" stroke="{color}" stroke-width="2.5"/>')
            for x,y,minute,value in points:
                chunks.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="2.2" fill="{color}"><title>{escape(label)}: {value:.2f} at {minute:.2f} min</title></circle>')
            legend_x=left+index*275
            chunks.append(f'<line x1="{legend_x}" x2="{legend_x+22}" y1="{top-13}" y2="{top-13}" stroke="{color}" stroke-width="2.5"/>')
            chunks.append(f'<text x="{legend_x+30}" y="{top-9}" class="small">{escape(label)}</text>')
    chunks.extend(['<text x="575" y="890" text-anchor="middle" font-size="16">Active in-game time (minutes)</text>',
                   '<text x="90" y="923" class="small">AI phases are short-window samples, nested and biased toward slow windows. Not an optimization A/B.</text>','</svg>'])
    output.write_text('\n'.join(chunks),encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path)
    parser.add_argument('--plot',action='store_true')
    args = parser.parse_args()
    rows,bad = read_rows(args.folder)
    captures=sorted((args.folder/'stop-states').glob('*-status.json'),key=lambda p:int(p.name.split('-')[0]))
    status=json.loads((captures[-1] if captures else args.folder/'status.json').read_text(encoding='utf-8'))
    headers=[r for r in rows if r.get('type')=='header']
    summaries=[r for r in rows if r.get('type')=='summary']
    markers=[r for r in rows if r.get('type') in ['marker','slow_trigger','session_end']]
    milestones=[window(rows,*span) for span in [(0,60),(240,300),(540,600),(900,960),(1440,1500),(1680,1807)]]
    bins=[window(rows,start,start+30) for start in range(0,1801,30)]
    report={'scope':'One real-clock normal-rules battle, continued across recorder segments. Periodic automatic diagnostic stops, upgrades and menus exclude paused time. Controller is automated; this is not a human manual playthrough or an optimization A/B.',
            'run_elapsed':status['run_elapsed'],'wall_seconds':status['wall_seconds'],'segments':len(headers),'invalid_lines':bad,
            'all_real_clock_release_normal_rules':all(not r.get('fixture') and not r.get('synthetic_clock') and not r.get('debug_build') for r in headers),
            'no_reported_drops_or_write_errors':all(not r.get('writer',{}).get('error') and not r.get('writer',{}).get('dropped_lines',0) for r in rows),
            'active_frames':sum(r['frames'] for r in summaries),'active_wall_seconds':sum(r['frames']*r['frame_ms']['mean']/1000 for r in summaries),'final_status':status,
            'milestones':milestones,'thirty_second_windows':[b for b in bins if b],
            'event_count':len(markers),'source_fingerprints':headers[0]['sources'],'renderer':{k:headers[0].get(k) for k in ['engine','gpu','renderer','window_size','vsync_mode','refresh_rate']}}
    report['overall_fps'] = report['active_frames']/report['active_wall_seconds'] if report['active_wall_seconds'] else None
    draw_rows = [r for r in summaries if r.get('draw_calls',{}).get('frames',0)>0]
    draw_frames = sum(r['draw_calls']['frames'] for r in draw_rows)
    report['draw_calls'] = {'frames':draw_frames, 'mean':sum(r['draw_calls']['mean']*r['draw_calls']['frames'] for r in draw_rows)/draw_frames if draw_frames else None,
                            'scope':'Weighted by explicitly logged per-frame draw samples; older summary formats may have no DC block.'}
    totals = [r['active_totals'] for r in rows if r.get('type')=='session_end' and r.get('active_totals')]
    report['cumulative_totals'] = {'sessions':len(totals),'frames':sum(r['frames'] for r in totals),'microseconds':sum(r['microseconds'] for r in totals)}
    coverage = bool(totals) and report['cumulative_totals']['frames']==report['active_frames'] and abs(report['cumulative_totals']['microseconds']/1e6-report['active_wall_seconds'])<.00001
    report['complete_summary_coverage'] = coverage
    report['acceptance_30min_above50'] = bool(status['run_elapsed']>=1800 and report['overall_fps'] is not None and report['overall_fps']>50 and coverage and report['all_real_clock_release_normal_rules'] and report['no_reported_drops_or_write_errors'] and bad==0)
    launch_path=args.folder/'launch.json'
    if launch_path.is_file() and json.loads(launch_path.read_text(encoding='utf-8')).get('continuous_controller'):
        report['scope']='One continuous real-clock normal-rules release battle with ordinary automated controls; no diagnostic slow-frame auto-pauses. Menus excluded from active-frame totals. Not an optimization A/B.'
    output=args.folder/'longrun-analysis.json';output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if args.plot:plot(report,args.folder/'longrun-trend.svg')
    print(json.dumps({'output':str(output),'seconds':status['run_elapsed'],'frames':report['active_frames'],'segments':report['segments'],'invalid_lines':bad,
                      'milestones':[{k:b[k] for k in ['start','end','fps_from_mean_interval','weighted_main_cpu_ms']} for b in milestones if b]},ensure_ascii=False))


if __name__=='__main__':main()
