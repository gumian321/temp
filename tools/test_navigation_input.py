"""Real keyboard/mouse intro, reward-pool and loading navigation."""
from pathlib import Path
exec(Path(__file__).with_name('test_real_input.py').read_text().split('report.unlink(missing_ok=True)')[0])
report.unlink(missing_ok=True)
env=os.environ|{'DISPLAY':':99','XDG_DATA_HOME':'/workspace/scratch/navigation-ui-data','XDG_CONFIG_HOME':'/workspace/scratch/navigation-ui-config','XDG_CACHE_HOME':'/workspace/scratch/cache'}
log=open(R/'artifacts/navigation-input.log','w');p=subprocess.Popen(['godot','--path',str(R),'--audio-driver','Dummy','--','--ui-probe'],env=env,stdout=log,stderr=subprocess.STDOUT)
try:
 for _ in range(200):
  if report.exists():break
  time.sleep(.1)
 wait_screen('intro');key(0x20);wait_screen('home')
 click(lambda b:'Start' in b['name']);wait_screen('menu')
 click(lambda b:b['name']=='ToggleResButton');wait_screen('reward_pool');key(0xff1b);wait_screen('menu')
 click(lambda b:b['name']=='Play Button');wait_screen('loading')
 before=state()['head'];key(0xff09);assert state()['screen']=='loading' and state()['head']==before;checks.append('Tab changes tip while world remains paused')
 key(0x20);wait_screen('game');key(0xff1b);wait_screen('pause')
 click(lambda b:'Main Menu' in b['name']);wait_screen('home');click(lambda b:'Exit' in b['name']);p.wait(timeout=10)
 result={'passed':len(checks),'checks':checks,'exit_code':p.returncode}
except Exception as e:result={'passed':len(checks),'checks':checks,'error':repr(e)};p.terminate();p.wait(timeout=10)
finally:log.close()
(R/'artifacts/navigation-input-report.json').write_text(json.dumps(result,indent=2));print(json.dumps(result));raise SystemExit(1 if 'error'in result else 0)
