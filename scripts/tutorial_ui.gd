extends CanvasLayer
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
