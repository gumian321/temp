extends SceneTree
## Standalone native UI fixture independent of main-game integration.
var checks:Array=[]
class Fixture extends RefCounted:
 var db=preload("res://scripts/source_db.gd").new()
 var save=preload("res://scripts/save_store.gd").new(db,"user://expedition-fixture.json",false)
 var selected_mission:Dictionary
 var difficulty=0
 var launched=false
 var screen="menu"
 func _init():selected_mission=db.asset(db.stores.MissionDataStore.missionsList[0])
 func show_menu():screen="home"
 func show_reward_pool():screen="reward_pool"
 func begin_run():launched=true
func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
 checks.append({"name":label,"passed":ok})
 if not ok:printerr("FAIL: "+label)
func settle():
 for i in 5:await process_frame
func execute():
 root.content_scale_size=Vector2i.ZERO
 var owner=Fixture.new()
 var view=preload("res://scripts/mission_select.gd").new();root.add_child(view);view.setup(owner);await settle()
 check(view.scene_art.clip_contents,"Mission illustration clips to reserved bounds")
 check(view.scene_art.size==Vector2(676,338),"Hero actual size matches reserved image area")
 for b in view.rows:
  var image=b.get_child(0)
  check(image.size==Vector2(96,72),"Thumbnail actual size matches reserved image area")
  check(b.clip_contents,"Thumbnail clips raster to card")
 var names=["生存","无尽","猎杀","护航","破巢","守卫"]
 for language in ["Chinese (simplified)","English"]:
  owner.db.language=language
  view.queue_free();await settle()
  view=preload("res://scripts/mission_select.gd").new();root.add_child(view);view.setup(owner);await settle()
  for window in [Vector2i(1280,720),Vector2i(1920,1080)]:
   root.size=window;await settle()
   for i in 6:
    view.select_mission(i);await settle()
    check(root.get_visible_rect().encloses(view.board.get_global_rect()),"Board fits %s %s"%[language,window])
    if language.begins_with("Chinese"):check(view.title.text==names[i],"Title mapped to correct mission %d"%i)
    check(bool(owner.selected_mission.isEndless)==(i==1),"Endless source mapping %d"%i)
    check(view.scene_art.mission_index==i and view.scene_icons[i].selected,"Mission painting and selected icon match mission %d"%i)
    for b in view.difficulty_buttons:check(view.board.get_global_rect().encloses(b.get_global_rect()),"Difficulty fits board")
    check(not view.pool_button.get_global_rect().intersects(view.pool_summary.get_global_rect()),"Loot summary clear of button")
    check(not view.reward_summary.get_global_rect().intersects(view.launch_button.get_global_rect()),"Rewards clear of launch")
    for d in 3:
     view.select_difficulty(d);await settle()
     check(owner.difficulty==d and view.difficulty_buttons[d].button_pressed,"Difficulty selected")
     var config=owner.db.asset(owner.selected_mission.MissionsObjectiveList[d].objectiveAIConfiguration)
     check(view.risk_summary.text.contains(str(int(config.MaxWaveCount))),"Risk source values correct")
    if DisplayServer.get_name()!="headless" and (language.begins_with("Chinese") or i==1):
     await RenderingServer.frame_post_draw
     var file="res://artifacts/expedition-%s-%dx%d-%d.png"%["zh" if language.begins_with("Chinese") else "en",window.x,window.y,i]
     check(root.get_texture().get_image().save_png(file)==OK,"Native screenshot saved")
 owner.save.state.meta=0;view.select_mission(1);await settle();check(view.launch_button.disabled,"Locked mission cannot launch")
 owner.save.state.meta=200;view.refresh();view.launch();check(owner.save.state.meta==100,"Unlock source cost charged once")
 view.launch();check(owner.launched,"Unlocked mission deploys")
 view.queue_free();await settle()
 var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
 FileAccess.open("res://artifacts/expedition-briefing-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report));quit(0 if report.passed else 1)
