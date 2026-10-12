"""Compare deterministic combat state before/after optimization, using a pinned local commit."""
import subprocess,os,tempfile,json
from pathlib import Path
R=Path(__file__).resolve().parents[1];base='cac76a1948a4362aa1f296e2cfc3d751c4c30070'
with tempfile.TemporaryDirectory(prefix='pew-differential-') as tmp:
 tmp=Path(tmp);reference=tmp/'reference.gd';reference.write_bytes(subprocess.check_output(['git','show',base+':scripts/combat.gd'],cwd=R))
 results=[]
 for label,path in [('before',str(reference)),('after','res://scripts/combat.gd')]:
  out=tmp/(label+'.json');env=os.environ|{'XDG_DATA_HOME':'/workspace/scratch/diff-data','XDG_CONFIG_HOME':'/workspace/scratch/xdg-config','XDG_CACHE_HOME':'/workspace/scratch/cache','RBPEW_BATTLE_SCRIPT':path,'RBPEW_COMPARISON_OUTPUT':str(out)}
  p=subprocess.run(['godot','--headless','--path',str(R),'--script','tests/compare_combat.gd'],env=env,capture_output=True,text=True,timeout=90);(R/f'artifacts/differential-{label}.log').write_text(p.stdout+p.stderr)
  if p.returncode or 'ERROR:'in p.stdout+p.stderr:raise RuntimeError(label+' engine error')
  results.append(json.loads(out.read_text()))
 differences=[{'index':i,'scenario':a['scenario'],'frame':a['frame']} for i,(a,b) in enumerate(zip(*results)) if a!=b]
 report={'baseline_commit':base,'snapshots':len(results[0]),'scenarios':sorted(set(x['scenario']for x in results[0])),'equal_counts':len(results[0])==len(results[1]),'differences':differences,'passed':results[0]==results[1]}
 (R/'artifacts/combat-differential-report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));raise SystemExit(0 if report['passed']else 1)
