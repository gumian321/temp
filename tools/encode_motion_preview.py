"""Encode the actual Godot motion-scene capture as a bounded animated preview."""
import json
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
report = json.loads((root / "artifacts/motion-scene-report.json").read_text(encoding="utf-8"))
if not report["passed"] or not 1 <= report["clip_frames"] <= 300:
    raise SystemExit("A passing rendered motion_scene report is required")
frames = []
for index in range(report["clip_frames"]):
    with Image.open(root / f"artifacts/motion-frames/frame-{index:04d}.png") as capture:
        frames.append(capture.convert("RGB"))
target = root / "artifacts/centipede-fluid-motion.webp"
frames[0].save(target, format="WEBP", save_all=True, append_images=frames[1:],
               duration=round(1000 / report["clip_fps"]), loop=0, quality=80, method=2)
with Image.open(target) as preview:
    assert preview.n_frames == len(frames)
    print(json.dumps({"path": str(target), "frames": preview.n_frames,
                      "size": preview.size, "seconds": len(frames) / report["clip_fps"],
                      "bytes": target.stat().st_size}))
