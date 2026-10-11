from pathlib import Path
import zipfile,hashlib,json
R=Path(__file__).resolve().parents[1]
out=R.parent/'santana-delivery';out.mkdir(exist_ok=True)
target=out/'Santana-Visual-Art-Slice-Source.zip'
skip_names={'CHECKPOINT.txt','cabin_probe.txt','dash_probe.txt'}
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(R.rglob('*')):
  if not p.is_file() or '.godot' in p.parts or 'renderer-test' in p.parts or p.name in skip_names:continue
  if p.suffix in ['.log','.blend1']:continue
  z.write(p,Path('SantanaVisual')/p.relative_to(R))
with zipfile.ZipFile(target) as z:
 failed=z.testzip()
 if failed:raise RuntimeError(f'Archive CRC failed: {failed}')
 print(json.dumps({'path':str(target),'bytes':target.stat().st_size,'files':len(z.infolist()),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'crc':'passed'}))
