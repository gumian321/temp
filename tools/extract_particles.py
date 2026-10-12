"""Preserve source particle modules and referenced material textures for the Godot renderer."""
import json,re,yaml,shutil,math
from pathlib import Path
R=Path(__file__).resolve().parents[1];S=Path('/workspace/run-build-pew-source/UnityCore')
g=json.loads((R/'data/source_guids.json').read_text());p=json.loads((R/'data/prefabs.json').read_text());pool=json.loads((R/'data/pool.json').read_text())
def docs(path):
 t=(S/path).read_text();t=re.sub(r'^%.*\n','',t,flags=re.M);t=re.sub(r'^--- !u!\d+ &(-?\d+).*$',r'---\n__id: \1',t,flags=re.M)
 return list(yaml.load_all(t,Loader=yaml.CSafeLoader))
(R/'assets/particles').mkdir(exist_ok=True);out={}
sources={str(k):pool[str(k)] for k in range(300,310)}
sources['505']=pool['505']
sources['flame']='8cbbd90b03f3bc94babacfe8e9d12f81'
def extract_emitters(ds,selected=None):
 renderers={d['ParticleSystemRenderer']['m_GameObject']['fileID']:d['ParticleSystemRenderer'] for d in ds if 'ParticleSystemRenderer'in d};emitters=[]
 transforms={d['Transform']['m_GameObject']['fileID']:d['Transform'] for d in ds if 'Transform'in d}
 for d in ds:
  if 'ParticleSystem'not in d:continue
  if selected is not None and int(d['__id']) not in selected:continue
  v=d['ParticleSystem'];r=renderers.get(v['m_GameObject']['fileID'],{});mat={};shader='';shader_ref={}
  for ref in r.get('m_Materials',[]):
   if ref.get('guid')in g:material=docs(g[ref['guid']])[0].get('Material',{});mat=material.get('m_SavedProperties',{});shader_ref=material.get('m_Shader',{});shader=g.get(shader_ref.get('guid',''),'');break
  env=mat.get('m_TexEnvs',{});tex=env.get('_MainTex',{}).get('m_Texture',{}).get('guid');texture=''
  if tex in g:
   path=Path(g[tex]);name=tex+path.suffix;shutil.copyfile(S/path,R/'assets/particles'/name);texture='res://assets/particles/'+name
  transform=transforms.get(v['m_GameObject']['fileID'],{});q=transform.get('m_LocalRotation',{})
  emitters.append({'local_space':bool(v.get('moveWithTransform',1)),'shader_ref':shader_ref,'offset':transform.get('m_LocalPosition',{}),'angle':-2*math.atan2(q.get('z',0),q.get('w',1)),'texture':texture,'material':mat,'shader':shader,'renderer':r,'clamp':v.get('ClampVelocityModule',{}),'sub':v.get('SubModule',{}),'duration':v['lengthInSec'],'loop':v['looping'],'delay':v['startDelay'],'initial':v['InitialModule'],'shape':v['ShapeModule'],'emission':v['EmissionModule'],'size':v['SizeModule'],'rotation':v['RotationModule'],'color':v['ColorModule'],'uv':v['UVModule'],'velocity':v['VelocityModule'],'force':v['ForceModule']})
 return emitters

for key,prefab in sources.items():out[key]=extract_emitters(docs(p[prefab]['source']))
(R/'data/particles.json').write_text(json.dumps(out,separators=(',',':')))
print('Source effects',len(out),'emitters',sum(map(len,out.values())))
