"""Verify source-checkout spider art with and without Godot's ignored import cache.

The Windows source launcher must import synchronously. The no-import probe also
exercises SpiderArt's raw-PNG fallback, using the real renderer script, not a mock.
Never removes or changes the working checkout's cache or player's save.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    godot = shutil.which(os.environ.get("GODOT_BIN", "godot"))
    assert godot, "Godot executable is required"
    launcher = (ROOT / "启动蜈蚣中文版.cmd").read_text(encoding="utf-8")
    assert launcher.index("--import") < launcher.index('start ""'), "Import must precede launch"
    assert "if errorlevel 1 (" in launcher, "Failed imports must block launching"
    records = []
    with tempfile.TemporaryDirectory(prefix="spider-source-import-") as scratch:
        base = Path(scratch)
        (base / "assets/characters").mkdir(parents=True)
        (base / "scripts").mkdir()
        (base / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Spider Import Regression"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        shutil.copy2(ROOT / "scripts/spider_art.gd", base / "scripts/spider_art.gd")
        # Copy every atlas source/remap, never the .godot imported files.
        for source in (ROOT / "assets/characters").glob("spider*"):
            if source.is_file():
                shutil.copy2(source, base / "assets/characters" / source.name)
        (base / "probe.gd").write_text('''extends SceneTree
func _initialize():
 var art=load("res://scripts/spider_art.gd")
 art.prepare()
 var valid = not art.pieces.is_empty()
 for key in art.pieces:
  var texture = art.pieces[key]
  valid = valid and texture != null and texture.get_width() > 0
  if texture is AtlasTexture: valid = valid and texture.atlas != null
  if texture != null and (not texture is AtlasTexture or texture.atlas != null):
   var image = texture.get_image()
   var visible = 0
   if image != null:
    for y in range(0, image.get_height(), 4):
     for x in range(0, image.get_width(), 4):
      if image.get_pixel(x, y).a > 0.5: visible += 1
   valid = valid and visible > 10
   print("VISIBLE_ALPHA_SAMPLES ", key, "=", visible)
 print("SPIDER_ATLAS_VALID=", valid)
 quit(0 if valid else 1)
''')
        env = os.environ.copy()
        for key, folder in [("HOME", "home"), ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"), ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")]:
            (base / folder).mkdir()
            env[key] = str(base / folder)
        command = [godot, "--headless", "--path", str(base)]
        for label, args in [("fresh_source_fallback", ["--script", "res://probe.gd"]), ("source_import", ["--import"]), ("imported_source", ["--script", "res://probe.gd"])]:
            result = subprocess.run(command + args, env=env, capture_output=True, text=True, timeout=90)
            output = result.stdout + result.stderr
            records.append({"case": label, "passed": result.returncode == 0 and "ERROR:" not in output, "exit_code": result.returncode, "output": output})
    report = {"checks": records, "passed": all(item["passed"] for item in records)}
    (ROOT / "artifacts/spider-source-import-report.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
