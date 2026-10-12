"""Preserve source research node coordinates and original preview video references."""
import runpy,contextlib,io,json
from pathlib import Path
with contextlib.redirect_stdout(io.StringIO()):d=runpy.run_path(str(Path(__file__).with_name('inspect_scene_ui.py')))
def world(go):
 t=d['ts'][d['ct'][go]];p=t['m_LocalPosition'];parent=d['ts'].get(t['m_Father']['fileID'],{}).get('m_GameObject',{}).get('fileID')
 if not parent:return [p['x'],p['y']]
 q=world(parent);return [p['x']+q[0],p['y']+q[1]]
nodes={}
for go,cs in d['cs'].items():
 for cls,c in cs:
  if cls=='UpgradeTreeNode':
   pos=world(go);nodes[str(next(x['__id'] for x in d['docs'] if x.get('MonoBehaviour') is c))]={'x':pos[0]-50,'y':-pos[1],'name':d['gos'][go]['m_Name']}
r=Path(__file__).resolve().parents[1]
(r/'data/research_layout.json').write_text(json.dumps(nodes))
videos={guid:'res://assets/videos/'+guid+'.ogv' for guid,path in d['g'].items() if path.endswith('.mp4')}
(r/'data/videos.json').write_text(json.dumps(videos))
print(len(nodes),'research nodes;',len(videos),'source videos')
