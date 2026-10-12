"""Export original line/trail renderer parameters, material textures and animation frames."""
import json,re,yaml,shutil
from pathlib import Path
R=Path(__file__).resolve().parents[1];S=Path('/workspace/run-build-pew-source/UnityCore');g=json.load(open(R/'data/source_guids.json'));prefabs=json.load(open(R/'data/prefabs.json'));out={}
def docs(path):
 t=(S/path).read_text();t=re.sub(r'^%.*\n','',t,flags=re.M);t=re.sub(r'^--- !u!\d+ &.*$',r'---',t,flags=re.M);return list(yaml.load_all(t,Loader=yaml.CSafeLoader))
def texture(guid):
 if guid not in g:return ''
 source=S/g[guid];target=R/'assets/particles'/(guid+source.suffix);shutil.copyfile(source,target);return 'res://assets/particles/'+target.name
for pid,p in prefabs.items():
 ds=docs(p['source']);records=[]
 for d in ds:
  for kind in ['LineRenderer','TrailRenderer']:
   if kind not in d:continue
   v=d[kind];params=v.get('m_Parameters',{});item={'kind':kind,'parameters':params,'duration':v.get('m_Time',.5),'texture':'','frames':[],'frame_duration':.5}
   for ref in v.get('m_Materials',[]):
    if ref.get('guid')not in g:continue
    mat=docs(g[ref['guid']])[0]['Material']['m_SavedProperties'];item['texture']=texture(mat.get('m_TexEnvs',{}).get('_MainTex',{}).get('m_Texture',{}).get('guid'));item['material']=mat;break
   for c in ds:
    c=c.get('MonoBehaviour',{})
    if 'changeRate'in c and 'spritesList'in c:item['frames']=[texture(s.get('guid')) for s in c['spritesList']];item['frame_duration']=c['changeRate']
   records.append(item)
 if records:out[pid]=records
(R/'data/native_visuals.json').write_text(json.dumps(out,separators=(',',':')));print('Original line/trail prefab definitions',len(out))
