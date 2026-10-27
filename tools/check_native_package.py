"""Verify a copied standalone Windows package loads its own native library."""
import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time
from run_checks import ROOT, isolated_environment


def modules(pid):
    kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    psapi=ctypes.WinDLL('psapi',use_last_error=True)
    kernel.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD]
    kernel.OpenProcess.restype=wintypes.HANDLE
    kernel.CloseHandle.argtypes=[wintypes.HANDLE]
    psapi.EnumProcessModulesEx.argtypes=[wintypes.HANDLE,ctypes.POINTER(wintypes.HMODULE),wintypes.DWORD,ctypes.POINTER(wintypes.DWORD),wintypes.DWORD]
    psapi.GetModuleFileNameExW.argtypes=[wintypes.HANDLE,wintypes.HMODULE,wintypes.LPWSTR,wintypes.DWORD]
    handle=kernel.OpenProcess(0x410,False,pid)
    if not handle:return []
    try:
        handles=(wintypes.HMODULE*2048)();needed=wintypes.DWORD()
        if not psapi.EnumProcessModulesEx(handle,handles,ctypes.sizeof(handles),ctypes.byref(needed),3):return []
        result=[]
        for item in handles[:min(2048,needed.value//ctypes.sizeof(wintypes.HMODULE))]:
            name=ctypes.create_unicode_buffer(32768)
            if psapi.GetModuleFileNameExW(handle,item,name,len(name)):result.append(Path(name.value))
        return result
    finally:kernel.CloseHandle(handle)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('executable',type=Path)
    parser.add_argument('--tag',required=True)
    args=parser.parse_args()
    if not args.tag.replace('-','').isalnum():parser.error('Invalid tag')
    source=args.executable.resolve().parent
    build=json.loads((source/'build.json').read_text(encoding='utf-8'))
    folder=ROOT/'artifacts'/args.tag;folder.mkdir(exist_ok=False)
    package=folder/'package';package.mkdir()
    for item in build['runtime_files']:
        original=(source/item['path']).resolve()
        if not original.is_relative_to(source) or hashlib.sha256(original.read_bytes()).hexdigest()!=item['sha256']:raise RuntimeError('Source dependency changed')
        target=package/item['path'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(original,target)
    case=folder/'result';case.mkdir()
    env=isolated_environment(case)
    snapshot=ROOT/'artifacts/cpu-depth-live-20261027/stop-states/1800-battle-state.bin'
    env.update(RBPEW_REPLAY_ROOT=str(case),RBPEW_BATTLE_SNAPSHOT=str(snapshot),RBPEW_REPLAY_WARMUP='20',RBPEW_REPLAY_SAMPLES='120',RBPEW_RUNTIME_LOG='1',RBPEW_PROFILE='1',RBPEW_ENABLE_NATIVE_CAVE_SWEEP='1',RBPEW_ENABLE_NATIVE_OVERLAP='1',RBPEW_ENABLE_WIDE_NEAR_CONTACT='1')
    relative=Path('Godot/app_userdata/Run Build Pew! — Centipede/centipede-save.json')
    save=Path(env['APPDATA'])/relative;save.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/'artifacts/cpu-depth-live-20261027/original-save-copy.json',save)
    command=[str(package/args.executable.name),'--headless','--audio-driver','Dummy','--fixed-fps','60','--log-file',str(case/'engine.log'),'--','--battle-replay']
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=subprocess.SW_HIDE
    process=subprocess.Popen(command,cwd=package,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',startupinfo=startup)
    loaded=[];began=time.monotonic()
    while process.poll() is None and time.monotonic()-began<30 and not loaded:
        loaded=[p.resolve() for p in modules(process.pid) if p.name.lower()=='cave_sweep.windows.x86_64.dll']
        if not loaded:time.sleep(.1)
    output,_=process.communicate(timeout=120)
    (case/'stdout.log').write_text(output,encoding='utf-8')
    replay=json.loads((case/'replay-report.json').read_text(encoding='utf-8'))
    counts=replay['counts']
    passed=process.returncode==0 and replay['passed'] and bool(loaded) and all(p.is_relative_to(package) for p in loaded) and counts.get('native_sweep_loaded') and counts.get('native_sweep_queries',0)>0 and counts.get('native_sweep_overlapQueries',0)>0
    result={'passed':bool(passed),'loaded_libraries':[str(p) for p in loaded],'cwd':str(package),'native_queries':counts.get('native_sweep_queries'),'native_overlap_queries':counts.get('native_sweep_overlapQueries'),'scope':'Copied only declared runtime files; launched from copied folder without --path. OS module enumeration verifies the actual DLL came from that folder. Load/query check, not an FPS acceptance run.'}
    (folder/'native-package-check.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result),flush=True)
    if not passed:raise RuntimeError('Clean package native verification failed')


if __name__=='__main__':main()
