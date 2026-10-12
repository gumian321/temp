"""Physical reward/build input with one explicitly injected reward-pack fixture."""
from pathlib import Path
exec(Path(__file__).with_name('test_real_input.py').read_text().split('report.unlink(missing_ok=True)')[0])
report.unlink(missing_ok=True)
env=os.environ|{'DISPLAY':':99','XDG_DATA_HOME':'/workspace/scratch/build-ui-data','XDG_CONFIG_HOME':'/workspace/scratch/build-ui-config','XDG_CACHE_HOME':'/workspace/scratch/cache'}
log=open(R/'artifacts/build-input.log','w');p=subprocess.Popen(['godot','--path',str(R),'--audio-driver','Dummy','--','--ui-probe','--build-input-fixture'],env=env,stdout=log,stderr=subprocess.STDOUT)
def click_at(px,py):
 s=state();t.XTestFakeMotionEvent(d,-1,int(px*s['window_size'][0]/1440+s['window_position'][0]),int(py*s['window_size'][1]/900+s['window_position'][1]),0);t.XTestFakeButtonEvent(d,1,1,0);t.XTestFakeButtonEvent(d,1,0,0);x.XFlush(d);time.sleep(.6)
try:
 for _ in range(200):
  if report.exists():break
  time.sleep(.1)
 wait_screen('rewards')
 click(lambda b:b['name']=='RewardPanel');wait_screen('build')
 assert state()['pending']>0;checks.append('Selecting source reward card creates pending modules')
 pending=state()['pending'];key(ord('e'));assert state()['screen']=='build';checks.append('Build key cannot bypass unplaced reward')
 click_at(950,210);assert state()['pending']==pending;checks.append('Disconnected placement rejected')
 click_at(674,440);assert state()['pending']==pending-1 and state()['parts']==2;checks.append('Adjacent placement consumes pending item and adds module')
 wait_screen('game')
 key(0xff1b);wait_screen('pause');click(lambda b:'Main Menu' in b['name']);wait_screen('home');click(lambda b:'Exit' in b['name']);p.wait(timeout=10)
 result={'passed':len(checks),'checks':checks,'exit_code':p.returncode,'fixture':'One source reward pack injected before external input; no forced outcome or module placement.'}
except Exception as e:
 result={'passed':len(checks),'checks':checks,'error':repr(e)};p.terminate();p.wait(timeout=10)
finally:log.close()
(R/'artifacts/build-input-report.json').write_text(json.dumps(result,indent=2));print(json.dumps(result));raise SystemExit(1 if 'error'in result else 0)
