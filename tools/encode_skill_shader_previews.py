#!/usr/bin/env python3
"""Encode exact native Godot viewport frames; no synthetic interpolation."""
from pathlib import Path
import json, subprocess
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts'/'round14'
clips=[('shader-frames',15,'attack-shader-clock-only'),('passive-frames',15,'passive-shader-clock-only'),('shield-frames',30,'shield-state-sequence'),('weapon-frames',20,'all-weapon-production')]
for folder,fps,label in clips:
    frames=sorted((OUT/folder).glob('frame-*.png'))
    if not frames: raise SystemExit(f'Missing native frames: {folder}')
    target=OUT/(label+'.mp4')
    subprocess.run(['ffmpeg','-y','-v','error','-framerate',str(fps),'-i',str(OUT/folder/'frame-%04d.png'),'-vf','pad=ceil(iw/2)*2:ceil(ih/2)*2','-c:v','libx264','-threads','2','-preset','medium','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(target)],check=True)
    probe=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration,size','-show_entries','stream=width,height,nb_frames,avg_frame_rate','-of','json',str(target)],capture_output=True,text=True,check=True)
    metadata=json.loads(probe.stdout)
    metadata['source_native_frames']=len(frames)
    metadata['scope']='Exact native OpenGL Godot viewport captures. Encoded at simulation sampling rate; not a performance recording or user GPU FPS measurement.'
    (OUT/(label+'-video.json')).write_text(json.dumps(metadata,indent=2)+'\n')
    print(target)
