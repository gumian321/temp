"""Lossless Unity YAML inventory, GUID linking and source evidence extraction."""
import re,json,csv,hashlib,collections
from pathlib import Path
import os
import yaml
ROOT=Path(os.environ.get('RBPEW_UNITYCORE', '/workspace/run-build-pew-source/UnityCore'))
OUT=Path(__file__).resolve().parents[1]
class Loader(yaml.CSafeLoader): pass
Loader.add_constructor('tag:yaml.org,2002:value',lambda l,n:l.construct_scalar(n))
Loader.add_multi_constructor('tag:unity3d.com,2011:',lambda loader,suffix,node:loader.construct_mapping(node,deep=True))
def docs(p):
 text=p.read_text(errors='replace')
 text=re.sub(r'^--- !u!\d+ &(-?\d+).*$',r'---\n__fileID: \1',text,flags=re.M)
 text=re.sub(r'^%.*\n','',text,flags=re.M)
 text=re.sub(r'^(\s*(?:- )?[A-Za-z_]\w*: )([0-9a-f]{8,})$',lambda m:m[1]+'\"'+m[2]+'\"' if len(m[2])%8==0 else m[0],text,flags=re.M)
 return list(yaml.load_all(text,Loader=Loader))
guid={}
for p in ROOT.rglob('*.meta'):
 m=re.search(r'^guid: (\w+)',p.read_text(errors='replace'),re.M)
 if m:guid[m[1]]=str(p.relative_to(ROOT))[:-5]
records={};errors=[]
for p in (ROOT/'Assets').rglob('*'):
 if p.suffix not in ['.asset','.prefab','.unity']:continue
 try:
  ds=docs(p); rel=str(p.relative_to(ROOT));records[rel]=ds
 except Exception as e: errors.append({'file':str(p.relative_to(ROOT)),'error':str(e)})
assets={}; components=[]
for path,ds in records.items():
 for d in ds:
  if not isinstance(d,dict):continue
  b=d.get('MonoBehaviour')
  if b:
   script=Path(guid.get(b.get('m_Script',{}).get('guid',''),'')).stem
   item={'path':path,'file_id':d.get('__fileID'), 'class':script,'values':b}
   components.append(item)
   if path.endswith('.asset'):assets[path]=item
localization={r['ID']:r for r in csv.DictReader((ROOT/'Assets/Resources/Localization SpreadSheet.txt').open()) if r.get('ID')}
for name,data in [('source_assets',assets),('source_components',components),('source_guids',guid),('localization',localization)]:
 (OUT/'data'/f'{name}.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
counts=collections.Counter(x['class'] for x in assets.values())
scripts=[]
for p in sorted((ROOT/'Assets/Scripts').rglob('*.cs')):
 t=p.read_text(errors='replace');scripts.append({'path':str(p.relative_to(ROOT)),'lines':len(t.splitlines()),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'methods':re.findall(r'(?:public|private|protected)\s+(?:static\s+)?[\w<>\[\]]+\s+(\w+)\s*\(',t)})
manifest={'source_commit':'5045ffca4134d1a29052477a9d328477c4c07993','scripts':scripts,'asset_classes':dict(counts),'components':len(components),'documents':len(records),'errors':errors}
(OUT/'data/source_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in manifest.items() if k!='scripts'},ensure_ascii=False,indent=2))
