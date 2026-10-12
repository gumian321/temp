import os,subprocess,json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
base=os.environ|{'DISPLAY':':99','RBPEW_PROFILE':'1','RBPEW_REVISION':'optimization-working','RBPEW_CAPTURE_DIR':str(R/'artifacts/benchmarks'),'XDG_DATA_HOME':'/workspace/scratch/benchmark-data','XDG_CONFIG_HOME':'/workspace/scratch/xdg-config','XDG_CACHE_HOME':'/workspace/scratch/cache'}
results=[]
for label,bg,atlas in [('original-render',True,True),('shader-only',False,True)]:
 env=base|{'RBPEW_BENCH_LABEL':label,'RBPEW_BACKGROUND_ORIGINAL':'1'if bg else'0','RBPEW_ATLAS_ORIGINAL':'1'if atlas else'0'}
 p=subprocess.run(['godot','--path',str(R),'--audio-driver','Dummy','--script','tests/benchmark_render.gd'],env=env,capture_output=True,text=True,timeout=90);(R/f'artifacts/{label}.log').write_text(p.stdout+p.stderr)
 if p.returncode or 'ERROR:'in p.stdout+p.stderr:raise RuntimeError(label+' engine error')
 result=json.loads((R/f'artifacts/{label}-render-benchmark.json').read_text());results.append(result);print(label,result['fps'],result['median_draw_calls'],flush=True)
(R/'artifacts/render-variants-report.json').write_text(json.dumps(results,indent=2))
