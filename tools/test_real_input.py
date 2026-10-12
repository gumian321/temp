"""X11/XTest physical input acceptance; observes diagnostic state, never calls gameplay functions."""
import ctypes as C,time,json,os,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[1];report=R/'artifacts/ui-probe.json'
x=C.CDLL('libX11.so.6');t=C.CDLL('libXtst.so.6')
x.XOpenDisplay.restype=C.c_void_p;x.XOpenDisplay.argtypes=[C.c_char_p];d=x.XOpenDisplay(b':99');assert d
x.XFlush.argtypes=[C.c_void_p];x.XKeysymToKeycode.argtypes=[C.c_void_p,C.c_ulong];x.XKeysymToKeycode.restype=C.c_uint
for f,args in [('XTestFakeMotionEvent',[C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_ulong]),('XTestFakeButtonEvent',[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]),('XTestFakeKeyEvent',[C.c_void_p,C.c_uint,C.c_int,C.c_ulong])]:getattr(t,f).argtypes=args
checks=[]
def state():
 for _ in range(10):
  try:return json.loads(report.read_text())
  except (ValueError,FileNotFoundError):time.sleep(.1)
 raise RuntimeError('No state probe')
def wait_screen(name,timeout=10):
 end=time.time()+timeout
 while time.time()<end:
  if name=='game' and state()['screen']=='loading':key(0x20)
  if state()['screen']==name:checks.append('Entered '+name+' through physical input');return
  time.sleep(.1)
 raise AssertionError((name,state()))
def click(match):
 s=state();b=next(b for b in s['buttons'] if match(b));t.XTestFakeMotionEvent(d,-1,int(b['x']*s['window_size'][0]/1440+s['window_position'][0]),int(b['y']*s['window_size'][1]/900+s['window_position'][1]),0);t.XTestFakeButtonEvent(d,1,1,0);t.XTestFakeButtonEvent(d,1,0,0);x.XFlush(d);time.sleep(.7)
def key(sym,duration=.1):
 k=x.XKeysymToKeycode(d,sym);t.XTestFakeKeyEvent(d,k,1,0);x.XFlush(d);time.sleep(duration);t.XTestFakeKeyEvent(d,k,0,0);x.XFlush(d);time.sleep(.5)
report.unlink(missing_ok=True)
env=os.environ|{'DISPLAY':':99','XDG_DATA_HOME':os.environ.get('RBPEW_UI_DATA','/workspace/scratch/ui-test-data'),'XDG_CONFIG_HOME':'/workspace/scratch/ui-test-config','XDG_CACHE_HOME':'/workspace/scratch/cache'}
log=open(R/'artifacts/real-input.log','w');p=subprocess.Popen(['godot','--path',str(R),'--audio-driver','Dummy','--','--ui-probe'],env=env,stdout=log,stderr=subprocess.STDOUT)
try:
 for _ in range(200):
  if report.exists():break
  time.sleep(.1)
 wait_screen('home')
 print('HOME BUTTONS',state()['buttons'],flush=True)
 click(lambda b:'Option' in b['name']);wait_screen('options')
 key(0xff1b);wait_screen('home')
 click(lambda b:'Start' in b['name'] or 'Play Button'==b['name']);wait_screen('menu')
 print('MISSION BUTTONS',state()['buttons'],flush=True)
 click(lambda b:b['name'].lower().replace(' ','')=='playbutton');wait_screen('game')
 before=state()['head'];key(ord('d'),1);after=state()['head'];assert after[0]>before[0]+20;checks.append('WASD moves head in actual window')
 key(0xff1b);wait_screen('pause');before=state()['head'];time.sleep(.7);assert state()['head']==before;checks.append('Pause freezes movement')
 click(lambda b:'Resume' in b['name']);wait_screen('game')
 key(ord('e'));wait_screen('build');key(ord('e'));wait_screen('game')
 key(0xff1b);wait_screen('pause');click(lambda b:'Main Menu' in b['name']);wait_screen('home')
 click(lambda b:'Tree' in b['name']);wait_screen('lab');key(0xff1b);wait_screen('home')
 click(lambda b:'Start' in b['name']);wait_screen('menu');click(lambda b:b['name'].lower().replace(' ','')=='playbutton');wait_screen('game')
 wait_screen('result',180)
 checks.append('Normal combat reached death and score settlement without injecting outcome')
 click(lambda b:'Lab' in b['name']);wait_screen('lab')
 before=state()['unlocked'];currency=state()['meta']
 click(lambda b:'Cannon' in b['text'])
 click(lambda b:b['text']=='🔒 3')
 click(lambda b:'RP' in b['text'] and ('Research' in b['text'] or 'Unlock' in b['text']))
 assert state()['unlocked']>before and state()['meta']<currency
 checks.append('Research purchase spends settled currency and increases unlocked rewards')
 key(0xff1b);wait_screen('home')
 click(lambda b:'Exit' in b['name']);p.wait(timeout=10)
 result={'passed':len(checks),'checks':checks,'exit_code':p.returncode}
except Exception as e:
 result={'passed':len(checks),'checks':checks,'error':str(e)}
 p.terminate();p.wait(timeout=10)
finally:log.close()
(R/'artifacts/real-input-report.json').write_text(json.dumps(result,indent=2));print(json.dumps(result));raise SystemExit(1 if 'error'in result else 0)
