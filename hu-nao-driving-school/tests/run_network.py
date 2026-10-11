"""Launch real Godot OS processes connected by ENet. Run after Godot import."""
import subprocess,pathlib,time,json,sys,os,signal
root=pathlib.Path(__file__).resolve().parents[1];out=root/'tests/results';out.mkdir(exist_ok=True)
procs=[];logs=[]
def launch(args,name):
 f=open(out/(name+'.log'),'w');logs.append(f)
 p=subprocess.Popen(args,cwd=root,stdout=f,stderr=subprocess.STDOUT);procs.append(p);return p
for suite,port,reverse in [('lan',27910,False),('impaired',27920,True),('prediction',27930,False)]:
 base=['godot','--headless','--path',str(root),'--script','tests/peer_test.gd','--']
 extra=['--host-driver'] if reverse else []
 launch(base+extra+['--host',f'--port={port}',f'--out={out}/{suite}-host.json'],suite+'-host')
 time.sleep(.5)
 client_port=port
 if suite!='lan':
  client_port=port+1
  launch([sys.executable,'tests/udp_proxy.py',f'--listen={client_port}',f'--server={port}','--seconds=47',f'--out={out}/{suite}-proxy.json'],'proxy')
  time.sleep(.2)
 client_process=launch(base+extra+[f'--port={client_port}',f'--out={out}/{suite}-client.json'],suite+'-client')
 if suite=='prediction': paused_client=client_process
try:
 # Suspend only the test client for two seconds. Host must continue simulating.
 time.sleep(10)
 paused_client.send_signal(signal.SIGSTOP)
 time.sleep(2)
 paused_client.send_signal(signal.SIGCONT)
 for p in procs:
  p.wait(timeout=65)
  assert p.returncode==0,p.returncode
finally:
 for p in procs:
  if p.poll() is None:p.kill()
 for f in logs:f.close()
checks=[]
for suite in ['lan','impaired','prediction']:
 h=json.load(open(out/(suite+'-host.json')));c=json.load(open(out/(suite+'-client.json')))
 assert len(h['rounds'])==len(c['rounds'])==2,(suite,'round count',h,c)
 assert h['rounds']==c['rounds'],(suite,'authoritative mismatch',h['rounds'],c['rounds'])
 assert [r['winner'] for r in h['rounds']]==['coach','driver'],(suite,'winners')
 assert h['rounds'][0]['counters']==1 and h['rounds'][0]['hits']==2,(suite,'pranks')
 for peer in [h,c]:
  for k in ['motion','brake','repair','disconnect_room','reconnected']:assert peer[k],(suite,k,peer)
  assert peer['max_pending']<=120 and peer['queue_peak']<=256
 assert c['snapshots']>300
 if suite=='lan': assert h['input_count']>1500, ('input frequency regressed',h['input_count'])
 text=(out/(suite+'-host.log')).read_text()+(out/(suite+'-client.log')).read_text()
 assert 'SCRIPT ERROR' not in text and 'ERROR:' not in text,text
 checks.append(suite+': 2 processes, matching round state, both roles, motion, brake, counter, hit, repair, wins, restart, both disconnect paths, reconnect')
assert json.load(open(out/'lan-host.json'))['duplicate_events']>=1
progress=json.load(open(out/'prediction-host.json'))['physics_timeline']
assert progress['13']-progress['10'] >= 150, ('slow client stalled host',progress)
json.dump({'passed':checks,'proxy':json.load(open(out/'prediction-proxy.json'))},open(out/'summary.json','w'),indent=2)
print('NETWORK_TESTS_PASS');print('\n'.join(checks))
