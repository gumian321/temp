"""Encode rendered Godot frames, preserving the actual soft-body animation."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
report = json.loads((root / "artifacts/brood-scene-report.json").read_text(encoding="utf8"))
if not report["passed"]:
    raise SystemExit("A passing brood_scene render is required")
frames = []
for frame in range(0, 300, 2):
    with Image.open(root / f"artifacts/brood-frames/frame-{frame:03d}.jpg") as image:
        frames.append(image.convert("RGB"))
destination = root / "artifacts/brood-impact-v2.webp"
frames[0].save(destination, format="WEBP", save_all=True, append_images=frames[1:],
               duration=[33, 34, 33] * 50, loop=0, quality=85, method=3)
with Image.open(destination) as result:
    assert result.n_frames == 150
print(json.dumps({"path": str(destination), "frames": 150, "seconds": 5,
                  "bytes": destination.stat().st_size}))
