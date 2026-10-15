#!/usr/bin/env python3
"""Interleave native A/B runs in one time window; keep real density/signatures."""
import json, os, subprocess, sys
from pathlib import Path
R=Path(__file__).resolve().parents[1];O=R/'artifacts'/'round14';BASE=Path('/workspace/shared/centipede-round14-baseline')
all_runs={'matched-before':[],'optimized':[]};examples={}
for pair in range(1,4):
 for label,project in [('matched-before',BASE),('optimized',R)]:
  folder=O/'matched-pairs'/f'pair-{pair}';folder.mkdir(parents=True,exist_ok=True)
  with (folder/f'{label}-console.log').open('w') as log:
   subprocess.run([sys.executable,str(R/'tools/benchmark_dense_combat.py'),'--project',str(project),'--label','round14-'+label,'--mode','render','--repeats','1','--output',str(folder)],env=os.environ,cwd=R,stdout=log,stderr=subprocess.STDOUT,check=True)
  summary=json.loads((folder/f'dense-render-round14-{label}-summary.json').read_text());examples[label]=summary;all_runs[label]+=summary['runs']
  print(json.dumps({'pair':pair,'variant':label,'frame_ms':summary['runs'][0]['frame_ms'],'main_draw_build_ms':summary['runs'][0]['main_draw_build_ms'],'draw_calls':summary['runs'][0]['draw_calls']}),flush=True)
for label,runs in all_runs.items():
 s=examples[label];s['runs']=runs;s['signatures_match']=all(r['signature']==runs[0]['signature'] for r in runs);s['order']='before1, after1, before2, after2, before3, after3'
 (O/f'dense-render-round14-{label}-summary.json').write_text(json.dumps(s,indent=2)+'\n')
