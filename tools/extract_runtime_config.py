import json,re
from pathlib import Path
R=Path(__file__).resolve().parents[1];data=R/'data'
guids=json.loads((data/'source_guids.json').read_text());components=json.loads((data/'source_components.json').read_text())
def clean(v):
 if isinstance(v,dict):
  if 'guid' in v:return v['guid']
  return {k:clean(x) for k,x in v.items() if not k.startswith('m_')}
 if isinstance(v,list):return [clean(x) for x in v]
 return v
wanted=['MainMenuCameraManager','ControlUIManager','UpgradeTreeManager','ToggleResearchUIManager','MapNodesManager','OptionMenuManager','TutorialMenuController','AudioManager','MinesManager','BackgroundColorChanger','CameraManager','MainMenuManager','LoadingPanelContorller','PlayUIManager','PauseMenuManager','GameOverMenuManager','GameMissionManager']
config={}
for x in components:
 if x['path'].endswith('.unity') and x['class'] in wanted and x['class'] not in config:config[x['class']]=clean(x['values'])
reverse={v:k for k,v in guids.items()}
rotations={}
for path in set(x['path'] for x in components if x['class']=='AIMissionStation'):
 local=[x for x in components if x['path']==path]
 speeds={str(x['values']['m_GameObject']['fileID']):x['values'].get('speed',25) for x in local if x['class']=='AutoRotator'}
 rotations[reverse[path]]={'rings':[speeds.get(str(x['values']['m_GameObject']['fileID']),0) for x in local if x['class']=='AIMissionStation'],'spawners':speeds}
config['station_rotations']=rotations
(data/'scene_config.json').write_text(json.dumps(config,separators=(',',':')))
audio={guid:'res://assets/audio/'+Path(path).name for guid,path in guids.items() if 'Assets/AudioClip/' in path and (R/'assets/audio'/Path(path).name).exists()}
(data/'audio.json').write_text(json.dumps(audio,separators=(',',':')))
print('Scene managers',len(config),'audio clips',len(audio))
