"""Set native Godot import options without editing the generated PNG pixels."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "assets/blue_ink/brood/armament-v2-generation.json").read_text(encoding="utf-8"))
for asset in manifest["assets"]:
    source = root / asset["path"]
    if not source.is_file():
        raise SystemExit(f"Missing generated image: {source}")
    settings = source.with_suffix(".png.import")
    if settings.is_file():
        text = settings.read_text(encoding="utf-8")
        import re
        text = re.sub(r"^mipmaps/generate=.*$", "mipmaps/generate=true", text, flags=re.M)
        text = re.sub(r"^process/size_limit=.*$", "process/size_limit=512", text, flags=re.M)
    else:
        uri = "res://" + asset["path"]
        digest = hashlib.md5(uri.encode("utf-8")).hexdigest()
        imported = f"res://.godot/imported/{source.name}-{digest}.ctex"
        text = f'''[remap]
importer="texture"
type="CompressedTexture2D"
path="{imported}"

[deps]
source_file="{uri}"
dest_files=["{imported}"]

[params]
compress/mode=0
mipmaps/generate=true
process/fix_alpha_border=true
process/premult_alpha=false
process/size_limit=512
'''
    settings.write_text(text, encoding="utf-8")
print(f"Configured {len(manifest['assets'])} images: 512px runtime limit, mipmaps, original alpha.")
