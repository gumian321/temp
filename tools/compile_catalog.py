import json,re,shutil,struct
from pathlib import Path
import os
from PIL import Image
R=Path(__file__).resolve().parents[1]; S=Path(os.environ.get('RBPEW_UNITYCORE', '/workspace/run-build-pew-source/UnityCore'))
a=json.loads((R/'data/source_assets.json').read_text());comps=json.loads((R/'data/source_components.json').read_text());guids=json.loads((R/'data/source_guids.json').read_text())
reverse={v:k for k,v in guids.items()}
def clean(v):
 if isinstance(v,dict):
  if 'guid' in v:return v['guid']
  return {k:clean(x) for k,x in v.items() if not k.startswith('m_')}
 if isinstance(v,list):return [clean(x) for x in v]
 return v
catalog={}
for path,x in a.items():
 if x['class'].startswith(('Unity.','Device','DOTween')):continue
 guid=reverse[path];v=clean(x['values']);v.update({'id':guid,'name':x['values'].get('m_Name',Path(path).stem),'class':x['class'],'source':path});catalog[guid]=v
stores={}
for x in comps:
 if x['class'].endswith('DataStore') and x['class'] not in stores:stores[x['class']]=clean(x['values'])
nodes=[{'id':str(x['file_id']),**clean(x['values'])} for x in comps if x['class']=='UpgradeTreeNode' and 'MainMenuScene' in x['path']]
prefabs={gid:{'name':Path(path).stem,'source':path,'components':[]} for gid,path in guids.items() if path.endswith('.prefab')}
for x in comps:
 if x['path'].endswith('.prefab'):
  key=reverse[x['path']]; prefabs.setdefault(key,{'name':Path(x['path']).stem,'source':x['path'],'components':[]})['components'].append({'class':x['class'],**clean(x['values'])})
scene_config={x['class']:clean(x['values']) for x in comps if 'GameScene' in x['path'] and x['class'] in ['MapNodesManager']}
(R/'data/scene_config.json').write_text(json.dumps(scene_config,separators=(',',':')))
# source enum values bind pool types to prefabs by exact enum/prefab names.
t=(S/'Assets/Scripts/Assembly-CSharp/PrefabTypes.cs').read_text()
enums={int(v):k for k,v in re.findall(r'(\w+)\s*=\s*(\d+)',t)}
pool={str(i):next((k for k,v in prefabs.items() if v['name']==name),'') for i,name in enums.items()}
# All sprite crops retain original artwork, rect coordinates and GUID identity.
sprites={};(R/'assets/sprites').mkdir(parents=True,exist_ok=True)
for p in (S/'Assets/Sprite').glob('*.asset'):
 t=p.read_text(); rect=re.search(r'm_Rect:\s+serializedVersion: \d+\s+x: ([\d.]+)\s+y: ([\d.]+)\s+width: ([\d.]+)\s+height: ([\d.]+)',t); tex=re.search(r'texture: \{fileID: \d+, guid: (\w+)',t)
 if not rect or not tex:continue
 src=S/guids.get(tex[1],'MISSING')
 if not src.is_file():continue
 gid=reverse[str(p.relative_to(S))];x,y,w,h=map(lambda s:int(float(s)),rect.groups())
 with Image.open(src) as im:
  if w==0 or h==0:continue
  if not (R/'assets/sprites'/f'{gid}.png').exists():im.crop((x,im.height-y-h,x+w,im.height-y)).save(R/'assets/sprites'/f'{gid}.png')
 sprites[gid]={'name':p.stem,'path':f'res://assets/sprites/{gid}.png','source':str(p.relative_to(S))}
for name,obj in [('catalog',catalog),('stores',stores),('research',nodes),('prefabs',prefabs),('pool',pool),('sprites',sprites)]:
 (R/'data'/f'{name}.json').write_text(json.dumps(obj,ensure_ascii=False,separators=(',',':')))
(R/'assets/audio').mkdir(exist_ok=True)
for p in (S/'Assets/AudioClip').glob('*.ogg'):shutil.copy2(p,R/'assets/audio'/p.name)
print('catalog',len(catalog),'research',len(nodes),'prefabs',len(prefabs),'sprites',len(sprites),'pool resolved',sum(bool(v) for v in pool.values()),'/',len(pool))
