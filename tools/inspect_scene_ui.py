import json,re,yaml
from pathlib import Path
R=Path('/workspace/centipede-godot');S=Path('/workspace/run-build-pew-source/UnityCore')
g=json.load(open(R/'data/source_guids.json'));scene=next(S.glob('Assets/Scenes/*MainMenuScene*unity'))
t=scene.read_text();t=re.sub(r'^%.*\n','',t,flags=re.M);t=re.sub(r'^--- !u!\d+ &(-?\d+).*$',r'---\n__id: \1',t,flags=re.M)
docs=list(yaml.load_all(t,Loader=yaml.CSafeLoader));gos={};ts={};ct={};cs={}
for d in docs:
 if 'GameObject'in d:gos[d['__id']]=d['GameObject']
 for kind in ['Transform','RectTransform']:
  if kind in d:ts[d['__id']]=d[kind];ct[d[kind]['m_GameObject']['fileID']]=d['__id']
 if 'MonoBehaviour'in d:
  v=d['MonoBehaviour'];cs.setdefault(v['m_GameObject']['fileID'],[]).append((Path(g.get(v['m_Script'].get('guid',''),'')).stem,v))
def path(go):
 t=ts.get(ct.get(go),{});p=t.get('m_Father',{}).get('fileID');parent=ts.get(p,{}).get('m_GameObject',{}).get('fileID')
 return (path(parent)+'/' if parent else '')+str(gos.get(go,{}).get('m_Name'))
for go,c in cs.items():
 if any(k in ['MainMenuManager','OptionMenuManager','PlayUIManager','UpgradeTreeManager','GameLeaderboardUIManager'] for k,v in c):
  print(go,path(go),ts.get(ct.get(go)),[k for k,v in c])
for go in [2239]:
 prefix=path(go)
 for id,c in cs.items():
  if path(id).startswith(prefix):
   for k,v in c:
    if 'm_Text' in v or 'm_text'in v or k=='LocalizationTextActivator':print(path(id),{a:b for a,b in v.items() if a in ['m_Text','m_text','m_fontSize','m_fontAsset','m_Sprite','textID','ID'] or 'Text' in a})
