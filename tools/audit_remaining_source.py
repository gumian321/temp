"""Classify inventory rows with source type, serialized use and concrete port evidence."""
import json,csv,re,collections
from pathlib import Path
R=Path(__file__).resolve().parents[1];S=Path('/workspace/run-build-pew-source/UnityCore')
rows=list(csv.DictReader(open(R/'docs/source_feature_matrix.csv')));components=json.load(open(R/'data/source_components.json'));instances=collections.defaultdict(list)
for c in components:instances[c['class']].append({'path':c['path'],'file_id':str(c['file_id'])})
mapped={}
def group(names,code,note):
 for name in names.split():mapped[name]=(code,note)
group('AudioClipObject AudioDataStore','scripts/audio_system.gd; data/catalog.json','Source clips, gain, simultaneous voice limits and categories')
group('ColorHelper ImageSystem ObjectSystem ListSystem Randomizer UnityEngineSystem MasterPool SceneSingleton Singleton TweenController TweenDataStore TweenScaleDisable','scripts/source_db.gd; scripts/combat.gd; scripts/main.gd; scripts/source_ui.gd','Godot vectors/colors, arrays, RNG, nodes, timers/tweens and shared resource lifetime replace Unity helpers; caller-specific tests remain the evidence')
group('LocalizationFontStore','scripts/source_ui.gd','Original language/font switching and source TMP material color/outline')
group('ParticlesSystem CFX_AutoDestructShuriken CFX_AutoStopLoopedEffect CFX_AutodestructWhenNoChildren CFX_ShurikenThreadFix CFX_SpawnSystem','scripts/particle_effects.gd','Source emission/lifetime and automatic freeing; no claim of engine-internal particle integrator equivalence')
group('RewardScrapPackController','scripts/reward_director.gd; scripts/run_state.gd; scripts/main.gd','Source recycle flight/shrink, physical individual scrap scatter and drone-only collection')
group('PopUpTextController PopUpTextManager','scripts/popup_text.gd','Source one-second queue, position, text and fade')
group('MainMenuCameraManager','scripts/menu_background.gd','Serialized menu target positions and camera interpolation rates')
group('BindingUIAnimation UITriggersController UIButtonTiggersController UIEventTriggers','scripts/source_ui.gd; scripts/cursor_system.gd; scripts/input_system.gd','Click/hold hint cycle, source audio, controller focus and pointer state; Godot native signals replace EventTrigger callbacks')
group('GameObjectsSelector SpriteRandomSelector RandomRotator AutoRotator MovementArrowsController SpritePulseEffector','scripts/render_state.gd; tools/source_render_metadata.py; scripts/main.gd','Active hierarchy, one selected object, random sprite/angle, angular speed, sequential arrows and hit color')
group('PlayerDecorationManager','scripts/player_decorations.gd','Source 4-neighbor topology; 1/2/3/4 side shell rules and 75/25 engine/antenna choice; attachment follows centipede segments')
group('AIEnginesManager Engine','scripts/particle_effects.gd; data/engines.json; scripts/main.gd','109 source attachment bindings, directional switches and 0.25-second source boost size transition')
group('LineRendererSpriteAnimator TrailRendererClearer','scripts/native_visuals.gd; data/native_visuals.json','Imported source beam frames/intervals and trails; instance-local history starts empty')
group('ObjectTriggersController PickButton','scripts/research_ui.gd; scripts/reward_pool_ui.gd; scripts/main.gd','Native Godot pointer/focus events, locked research and reward buttons')
group('MapIconFixedRotation','scripts/main.gd','Minimap sprites rendered in screen coordinates without inherited ship rotation')
group('VersionUIController','scripts/source_ui.gd; data/ui_layouts.json','Source version label retained by Canvas import')
external={'AnalyticsManager','SteamAchievementsManager','SteamLeaderboardManager','SteamManager','SteamStatsManager','SteamUtilsManager','GameLeaderboardManager','GameLeaderboardUIManager','LeaderboardUIContainer','GoToURL'}
full_game={'DemoBuildManager':'GameBuildManager serialized gameVersion=2 FullGame; Demo StartDemo branch only runs for version=1', 'TestingManager':'IntroSceneManager.Start calls DisableTestingManager before loading menu; serialized cheat flags do not authorize enabling cheats', 'GameBuildManager':'FullGame/platform configuration retained; Steam launch/license/remote APIs remain external dependency'}
report=[]
for row in rows:
 name=row['类'];path=S/row['Unity源文件'];text=path.read_text() if path.exists() else '';category='mapped';note=row['验收边界']
 if name in mapped:
  code,note=mapped[name];row['Godot实现文件']=code;row['Godot状态']='行为已映射；见验收边界';row['验收边界']=note
 elif not row['Godot实现文件']:
  if name in external:category='external_dependency';note='Source online/platform behavior exists; blocked by missing native runtime/authenticated service environment. No fabricated remote results.'
  elif name in full_game:category='build_configuration';note=full_game[name]
  elif re.search(r'\b(enum|interface)\s+'+re.escape(name)+r'\b',text):category='type_contract';note='Source enum/interface, not an independent executable system; source numeric values retained in imported catalog or implemented caller contracts.'
  elif not row['方法']:category='data_contract';note='Source data/struct/attribute declaration with no inventoried methods; serialized fields retained by import, executable behavior belongs to callers.'
  elif not instances[name] and (name.startswith('CFX_') or name in {'AudioTester','LabCanvas','MenuBuildingManager','HeartBeatAudioController','HideUI','GizmosExtend','ColorScope','ScreenshotCapture','TransparencyCaptureToFile','zzTransparencyCapture','zzTransparencyCaptureExample','SimpleCameraController','SteamTester'}):category='uninstantiated_tool';note='No serialized instance in recovered scenes/prefabs. Tool/example/development path, not a reachable normal FullGame scene feature. Source retained read-only.'
  else:category='needs_review';note='Executable source row still needs concrete behavioral mapping.'
  row['Godot状态']=category;row['验收边界']=note
 report.append({'class':name,'source':row['Unity源文件'],'category':category,'instances':instances[name],'implementation':row['Godot实现文件'],'evidence':note})
with open(R/'docs/source_feature_matrix.csv','w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
summary=dict(collections.Counter(r['category'] for r in report));(R/'artifacts/source-classification-report.json').write_text(json.dumps({'counts':summary,'rows':report},ensure_ascii=False,indent=2));print(summary);print('Needs review:',[r['class'] for r in report if r['category']=='needs_review'])
