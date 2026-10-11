"""Six new prank outcomes over real ENet processes; no renderer/gameplay impersonation."""
import subprocess,pathlib,time,json,sys
root=pathlib.Path(__file__).resolve().parents[1];out=root/'tests/results/v02';out.mkdir(parents=True,exist_ok=True)
procs=[];logs=[]
def run(args,name):
 f=open(out/(name+'.log'),'w');logs.append(f);p=subprocess.Popen(args,cwd=root,stdout=f,stderr=subprocess.STDOUT);procs.append(p);return p
for name,port,reverse in [('comedy-lan',28010,False),('comedy-impaired',28020,True)]:
 base=['godot','--headless','--path',str(root),'--script','tests/comedy_peer.gd','--']+(['--reverse'] if reverse else [])
 run(base+['--host',f'--port={port}',f'--out={out}/{name}-host.json'],name+'-host');time.sleep(.4)
 target=port
 if reverse:
  target+=1;run([sys.executable,'tests/udp_proxy.py',f'--listen={target}',f'--server={port}','--seconds=63',f'--out={out}/proxy.json'],'proxy');time.sleep(.2)
 run(base+[f'--port={target}',f'--out={out}/{name}-client.json'],name+'-client')
try:
 for p in procs:p.wait(timeout=80);assert p.returncode==0
finally:
 for p in procs:
  if p.poll() is None:p.kill()
 for f in logs:f.close()
for name in ['comedy-lan','comedy-impaired']:
 h=json.load(open(out/(name+'-host.json')));c=json.load(open(out/(name+'-client.json')))
 assert len(h['reports'])==len(c['reports'])==6,(name,h,c)
 assert h['reports']==c['reports'],(name,'state mismatch')
 assert h['stages']==c['stages'],(name,'reliable stage mismatch',h['stages'],c['stages'])
 assert len(h['stages'])==18,(name,h['stages'])
 for index,r in enumerate(h['reports']):
  assert r['winner']=='coach' and all(v==0 for v in r['effects']+r['backlash'])
  if index%2==0:assert r['counters']==r['backfires']==r['driver_repairs']==1 and r['hits']==0
  else:assert r['hits']==r['repairs']==1 and r['counters']==0
 for peer in [h,c]:
  assert all(peer[k] for k in ['motion','disconnected','reconnected','returned_clean'])
  assert peer['queue_peak']<=256
 assert 'ERROR:' not in (out/(name+'-host.log')).read_text()+(out/(name+'-client.log')).read_text()
assert json.load(open(out/'comedy-lan-host.json'))['duplicates']>=3
print('COMEDY_NETWORK_PASS: six outcomes, 18 identical reliable stages per pair, backfire/cleanup, active driving, dedup, restart, both disconnects, reconnect; ordinary + 100±40ms/5% UDP loss')
