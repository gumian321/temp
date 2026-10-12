"""Real mouse operations; explicit initial modules/action-count fixture only."""
from pathlib import Path
exec(Path(__file__).with_name('test_real_input.py').read_text().split('report.unlink(missing_ok=True)')[0])
report.unlink(missing_ok=True)
env=os.environ|{'DISPLAY':':99','XDG_DATA_HOME':'/workspace/scratch/operations-ui-data','XDG_CONFIG_HOME':'/workspace/scratch/operations-ui-config','XDG_CACHE_HOME':'/workspace/scratch/cache'}
log=open(R/'artifacts/operations-input.log','w');p=subprocess.Popen(['godot','--path',str(R),'--audio-driver','Dummy','--','--ui-probe','--operations-input-fixture'],env=env,stdout=log,stderr=subprocess.STDOUT)
def cell(cx,cy):
 s=state();px=720+cx*46;py=440-cy*46
 t.XTestFakeMotionEvent(d,-1,int(px*s['window_size'][0]/1440+s['window_position'][0]),int(py*s['window_size'][1]/900+s['window_position'][1]),0);t.XTestFakeButtonEvent(d,1,1,0);t.XTestFakeButtonEvent(d,1,0,0);x.XFlush(d);time.sleep(.6)
try:
 for _ in range(200):
  if report.exists():break
  time.sleep(.1)
 wait_screen('build')
 click(lambda b:b['text'].startswith('MOVE'));cell(-1,0);cell(0,-1)
 assert state()['actions']['move']==0 and any(e['x']==0 and e['y']==-1 for e in state()['layout']);checks.append('Mouse move relocated module and consumed one move')
 before={e['id']:(e['x'],e['y']) for e in state()['layout']}
 click(lambda b:b['text'].startswith('SWAP'));cell(0,-1);cell(-1,1)
 assert state()['actions']['swap']==0 and all((e['x'],e['y'])!=before[e['id']] for e in state()['layout'][1:]);checks.append('Mouse swap exchanged both modules and consumed one swap')
 click(lambda b:b['text'].startswith('DUPLICATE'));cell(-1,1);cell(-2,1)
 assert state()['actions']['duplicate']==0 and state()['parts']==4;checks.append('Mouse duplicate produced adjacent copy and consumed one action')
 click(lambda b:b['text'].startswith('WALL'));cell(-2,1)
 assert state()['actions']['wall']==0 and any(e['wall'] for e in state()['layout']);checks.append('Mouse reinforcement added wall and consumed one action')
 wait_screen('game')
 key(0xff1b);wait_screen('pause');click(lambda b:'Main Menu' in b['name']);wait_screen('home');click(lambda b:'Exit' in b['name']);p.wait(timeout=10)
 result={'passed':len(checks),'checks':checks,'exit_code':p.returncode,'fixture':'Two source modules and one of each construction operation at start; all subsequent edits through physical X11 input.'}
except Exception as e:result={'passed':len(checks),'checks':checks,'error':repr(e)};p.terminate();p.wait(timeout=10)
finally:log.close()
(R/'artifacts/operations-input-report.json').write_text(json.dumps(result,indent=2));print(json.dumps(result));raise SystemExit(1 if 'error'in result else 0)
