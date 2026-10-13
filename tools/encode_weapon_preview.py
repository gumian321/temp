"""Encode the real, staged weapon capture; no synthetic replacement frames."""
import json
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
report = json.loads((root / "artifacts/weapon-showcase-report.json").read_text(encoding="utf-8"))
render_report = json.loads((root / "artifacts/weapons-showcase-render.json").read_text(encoding="utf-8"))
if not report["passed"] or not render_report["passed"] or not 1 <= report["clip_frames"] <= 160:
    raise SystemExit("A clean, passing rendered weapon_showcase report is required")
frames = []
for index in range(report["clip_frames"]):
    with Image.open(root / f"artifacts/weapon-frames/frame-{index:04d}.png") as capture:
        frames.append(capture.convert("RGB"))
target = root / "artifacts/weapon-feedback-preview.webp"
frames[0].save(target, format="WEBP", save_all=True, append_images=frames[1:],
               duration=50, loop=0, quality=85, method=3)
with Image.open(target) as preview:
    assert preview.n_frames == len(frames)
    print(json.dumps({"path": str(target), "frames": preview.n_frames,
                      "size": preview.size, "seconds": len(frames) / 20,
                      "bytes": target.stat().st_size}))
