"""Retain each source Engine's own ParticleSystem and unit-relative attachment."""
import json,math
from pathlib import Path
from extract_particles import R,g,p,docs,extract_emitters,out
entities=json.load(open(R/'data/entities.json'));engines={}
engine_paths={c['path'] for c in json.load(open(R/'data/source_components.json')) if c['class']=='Engine'}
for prefab,definition in p.items():
 if definition['source'] not in engine_paths:continue
 ds=docs(definition['source']);components=[]
 for d in ds:
  if 'MonoBehaviour'in d:
   v=d['MonoBehaviour'];cls=Path(g.get(v.get('m_Script',{}).get('guid',''),'')).stem
   if cls in ['Engine','AIEnginesManager']:components.append((str(d['__id']),cls,v))
 if not any(c[1]=='Engine' for c in components):continue
 trans={d['__id']:d['Transform'] for d in ds if 'Transform'in d};gt={v['m_GameObject']['fileID']:k for k,v in trans.items()};ps={d['__id']:d['ParticleSystem'] for d in ds if 'ParticleSystem'in d}
 def parent(go):return trans.get(trans.get(gt.get(go),{}).get('m_Father',{}).get('fileID',0),{}).get('m_GameObject',{}).get('fileID',0)
 def ancestors(go):
  result=[]
  while go:result.append(go);go=parent(go)
  return result
 def pose(go):
  t=trans.get(gt.get(go),{});pos=t.get('m_LocalPosition',{});q=t.get('m_LocalRotation',{});pp=pose(parent(go)) if parent(go) else (0,0,0);a=2*math.atan2(q.get('z',0),q.get('w',1));x=pos.get('x',0);y=pos.get('y',0)
  return pp[0]+x*math.cos(pp[2])-y*math.sin(pp[2]),pp[1]+x*math.sin(pp[2])+y*math.cos(pp[2]),pp[2]+a
 owners={int(u['id']) for u in entities.get(prefab,[])};records=[]
 for cid,cls,c in components:
  if cls!='Engine':continue
  pid=c.get('engineParticle',{}).get('fileID',0)
  if pid not in ps:continue
  go=ps[pid]['m_GameObject']['fileID'];chain=ancestors(go);owner=next((v for v in chain if v in owners),0);a=pose(go);b=pose(owner) if owner else (0,0,0)
  selected={k for k,v in ps.items() if go in ancestors(v['m_GameObject']['fileID'])};key='engine:'+prefab+':'+cid;out[key]=extract_emitters(ds,selected)
  direction=''
  for _,name,manager in components:
   if name=='AIEnginesManager':
    for side in ['left','right','up','down']:
     if any(str(r['fileID'])==cid for r in manager.get(side+'Engines',[])):direction=side
  records.append({'key':key,'owner':str(owner),'x':a[0]-b[0],'y':-(a[1]-b[1]),'angle':-(a[2]-b[2]),'direction':direction,'automatic':bool(ps[pid].get('playOnAwake',True))})
 if records:engines[prefab]=records
(R/'data/engines.json').write_text(json.dumps(engines,separators=(',',':')));(R/'data/particles.json').write_text(json.dumps(out,separators=(',',':')));print('Engine attachments',sum(map(len,engines.values())))
