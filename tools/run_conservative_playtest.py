"""Launch a real-time normal-rules release run with a conservative input pilot."""
import argparse
import datetime
import json
import hashlib
import os
from pathlib import Path
import shutil
import subprocess

from run_checks import isolated_environment

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=float, default=1980)
    parser.add_argument('--tag', default='conservative-playtest-20261026')
    parser.add_argument('--executable',type=Path,default=ROOT/'artifacts/longrun-wall-fragments/RunBuildPew.exe')
    parser.add_argument('--continuous',action='store_true',help='Record drops without the external pilot pausing the battle for inspection')
    parser.add_argument('--seed',type=int,help='Optional external controller seed; never changes the game simulation RNG')
    parser.add_argument('--muted',action='store_true',help='Mute only this game process through the Windows audio-session API')
    args = parser.parse_args()
    if not args.tag.replace('-', '').isalnum():
        parser.error('Invalid tag')
    folder = ROOT / 'artifacts' / args.tag
    folder.mkdir(parents=True, exist_ok=False)
    environment = isolated_environment(folder)
    environment.update(RBPEW_RUNTIME_LOG='1', RBPEW_PILOT_ROOT=folder.as_posix(), RBPEW_PILOT_SECONDS=str(args.seconds))
    if args.continuous:environment['RBPEW_PILOT_AUTO_PAUSE']='0'
    if args.seed is not None:environment['RBPEW_PILOT_SEED']=str(args.seed)
    relative = Path('Godot/app_userdata/Run Build Pew! — Centipede/centipede-save.json')
    original = Path(os.environ['APPDATA']) / relative
    target = Path(environment['APPDATA']) / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(original, target)
    (folder / 'original-save-copy.json').write_bytes(original.read_bytes())
    executable = args.executable.resolve()
    if not executable.is_file():
        parser.error('Missing executable; pass --executable with an exported diagnostic build')
    executable_hash = hashlib.sha256(executable.read_bytes()).hexdigest()
    package_files=[]
    build_path=executable.parent/'build.json'
    if build_path.is_file():
        package_files=json.loads(build_path.read_text(encoding='utf-8')).get('runtime_files',[])
        for item in package_files:
            dependency=(executable.parent/item['path']).resolve()
            if not dependency.is_relative_to(executable.parent) or not dependency.is_file() or hashlib.sha256(dependency.read_bytes()).hexdigest()!=item['sha256']:
                raise RuntimeError('Release file is missing or differs from build manifest: '+item['path'])
    command = [str(executable), '--windowed', '--resolution', '1440x900', '--position', '80,50',
               '--log-file', str(folder/'engine.log'), '--', '--conservative-playtest']
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 5
    with (folder / 'stdout.log').open('w', encoding='utf-8') as output:
        process = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=output, stderr=subprocess.STDOUT, startupinfo=startup)
        metadata = {'pid':process.pid, 'folder':str(folder), 'command':command,
                    'started_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    'scope':'Real clock, normal health/damage/waves/rewards, copied existing progression, no performance fixture. Controller steers movement and invokes normal reward/build callbacks.'}
        metadata['controller_source_sha256'] = hashlib.sha256((ROOT/'scripts/conservative_pilot.gd').read_bytes()).hexdigest()
        metadata['executable_sha256'] = executable_hash
        metadata['executable_bytes'] = executable.stat().st_size
        manifest = executable.parent / 'source-manifest.json'
        if manifest.is_file():
            metadata['package_source_manifest_sha256'] = hashlib.sha256(manifest.read_bytes()).hexdigest()
        metadata['original_save_sha256'] = hashlib.sha256(original.read_bytes()).hexdigest()
        metadata['continuous_controller'] = args.continuous
        metadata['requested_controller_seed'] = args.seed
        metadata['runtime_files'] = package_files
        metadata['requested_session_mute'] = args.muted
        (folder/'launch.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(metadata, ensure_ascii=False), flush=True)
        if args.muted:
            mute_startup=subprocess.STARTUPINFO();mute_startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;mute_startup.wShowWindow=subprocess.SW_HIDE
            mute_command=[shutil.which('pwsh') or 'powershell.exe','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',str(ROOT/'tools/mute_process_audio.ps1'),'-TargetPid',str(process.pid),'-ExpectedExecutable',str(executable)]
            try:
                mute_result=subprocess.run(mute_command,cwd=ROOT,env=environment,startupinfo=mute_startup,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=25)
                metadata['audio_session_muted']=mute_result.returncode==0
                (folder/'session-mute.log').write_text(mute_result.stdout+mute_result.stderr,encoding='utf-8')
            except (OSError,subprocess.TimeoutExpired) as error:
                metadata['audio_session_muted']=False
                (folder/'session-mute.log').write_text(str(error),encoding='utf-8')
            (folder/'launch.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
            print(json.dumps({'pid':process.pid,'audio_session_muted':metadata['audio_session_muted']}),flush=True)
        return process.wait()


if __name__ == '__main__':
    raise SystemExit(main())
