import json,subprocess,concurrent.futures
from pathlib import Path
R=Path(__file__).resolve().parents[1];S=Path('/workspace/run-build-pew-source/UnityCore');out=R/'assets/videos';out.mkdir(exist_ok=True)
g=json.load(open(R/'data/source_guids.json'))
def convert(item):
 guid,path=item;dest=out/(guid+'.ogv')
 if dest.exists():return
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(S/path),'-vf','scale=480:-2','-an','-c:v','libtheora','-q:v','5','-threads','1',str(dest)],check=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(convert,[(k,v) for k,v in g.items() if v.endswith('.mp4')]))
print('Transcoded',len(list(out.glob('*.ogv'))),'source preview videos')
