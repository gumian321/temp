"""Build recoverable local artifacts without network publication or Library upload."""
import json,os,subprocess,zipfile,hashlib,shutil,html,base64
from pathlib import Path
R=Path(__file__).resolve().parents[1];D=Path('/workspace/centipede-deliverables');D.mkdir(exist_ok=True)
env=os.environ|{'XDG_DATA_HOME':'/workspace/scratch/xdg-data','XDG_CONFIG_HOME':'/workspace/scratch/xdg-config','XDG_CACHE_HOME':'/workspace/scratch/cache'}
with open(R/'artifacts/export.log','w') as f:subprocess.run(['godot','--headless','--path',str(R),'--export-pack','Linux',str(R/'artifacts/game.pck')],env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()
runtime=D/'linux-runtime';runtime.mkdir(exist_ok=True)
shutil.copy2(shutil.which('godot'),runtime/'godot');shutil.copy2(R/'distribution/Run.sh',runtime/'Run.sh');shutil.copy2(R/'distribution/GODOT_LICENSE.txt',runtime/'GODOT_LICENSE.txt')
shutil.copyfile(R/'artifacts/game.pck',runtime/'game.pck')
(runtime/'README.txt').write_text('Run Build Pew! — Centipede Godot migration checkpoint\nRevision: '+revision+'\nLinux x86_64: run ./Run.sh\nWASD, mouse fire, Shift boost (requires fuel tank), E build, right mouse/Tab radar, Escape pause.\nIncludes original source assets. Source owner permissions apply.\nFull parity acceptance remains pending: see project docs/FEATURE_PARITY.md.\n')
files=subprocess.check_output(['git','ls-files','-z'],cwd=R).decode().split('\0')
with zipfile.ZipFile(D/'centipede-godot-project-checkpoint.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for name in files:
  if name and (R/name).is_file():z.write(R/name,'centipede-godot/'+name)
 for p in (R/'artifacts').rglob('*'):
  if p.is_file() and (p.suffix in ['.json','.png']):z.write(p,'centipede-godot/'+str(p.relative_to(R)))
with zipfile.ZipFile(D/'centipede-linux-runnable-checkpoint.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in runtime.iterdir():
  if p.is_file():z.write(p,'centipede-linux/'+p.name)
subprocess.run(['git','bundle','create',str(D/'centipede-local-history.bundle'),'--all'],cwd=R,check=True)
reports=[]
for p in sorted((R/'artifacts').glob('*report.json')):reports.append('<h2>'+html.escape(p.name)+'</h2><pre>'+html.escape(p.read_text())+'</pre>')
shots=[]
for p in sorted((R/'artifacts/screenshots').glob('*.png')):shots.append('<h2>'+html.escape(p.name)+'</h2><img style="max-width:100%" src="data:image/png;base64,'+base64.b64encode(p.read_bytes()).decode()+'">')
(D/'centipede-checkpoint-report.html').write_text('<!doctype html><meta charset="utf-8"><title>Centipede migration checkpoint</title><h1>Migration checkpoint — not full parity acceptance</h1><p>Revision '+revision+'</p><pre>'+html.escape((R/'docs/FEATURE_PARITY.md').read_text())+'</pre>'+''.join(reports+shots))
manifest={'revision':revision,'status':'CHECKPOINT_NOT_FULL_PARITY','files':[]}
for p in D.iterdir():
 if p.is_file() and p.name not in ['checksums.json','delivery-verification.json']:manifest['files'].append({'name':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(D/'checksums.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest))
