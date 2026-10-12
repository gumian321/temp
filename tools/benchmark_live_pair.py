import os,subprocess,json,time
from pathlib import Path
R=Path(__file__).resolve().parents[1];base=Path('/workspace/scratch/perf-baseline');reports=[]
for label,root,revision in [('before',base,'cac76a1'),('after',R,'1a1062e')]:
 env=os.environ|{'DISPLAY':':99','LP_NUM_THREADS':'3','RBPEW_WARMUP':'1','RBPEW_PROFILE':'1','RBPEW_REVISION':revision,'RBPEW_CAPTURE_DIR':str(R/'artifacts/benchmarks'),'XDG_DATA_HOME':'/workspace/scratch/paired-benchmark-data','XDG_CONFIG_HOME':'/workspace/scratch/xdg-config','XDG_CACHE_HOME':'/workspace/scratch/cache'}
 p=subprocess.run(['godot','--audio-driver','Dummy','--path',str(root),'--script','tests/test_stress_gui.gd'],env=env,capture_output=True,text=True,timeout=100);(R/f'artifacts/paired-{label}.log').write_text(p.stdout+p.stderr)
 if p.returncode or 'ERROR:'in p.stdout+p.stderr:raise RuntimeError(label+' engine error')
 report=json.loads((root/'artifacts/gui-stress-report.json').read_text());(R/f'artifacts/paired-{label}.json').write_text(json.dumps(report,indent=2));reports.append(report);print(label,report['average_fps'],report['p95_frame_ms'],flush=True)
(R/'artifacts/paired-performance-report.json').write_text(json.dumps({'conditions':'Sequential independent Godot processes, same cloud X11/1440x900, same 60-source-module fixture and fixed pointer, 8s shader warmup then reset, 30s measurement, LP_NUM_THREADS=3 in both. No reduced modules, enemies, projectiles, or particles.','before':reports[0],'after':reports[1],'fps_change_percent':(reports[1]['average_fps']/reports[0]['average_fps']-1)*100},indent=2))
