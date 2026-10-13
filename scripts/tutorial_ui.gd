extends CanvasLayer
const UI=preload("res://scripts/game_ui.gd")
var cards:Dictionary={}
var prompts:Dictionary={}
var keys:Dictionary={}
var joystick=false
var db
var save
var view
var config:Dictionary
var shown:Dictionary={}
var elapsed=0.0
var started=false
var movement_shown=false
var radar_shown=false
var fuel_shown=false
var last_packs=0
func setup(source,store):
 db=source;save=store;layer=4;config=db.scene_config.TutorialMenuController
 view=load('res://scripts/source_ui.gd').new();add_child(view);view.setup(db,'GameScene/Tutorial Canvas',func(_m,_i,_a):pass)
 for key in ['move','shoot','boost','radar','build','run']:view.show_node(ref(key),false)
 build_cards()
func build_cards():
 UI.protect(view);view.theme=UI.theme();view.scale=Vector2.ONE;view.position=Vector2.ZERO
 var index=0
 for key in ['move','shoot','boost','radar','build','run']:
  var node=view.controls.get(ref(key))
  if node==null:continue
  for child in node.get_children():child.hide()
  node.position=Vector2(36,550+(index%3)*96);node.size=Vector2(360,82);node.pivot_offset=Vector2.ZERO
  UI.panel(node,Rect2(0,0,360,82))
  UI.icon(node,{'move':'next','shoot':'target','boost':'play','radar':'target','build':'settings','run':'play'}[key],Vector2(16,22),36)
  keys[key]=UI.label(node,"",Vector2(68,12),25,UI.AMBER)
  prompts[key]=UI.label(node,"",Vector2(68,48),16,UI.MUTED)
  cards[key]=node;index+=1
 refresh_bindings()
func refresh_bindings(using_joy:bool=false):
 joystick=using_joy;view.set_binding_labels(save.state.settings.bindings,using_joy)
 var input=load('res://scripts/input_system.gd')
 for key in keys:
  var binding="W A S D" if key=='move' else (db.ui("MOUSE","鼠标") if key=='shoot' else OS.get_keycode_string(int(save.state.settings.bindings.get(key,input.DEFAULTS.get(key,KEY_SPACE)))))
  if joystick:binding={'move':'L','shoot':'R / RT','boost':'LT','radar':'A','build':'B','run':'RT'}[key]
  keys[key].text=binding
  prompts[key].text=db.text({'move':'Tutorial_Move','shoot':'Tutorial_Shoot','boost':'Tutorial_Boost','radar':'Tutorial_Radar','build':'Tutorial_Build','run':'Tutorial_Run'}[key])
func refresh_language():
 # Change existing labels in place so visible tips, tweens and counters survive.
 refresh_localized_labels(view.layouts['GameScene/Tutorial Canvas'])
 refresh_bindings(joystick)
func refresh_localized_labels(data:Dictionary):
 var activation:Dictionary=data.get('components',{}).get('LocalizationTextActivator',{})
 if not activation.is_empty() and view.labels.has(data.id):
  view.set_text(data.id,db.text(str(activation.IDString).strip_edges()))
  view.labels[data.id].add_theme_font_override('font',UI.theme().default_font)
 for child in data.children:refresh_localized_labels(child)
func ref(key:String)->String:return str(int(config[key+'Tutorial'].fileID))
func reset_run():
 elapsed=0;started=false;movement_shown=false;radar_shown=false;fuel_shown=false;last_packs=0
 for timer in shown.values():if is_instance_valid(timer):timer.kill()
 shown.clear()
 for key in ['move','shoot','boost','radar','build','run']:view.show_node(ref(key),false)
func tick(dt:float,playing:bool,player,run):
 if not playing:return
 elapsed+=dt
 if elapsed>=2 and not movement_shown:movement_shown=true;show_tip('move');show_tip('shoot')
 if elapsed>=22 and not radar_shown:radar_shown=true;show_tip('radar')
 if player.max_fuel>0 and not fuel_shown:fuel_shown=true;show_tip('boost')
 if run.packs>last_packs:show_tip('build')
 last_packs=run.packs
func show_tip(key:String):
 if shown.has(key):return
 var name=key.capitalize()+'Tutorial'
 var count=int(save.state.tutorials.get(name,0))+1;save.state.tutorials[name]=count;save.save()
 # Source ShowTutorial field is unused; the executable gate is the per-save count.
 if count>int(config.tutorialShowCount):return
 var node=view.controls.get(ref(key))
 if node==null:return
 node.visible=true;node.scale=Vector2.ZERO
 var tween=create_tween();shown[key]=tween
 var duration=[0.25,0.5,1.0,1.5,3.0,6.0][int(config.tutorialTweenDuration)]
 tween.tween_property(node,'scale',Vector2.ONE,duration)
 tween.tween_interval(float(config.tutorialOnScreenDuration))
 tween.tween_property(node,'scale',Vector2.ZERO,duration)
 tween.tween_callback(func():node.visible=false;shown.erase(key))
