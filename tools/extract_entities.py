"""Preserve prefab unit/slot hierarchy and source transforms for runtime entities."""
import os,json,re,math
from pathlib import Path
import yaml
from source_render_metadata import extract_metadata
R=Path(__file__).resolve().parents[1];S=Path(os.environ.get('RBPEW_UNITYCORE','/workspace/run-build-pew-source/UnityCore'))
prefabs=json.loads((R/'data/prefabs.json').read_text());guids=json.loads((R/'data/source_guids.json').read_text())
unit_types={'AIUnitController','AISwarmingUnit','AIFollowingUnit','AIPatrolUnit','AIBossUnit','AIBossPartController','TraderUnit','AIStation','AIStationPartController','AIGuardUnitController','SpawnerStation','Asteroid','ContainerObject','MineController'}
def clean(v):
 if isinstance(v,dict):
  if 'guid' in v:return v['guid']
  return {k:clean(x) for k,x in v.items() if not k.startswith('m_')}
 if isinstance(v,list):return [clean(x) for x in v]
 return v
all_units={};all_transforms={}
for pid,prefab in prefabs.items():
 text=(S/prefab['source']).read_text();text=re.sub(r'^%.*\n','',text,flags=re.M);text=re.sub(r'^--- !u!\d+ &(-?\d+).*$',r'---\n__id: \1',text,flags=re.M)
 text=re.sub(r'^(\s*(?:- )?[A-Za-z_]\w*: )([0-9a-f]{8,})$',lambda m:m[1]+'"'+m[2]+'"' if len(m[2])%8==0 else m[0],text,flags=re.M)
 docs=list(yaml.load_all(text,Loader=yaml.CSafeLoader));trans={};go_trans={};gos={};components={};renderers={}
 for d in docs:
  if 'Transform' in d:
   trans[int(d['__id'])]=d['Transform'];go_trans[d['Transform']['m_GameObject']['fileID']]=int(d['__id'])
  elif 'GameObject' in d:gos[int(d['__id'])]=d['GameObject']
  elif 'MonoBehaviour' in d:
   v=d['MonoBehaviour'];cls=Path(guids.get(v.get('m_Script',{}).get('guid',''),'')).stem
   components.setdefault(v['m_GameObject']['fileID'],[]).append({'class':cls,'component_id':str(int(d['__id'])),**clean(v)})
  elif 'SpriteRenderer' in d:renderers.setdefault(d['SpriteRenderer']['m_GameObject']['fileID'],[]).append(d['SpriteRenderer'])
 def parent(go):return trans.get(trans.get(go_trans.get(go),{}).get('m_Father',{}).get('fileID',0),{}).get('m_GameObject',{}).get('fileID',0)
 def pose(go):
  t=trans.get(go_trans.get(go),{});v=t.get('m_LocalPosition',{});sc=t.get('m_LocalScale',{});q=t.get('m_LocalRotation',{});a=2*math.atan2(q.get('z',0),q.get('w',1));p=parent(go)
  pp=pose(p) if p else (0,0,1,1,0);x=v.get('x',0)*pp[2];y=v.get('y',0)*pp[3]
  return (pp[0]+x*math.cos(pp[4])-y*math.sin(pp[4]),pp[1]+x*math.sin(pp[4])+y*math.cos(pp[4]),sc.get('x',1)*pp[2],sc.get('y',1)*pp[3],a+pp[4])
 all_transforms[pid]={str(tid):{'x':pose(t['m_GameObject']['fileID'])[0],'y':-pose(t['m_GameObject']['fileID'])[1],'angle':-pose(t['m_GameObject']['fileID'])[4]} for tid,t in trans.items()}
 presentation=extract_metadata(docs,guids)
 unit_go={go for go,cs in components.items() if any(c['class'] in unit_types for c in cs)}
 def owner(go,include=True):
  p=go if include else parent(go)
  while p:
   if p in unit_go:return p
   p=parent(p)
  return 0
 units=[]
 for go in unit_go:
  cs=components[go];u=next(c for c in cs if c['class'] in unit_types);x,y,sx,sy,angle=pose(go)
  slots=[];arts=[]
  for child,cset in components.items():
   if owner(child)!=go:continue
   for c in cset:
    if c['class']=='AICoreController':
     px,py,psx,psy,pa=pose(child);slots.append({'x':px-x,'y':-(py-y),'angle':-pa,'sx':psx,'sy':psy,**c})
  for child,renders in renderers.items():
   if owner(child)!=go:continue
   px,py,psx,psy,pa=pose(child)
   for v in renders:
    if v.get('m_Sprite',{}).get('guid') and v.get('m_Enabled',1):arts.append({'sprite':v['m_Sprite']['guid'],'x':px-x,'y':-(py-y),'sx':psx,'sy':psy,'angle':-pa,'order':v.get('m_SortingOrder',0),'color':v.get('m_Color',{}),'presentation':presentation.get(child,{})})
  units.append({'id':str(go),'parent_unit':str(owner(go,False)),'name':gos.get(go,{}).get('m_Name',''),'x':x,'y':-y,'sx':sx,'sy':sy,'angle':-angle,'unit':u,'components':cs,'slots':slots,'render':sorted(arts,key=lambda v:v['order'])})
 all_units[pid]=units
(R/'data/entities.json').write_text(json.dumps(all_units,separators=(',',':')))
print('Source hierarchy:',sum(len(v) for v in all_units.values()),'units in',len(all_units),'prefabs')

(R/'data/prefab_transforms.json').write_text(json.dumps(all_transforms,separators=(',',':')))
