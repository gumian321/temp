"""Run bounded, isolated Godot checks and reject engine script errors even with exit zero."""
import subprocess,os,json,time,tempfile,atexit,shutil
from pathlib import Path
R=Path(__file__).resolve().parents[1]
(R/'artifacts').mkdir(exist_ok=True)
scratch=Path(tempfile.mkdtemp(prefix='centipede-checks-'))
atexit.register(shutil.rmtree,scratch,ignore_errors=True)
env=os.environ|{'XDG_DATA_HOME':str(scratch/'data'),'XDG_CONFIG_HOME':str(scratch/'config'),'XDG_CACHE_HOME':str(scratch/'cache')}
results=[]
for name in ['core','missions','map','rewards','specials','regressions','drones','reward_pool','controller','long_body','shields','turret_tracking','achievements','fuel_tutorial','enemy_drones','radar','weapon_catalog','particles','presentation','loot']:
 start=time.monotonic()
 try:
  p=subprocess.run(['godot','--headless','--path',str(R),'--script',f'res://tests/test_{name}.gd'],env=env,capture_output=True,text=True,timeout=45)
  text=p.stdout+p.stderr;success=p.returncode==0 and 'ERROR:'not in text
  record={'suite':name,'exit_code':p.returncode,'passed':success,'seconds':round(time.monotonic()-start,3)}
 except subprocess.TimeoutExpired as e:
  text=str(e);record={'suite':name,'passed':False,'error':'45-second timeout'}
 (R/f'artifacts/{name}-suite.log').write_text(text);results.append(record);print(json.dumps(record),flush=True)
report={'suites':results,'passed':all(r['passed'] for r in results)}
(R/'artifacts/consolidated-test-report.json').write_text(json.dumps(report,indent=2))
raise SystemExit(0 if report['passed'] else 1)
