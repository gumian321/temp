"""Rebuild the licensed, Chinese-capable bold UI font from official system Noto."""
from pathlib import Path
from fontTools.ttLib import TTCollection
from fontTools import subset
root = Path(__file__).resolve().parents[1]
font = TTCollection('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc').fonts[2]
chars = {chr(i) for i in range(0x20, 0x300)}
for a in range(0xa1, 0xff):
    for b in range(0xa1, 0xff):
        try:
            chars.add(bytes([a, b]).decode('gb2312'))
        except UnicodeDecodeError:
            pass
for base in ['scripts', 'data', 'tests']:
    for path in (root / base).rglob('*'):
        if path.is_file() and path.suffix in {'.gd', '.json', '.csv', '.tsv', '.txt'}:
            chars.update(path.read_text(errors='ignore'))
options = subset.Options()
options.layout_features = ['*']
worker = subset.Subsetter(options=options)
worker.populate(unicodes=[ord(c) for c in chars])
worker.subset(font)
font.save(root / 'assets/fonts/NotoSansCJKsc-Bold.otf')
