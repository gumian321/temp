import json,re,math
from pathlib import Path
import os
import yaml
from source_render_metadata import extract_metadata
R=Path(__file__).resolve().parents[1];S=Path(os.environ.get('RBPEW_UNITYCORE', '/workspace/run-build-pew-source/UnityCore'))
p=json.loads((R/'data/prefabs.json').read_text());g=json.loads((R/'data/source_guids.json').read_text());sprites=json.loads((R/'data/sprites.json').read_text())
for id,item in sprites.items():
 text=(S/item['source']).read_text();m=re.search(r'm_PixelsToUnits: ([\d.]+)',text);item['ppu']=float(m[1]) if m else 100
for id,item in p.items():
 text=(S/item['source']).read_text();text=re.sub(r'^--- !u!\d+ &(-?\d+).*$',r'---\n__id: \1',text,flags=re.M);text=re.sub(r'^%.*\n','',text,flags=re.M)
 ds=list(yaml.load_all(text,Loader=yaml.CSafeLoader));trans={};by_go={};render=[]
 for d in ds:
  if 'Transform' in d:trans[d['__id']]=d['Transform'];by_go[d['Transform']['m_GameObject']['fileID']]=d['__id']
 def pos(tid):
  t=trans.get(tid,{})
  if not t:return (0,0,1,1,0)
  v=t.get('m_LocalPosition',{});s=t.get('m_LocalScale',{});q=t.get('m_LocalRotation',{});rot=2*math.atan2(q.get('z',0),q.get('w',1))
  parent=pos(t.get('m_Father',{}).get('fileID',0))
  x=v.get('x',0)*parent[2];y=v.get('y',0)*parent[3]
  return (parent[0]+x*math.cos(parent[4])-y*math.sin(parent[4]),parent[1]+x*math.sin(parent[4])+y*math.cos(parent[4]),s.get('x',1)*parent[2],s.get('y',1)*parent[3],rot+parent[4])
 presentation=extract_metadata(ds,g)
 for d in ds:
  if 'SpriteRenderer' not in d:continue
  v=d['SpriteRenderer'];gid=v.get('m_Sprite',{}).get('guid','')
  if gid not in sprites:continue
  x,y,sx,sy,angle=pos(by_go.get(v['m_GameObject']['fileID'],0))
  render.append({'sprite':gid,'x':x,'y':-y,'sx':sx,'sy':sy,'angle':-angle,'order':v.get('m_SortingOrder',0),'color':v.get('m_Color',{}),'presentation':presentation.get(v['m_GameObject']['fileID'],{})})
 render.sort(key=lambda v:v['order']);item['render']=render
(R/'data/prefabs.json').write_text(json.dumps(p,separators=(',',':')))
(R/'data/sprites.json').write_text(json.dumps(sprites,separators=(',',':')))
print('Extracted prefab SpriteRenderer transforms:',sum(len(v['render']) for v in p.values()))
