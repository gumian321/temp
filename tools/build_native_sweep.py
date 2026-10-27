"""Build the isolated C GDExtension with project-local Zig; optionally smoke it."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from run_checks import isolated_environment

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / "native" / "cave_sweep"
API = ROOT / "artifacts" / "native-api-4.6.3"
DEFAULT_ZIG = ROOT / "artifacts" / "native-toolchain" / "zig-x86_64-windows-0.15.2" / "zig.exe"


def check_api(api_dir):
    data = json.loads((api_dir / "extension_api.json").read_text(encoding="utf-8"))
    sizes = next(x["sizes"] for x in data["builtin_class_sizes"] if x["build_configuration"] == "float_64")
    sizes = {item["name"]: item["size"] for item in sizes}
    for name, size in {"StringName": 8, "String": 8, "PackedFloat64Array": 16, "Variant": 24}.items():
        if sizes[name] != size:
            raise RuntimeError(f"Unexpected Godot ABI: {name}={sizes[name]}, expected {size}")
    packed = next(x for x in data["builtin_classes"] if x["name"] == "PackedFloat64Array")
    hashes = {method["name"]: method["hash"] for method in packed["methods"]}
    if hashes["size"] != 3173160232 or hashes["resize"] != 848867239:
        raise RuntimeError("PackedFloat64Array method hashes differ from wrapper.c")
    obj = next(x for x in data["classes"] if x["name"] == "Object")
    notification = next(x for x in obj["methods"] if x["name"] == "notification")
    if notification["hash"] != 4023243586:
        raise RuntimeError("Object.notification hash differs from wrapper.c")
    if not (api_dir / "gdextension_interface.h").is_file():
        raise RuntimeError("Dumped gdextension_interface.h is missing")


def write_descriptor(binary):
    # Forward slashes work in Godot config strings on Windows, including spaces.
    path = binary.resolve().as_posix().replace('"', '\\"')
    descriptor = NATIVE / "test_project" / "cave_sweep.gdextension"
    descriptor.write_text(
        '[configuration]\nentry_symbol = "cave_sweep_library_init"\ncompatibility_minimum = "4.6"\n'
        'reloadable = false\n\n[libraries]\n'
        f'windows.debug.x86_64 = "{path}"\nwindows.release.x86_64 = "{path}"\n',
        encoding="utf-8")
    return descriptor


def smoke(godot, output_dir, fixture):
    with tempfile.TemporaryDirectory(prefix="cave-sweep-smoke-", dir=output_dir) as tmp:
        profile = Path(tmp)
        env = isolated_environment(profile)
        if fixture is not None:
            env["CAVE_SWEEP_FIXTURE"] = str(fixture.resolve())
        command = [str(godot.resolve()), "--headless", "--path", str(NATIVE / "test_project"),
                   "--script", "res://smoke.gd", "--audio-driver", "Dummy"]
        result = subprocess.run(command, env=env, text=True, capture_output=True, timeout=45)
        log = result.stdout + result.stderr
        (output_dir / "smoke.log").write_text(log, encoding="utf-8")
        print(log, end="")
        checked_log = re.sub(
            r"ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\r?\n?",
            "", log) if os.name == "nt" else log
        if result.returncode or "CAVE_SWEEP_SMOKE=" not in log or "SCRIPT ERROR:" in checked_log or "ERROR:" in checked_log:
            raise RuntimeError(f"Native smoke failed ({result.returncode}); see {output_dir / 'smoke.log'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zig", type=Path, default=DEFAULT_ZIG)
    parser.add_argument("--api", type=Path, default=API)
    parser.add_argument("--godot", type=Path, help="Run the isolated load/call smoke with this executable")
    parser.add_argument("--fixture", type=Path, default=ROOT / "artifacts" / "native-sweep-fixture.bin",
                        help="Compare every original GDScript result byte-for-byte when this fixture exists")
    parser.add_argument("--check-only", action="store_true", help="Validate API and print command without compiling")
    args = parser.parse_args()
    check_api(args.api)
    output_dir = ROOT / "artifacts" / "native-sweep"
    output_dir.mkdir(parents=True, exist_ok=True)
    cache_dir = ROOT / "artifacts" / "native-toolchain" / "cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["ZIG_GLOBAL_CACHE_DIR"] = str(cache_dir / "global")
    env["ZIG_LOCAL_CACHE_DIR"] = str(cache_dir / "local")
    binary = output_dir / "cave_sweep.windows.x86_64.dll"
    command = [str(args.zig.resolve()), "cc", "-target", "x86_64-windows-gnu", "-std=c11", "-shared", "-O2",
               "-ffp-contract=off", "-fno-fast-math", "-fno-math-errno", "-Wall", "-Wextra",
               "-I", str(args.api.resolve()), str(NATIVE / "wrapper.c"), str(NATIVE / "kernel.c"),
               "-o", str(binary)]
    print(subprocess.list2cmdline(command))
    if args.check_only:
        return
    if not args.zig.is_file():
        parser.error(f"Project-local Zig compiler not found: {args.zig}")
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=240)
    (output_dir / "build.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    print(result.stdout + result.stderr, end="")
    result.check_returncode()
    descriptor = write_descriptor(binary)
    print(f"Built {binary}\nIsolated descriptor: {descriptor}")
    if args.godot:
        smoke(args.godot, output_dir, args.fixture if args.fixture.is_file() else None)


if __name__ == "__main__":
    main()
