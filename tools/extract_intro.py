"""Preserve the serialized intro order, transforms, text and timing."""
import json,re,yaml
from pathlib import Path
R=Path(__file__).resolve().parents[1];S=Path('/workspace/run-build-pew-source/UnityCore')
t=(S/'Assets/Scenes/IntroScene.unity').read_text();t=re.sub(r'^%.*\n','',t,flags=re.M);t=re.sub(r'^--- !u!\d+ &(-?\d+).*$',r'---\n__id: \1',t,flags=re.M)
ds={d['__id']:d for d in yaml.load_all(t,Loader=yaml.CSafeLoader)}
trs={d['__id']:d.get('Transform',d.get('RectTransform')) for d in ds.values() if 'Transform'in d or 'RectTransform'in d};bygo={v['m_GameObject']['fileID']:k for k,v in trs.items()}
def pose(tid):
 t=trs.get(tid)
 if not t:return [0,0,1,1]
 p=pose(t['m_Father']['fileID']);v=t['m_LocalPosition'];s=t['m_LocalScale'];return [p[0]+v['x']*p[2],p[1]+v['y']*p[3],p[2]*s['x'],p[3]*s['y']]
components=json.load(open(R/'data/source_components.json'));cfg=next(x['values'] for x in components if x['class']=='IntroSceneManager');pages=[]
for entry in cfg['IntroObjectsList']:
 page={}
 for field,kind in [('objImage','SpriteRenderer'),('objText','MonoBehaviour')]:
  ident=entry[field]['fileID']
  if not ident:continue
  c=ds[ident][kind];go=c['m_GameObject']['fileID'];v={'pose':pose(bygo[go])}
  if kind=='SpriteRenderer':v['sprite']=c['m_Sprite']['guid']
  else:v['text']=c['m_text'];v['font_size']=c['m_fontSize']
  page[field]=v
 pages.append(page)
(R/'data/intro.json').write_text(json.dumps({'half_duration':[.25,.5,1,1.5,3,6][cfg['animationDuration']],'pages':pages},indent=2))
