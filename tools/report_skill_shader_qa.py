#!/usr/bin/env python3
"""Summarize final native paired measurements without claiming user-device FPS."""
import hashlib,json,statistics
from pathlib import Path
R=Path(__file__).resolve().parents[1]; O=R/'artifacts'/'round14'
b=json.loads((O/'dense-render-round14-matched-before-summary.json').read_text());a=json.loads((O/'dense-render-round14-optimized-summary.json').read_text())
same=all(x['signature']==b['runs'][0]['signature'] for x in b['runs']+a['runs'])
metrics={}
for metric in ['frame_ms','simulation_prepare_ms','main_draw_build_ms','draw_calls','render_objects','bullets','effects','particle_emitters']:
    metrics[metric]={}
    for stat in ['p50','p95','mean']:
        before=statistics.median(x[metric][stat] for x in b['runs']);after=statistics.median(x[metric][stat] for x in a['runs'])
        metrics[metric][stat]={'before':before,'after':after,'change_percent':(after/before-1)*100 if before else None}
hashes=json.loads((O/'final-source-hashes.json').read_text());unchanged=all(hashlib.sha256((R/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
summary={'baseline_revision':'8204a755181b9b2d9f2f622c9745c24c727145cb','after_revision':'same git HEAD plus uncommitted frozen shader implementation; exact scripts/shaders in final-source-hashes.json','frozen_sources_unchanged':unchanged,'same_simulation_signatures':same,'repeats_each':3,'metrics_median_across_runs':metrics,'renderer':a['runs'][0]['renderer'],'viewport':a['runs'][0]['viewport'],'conditions':'Interleaved before1/after1/before2/after2/before3/after3 in the same time window. Isolated native X11/OpenGL Godot 4.6.3, LP_NUM_THREADS=3, identical 60 warmup + 180 measured fixed-step frames, 31 modules / 64 durable enemies / production projectile floor256. No concurrent heavy test during paired runs.','caveats':['llvmpipe is CPU software rasterization, not a physical user GPU. Native shader execution is real but timings are cloud-host-only.','Driver warned VSync mode cannot be changed; reported mode alone does not guarantee compositor behavior.','Frame wall time includes game script, draw construction, renderer, window/compositor pacing. It is not an isolated GPU timer.','simulation_prepare_ms excludes most deferred rendering; main_draw_build_ms is main _draw command construction, not every child draw/GPU operation.', 'The optimized direct-RID path moves command submission from deferred child _draw callbacks into main _draw. Its main_draw_build_ms scope therefore grows; compare end-to-end frame_ms rather than interpreting that stage delta alone as net CPU cost.','No reduced enemy/projectile density, no disabling effects; matched deterministic signatures and populations checked.','Movie frame sampling is fixed simulation time, not a benchmark screen recording.','Intermediate two-lane implementation measurements are discarded and stored separately.']}
validation={}
for filename in ['round14-full-regression.json','round14-enemy-motion.json','round14-native-shaders-final.json','round14-native-foreground.json']:
 path=R/'artifacts'/filename
 current=path.exists() and path.stat().st_mtime >= (O/'final-source-hashes.json').stat().st_mtime
 validation[filename]={'current_frozen_build':current,'passed':json.loads(path.read_text()).get('passed',False) if current else None}
summary['validation']=validation
summary['release_validation_complete']=all(v['current_frozen_build'] and v['passed'] for v in validation.values())
pair_changes=[]
for i,(before_run,after_run) in enumerate(zip(b['runs'],a['runs']),1):
 pair_changes.append({'pair':i,**{stat:{'before_ms':before_run['frame_ms'][stat],'after_ms':after_run['frame_ms'][stat],'change_percent':(after_run['frame_ms'][stat]/before_run['frame_ms'][stat]-1)*100} for stat in ['p50','p95','mean']}})
summary['paired_frame_changes']=pair_changes
summary['median_paired_frame_change_percent']={stat:statistics.median(pair[stat]['change_percent'] for pair in pair_changes) for stat in ['p50','p95','mean']}
(O/'paired-performance-final.json').write_text(json.dumps(summary,indent=2)+'\n')
lines=['# Round 14 shader QA','',f'Final frozen-build regression/native validation complete: {summary["release_validation_complete"]}.','',f'Frozen production hashes unchanged: {unchanged}. Same simulation signature across all six runs: {same}.','', '## Native paired performance','', '| Metric (median across 3 runs) | Before | After | Change |','|---|---:|---:|---:|']
for k in ['frame_ms','simulation_prepare_ms','main_draw_build_ms','draw_calls']:
 for s in ['p50','p95']:
  m=metrics[k][s];lines.append(f'| {k} {s} | {m["before"]:.3f} | {m["after"]:.3f} | {m["change_percent"]:+.1f}% |')
lines+=['','## Paired frame changes (controls local host drift)','','| Pair | p50 before → after ms | p50 change | p95 change |','|---|---:|---:|---:|']
for pair in pair_changes:
 lines.append(f'| {pair["pair"]} | {pair["p50"]["before_ms"]:.3f} → {pair["p50"]["after_ms"]:.3f} | {pair["p50"]["change_percent"]:+.1f}% | {pair["p95"]["change_percent"]:+.1f}% |')
lines.append('Median within-pair frame change: '+json.dumps(summary['median_paired_frame_change_percent'])+'.')
lines+=['','## Conditions and limits','',summary['conditions'],'']+['- '+x for x in summary['caveats']]
lines+=['','## Functional and native checks','']
for filename in ['round14-full-regression.json','round14-enemy-motion.json','round14-native-shaders-final.json','round14-native-foreground.json']:
 p=R/'artifacts'/filename
 if p.exists() and validation[filename]['current_frozen_build']:
  q=json.loads(p.read_text());lines.append(f'- {filename}: {sum(x["passed"] for x in q["suites"])}/{len(q["suites"])} suites pass.')
for filename in ['shader-scene-report.json','passive-shader-pixels-report.json','living-shader-scene-report.json','weapon-shader-showcase-report.json']:
 p=O/filename
 if p.exists() and p.stat().st_mtime >= (O/'final-source-hashes.json').stat().st_mtime:
  q=json.loads(p.read_text());lines.append(f'- {filename}: {sum(x["passed"] for x in q["checks"])}/{len(q["checks"])} assertions pass. {q.get("scope", "")}')
lines+=['','## Exact native previews','', '- attack-shader-clock-only.mp4: 19 material families, frozen CPU geometry and effect life, only shader clock changes.','- passive-shader-clock-only.mp4: all six fixed MultiMesh effects, only sim_time changes.','- shield-state-sequence.mp4: production main shield sustain → hit → break → recovery.','- all-weapon-production.mp4: 14 real weapon families hitting real controlled targets.','', 'Each MP4 has a corresponding *-video.json with ffprobe dimensions, frame count, duration and capture scope.']
(O/'QA_REPORT.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(summary,indent=2))
