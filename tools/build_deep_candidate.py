"""Export a uniquely named performance candidate with verified source hashes."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import shutil

from run_checks import ROOT, isolated_environment


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    paths = [ROOT / name for name in ['project.godot', 'main.tscn', 'export_presets.cfg']]
    for name in ['scripts', 'shaders', 'data', 'native_runtime']:
        paths.extend(p for p in (ROOT / name).rglob('*') if p.is_file() and p.suffix not in ['.uid', '.import'])
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(paths)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--godot', default='D:/godot/Godot_v4.6.3-stable_win64.exe')
    args = parser.parse_args()
    if not re.fullmatch('[A-Za-z0-9-]+', args.tag):
        parser.error('Invalid tag')
    folder = ROOT / 'artifacts' / args.tag
    folder.mkdir(exist_ok=False)
    executable = folder / 'RunBuildPew.exe'
    before = sources()
    (folder / 'source-manifest.json').write_text(json.dumps(before, indent=2), encoding='utf-8')
    environment = isolated_environment(folder / 'export-profile')
    command = [args.godot, '--headless', '--path', str(ROOT), '--export-release', 'Windows Review', str(executable)]
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE
    process = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True,
                             text=True, encoding='utf-8', errors='replace', timeout=180, startupinfo=startup)
    output = process.stdout + process.stderr
    (folder / 'export.log').write_text(output, encoding='utf-8')
    checked = re.sub(r'ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:\d+\)\r?\n?', '', output)
    if process.returncode or 'ERROR:' in checked or not executable.is_file():
        raise RuntimeError(f'Export failed; see {folder / "export.log"}: {output[-3500:]}')
    if sources() != before:
        raise RuntimeError('Runtime sources changed during export; candidate must not be used')
    runtime_files = [{'path': executable.name, 'sha256': digest(executable), 'bytes': executable.stat().st_size}]
    # Ignored native resources load explicitly on supported Windows builds.
    # Ship their physical files beside the executable; never depend on cwd.
    native_folder = ROOT / 'native_runtime' / 'cave_sweep'
    if native_folder.is_dir():
        for source in sorted(native_folder.iterdir()):
            if source.suffix not in ['.dll', '.gdextension'] and source.name not in ['.gdignore','build-provenance.json']:
                continue
            target = folder / 'native_runtime' / 'cave_sweep' / source.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            runtime_files.append({'path': target.relative_to(folder).as_posix(), 'sha256': digest(target), 'bytes': target.stat().st_size})
    report = {'created_at_utc': datetime.now(timezone.utc).isoformat(), 'command': command,
              'executable': str(executable), 'sha256': digest(executable), 'bytes': executable.stat().st_size,
              'source_manifest': 'source-manifest.json', 'manifest_scope': 'Runtime scripts, shaders, data and project/export configuration; final executable hash covers the complete embedded package.'}
    report['runtime_files'] = runtime_files
    report['manifest_scope'] = 'Scripts, shaders, data, native runtime and project/export configuration; executable plus listed external native files comprise the release.'
    (folder / 'build.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
