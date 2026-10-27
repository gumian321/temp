"""Dump the installed engine's public GDExtension interface in an isolated folder."""
import json
import subprocess

from run_checks import ROOT, isolated_environment


def main():
    folder = ROOT / 'artifacts' / 'native-api-4.6.3'
    folder.mkdir(parents=True, exist_ok=True)
    environment = isolated_environment(folder / 'profile')
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE
    command = ['D:/godot/Godot_v4.6.3-stable_win64.exe', '--headless', '--dump-gdextension-interface', '--dump-extension-api']
    process = subprocess.run(command, cwd=folder, env=environment, startupinfo=startup,
                             capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60)
    (folder / 'dump.log').write_text(process.stdout + process.stderr, encoding='utf-8')
    if process.returncode:
        raise RuntimeError((process.stdout + process.stderr)[-2000:])
    print(json.dumps({'files': [str(p) for p in folder.iterdir() if p.is_file()], 'scope': 'Documented engine API dump only, no game or user progress loaded'}))


if __name__ == '__main__':
    main()
