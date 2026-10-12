import json,re
from pathlib import Path
R=Path(__file__).resolve().parents[1];S=Path('/workspace/run-build-pew-source/UnityCore')
s=(S/'Assets/Scripts/Assembly-CSharp/PlayerInputActions.cs').read_text();raw=re.search(r'InputActionAsset.FromJson\((".*")\);',s)[1]
x=json.loads(json.loads(raw));(R/'data/input_bindings.json').write_text(json.dumps(x,indent=2))
refs={}
for guid,path in json.load(open(R/'data/source_guids.json')).items():
 if path.startswith('Assets/MonoBehaviour/') and path.endswith('.asset'):
  text=(S/path).read_text()
  if 'm_ActionId:' in text:
   name=re.search(r'  m_Name: (.*)',text)[1];refs[guid]=name.split('/')[-1]
(R/'data/input_references.json').write_text(json.dumps(refs,indent=2));print('Input action references',len(refs))
