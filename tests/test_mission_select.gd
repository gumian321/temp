extends "res://tests/test_centipede_scene.gd"
var geometry: Array=[]
var raster_sizes: Array=[]
func settle():
 for i in 5:await process_frame
func key(code: int):
 var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await settle()
func joy(code: int):
 var event=InputEventJoypadButton.new();event.device=0;event.button_index=code;event.pressed=true;Input.parse_input_event(event);await process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await settle()
func screenshot(tag: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var file="res://artifacts/mission-ui-"+tag+".png"
 var image=root.get_texture().get_image()
 check(image.save_png(file)==OK,"Captured "+tag)
 raster_sizes.append({"case":tag,"width":image.get_width(),"height":image.get_height()})
 captures.append(file)
func inspect_geometry(tag: String):
 var view=game.mission_ui
 var rect=view.board.get_global_rect()
 var viewport=root.get_visible_rect()
 var center_error=rect.get_center().distance_to(viewport.get_center())
 check(center_error<1.0,"Board centred at "+tag)
 check(viewport.encloses(rect),"Board inside viewport at "+tag)
 var controls:Array=[];game.collect_focus_buttons(view,controls)
 var outside=[]
 for c in controls:
  if not rect.encloses(c.get_global_rect()):outside.append(c.text)
 var labels=[view.title,view.description,view.objective_text,view.duration,view.mode_label,view.points,view.status,view.pool_summary]
 for l in labels:
  if not rect.encloses(l.get_global_rect()):outside.append(l.text)
 check(outside.is_empty(),"Buttons and text inside board at "+tag)
 geometry.append({"case":tag,"viewport":[viewport.size.x,viewport.size.y],"board":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"center_error":center_error,"outside":outside})
func execute():
 var original_scale=root.content_scale_size
 root.content_scale_size=Vector2i.ZERO
 root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
 game.set_process(false);game.save.fresh();game.save.state.settings.skip_boss=true;game.test_mode=true
 game.show_missions();await settle()
 check(game.mission_ui.rows.size()==6,"All six source missions present")
 check(game.mission_ui.difficulty_buttons[0].get_theme_color("font_hover_pressed_color")==Color("173b70"),"Selected difficulty remains dark and readable while hovered")
 check(root.gui_get_focus_owner()==game.mission_ui.rows[0],"Initial focus follows selected mission")
 for size_value in [Vector2i(1440,900),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1100,820),Vector2i(1440,900)]:
  root.size=size_value;await settle()
  var tag="%dx%d"%[size_value.x,size_value.y]
  inspect_geometry(tag)
  await screenshot(tag)
 # Test true viewport resizing too, rather than only window stretching.
 root.content_scale_size=original_scale
 for window_size in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=window_size;await settle()
  inspect_geometry("stretched-%dx%d"%[window_size.x,window_size.y])
  await screenshot("stretched-%dx%d"%[window_size.x,window_size.y])
 root.size=Vector2i(1440,900);await settle()
 # English remains selectable in the existing options; ensure longer labels fit.
 game.db.language="English";game.show_missions();await settle()
 for i in game.mission_ui.rows.size():
  game.mission_ui.select_mission(i);await settle();inspect_geometry("english-mission-%d"%i)
 game.db.language=game.db.DEFAULT_LANGUAGE;game.show_missions();await settle()
 for i in game.mission_ui.rows.size():
  await click_at(game.mission_ui.rows[i].get_global_rect().get_center());await settle()
  check(game.selected_mission.id==game.db.stores.MissionDataStore.missionsList[i],"Mouse selects mission %d"%i)
  for d in 3:
   await click_at(game.mission_ui.difficulty_buttons[d].get_global_rect().get_center());await settle()
   check(game.difficulty==d,"Difficulty %d selected for mission %d"%[d,i])
   check(game.mission_ui.duration.text.contains(str(int(game.selected_mission.MissionsObjectiveList[d].objectiveTime))) or bool(game.selected_mission.isEndless),"Objective time follows selected difficulty")
 # Insufficient points, purchase, and repeat selection must preserve the source rules.
 game.save.state.meta=0;game.mission_ui.select_mission(5);await settle()
 check(game.mission_ui.launch_button.disabled,"Locked mission cannot be launched without points")
 await screenshot("locked")
 game.save.state.meta=200;game.mission_ui.refresh();await settle()
 var cost=int(game.selected_mission.MissionCost)
 await click_at(game.mission_ui.launch_button.get_global_rect().get_center());await settle()
 check(game.save.mission_unlocked(game.selected_mission) and game.save.state.meta==200-cost and game.screen=="menu","Unlock charges once and stays on briefing")
 var selected=game.selected_mission.id;var level=game.difficulty
 await click_at(game.mission_ui.pool_button.get_global_rect().get_center());await settle()
 check(game.screen=="reward_pool","Reward pool opens from briefing")
 await key(KEY_ESCAPE)
 check(game.screen=="menu" and game.selected_mission.id==selected and game.difficulty==level,"Reward pool Escape preserves mission and difficulty")
 game.save.state.disabled.append(game.save.state.unlocked[0]);game.mission_ui.refresh();await settle()
 await click_at(game.mission_ui.reset_button.get_global_rect().get_center());await settle()
 check(game.save.state.disabled.is_empty(),"Reset reward modifiers still works")
 for i in 3:
  await click_at(game.mission_ui.back_button.get_global_rect().get_center());await settle();check(game.screen=="home","Back button returns home")
  game.show_missions();await settle();check(root.gui_get_focus_owner()!=null,"Repeated opening restores focus")
 game.mission_ui.rows[0].grab_focus();await key(KEY_DOWN)
 check(root.gui_get_focus_owner()==game.mission_ui.rows[1],"Keyboard down moves through mission list")
 await key(KEY_ENTER);check(game.selected_mission.id==game.db.stores.MissionDataStore.missionsList[1],"Keyboard Enter chooses focused mission")
 await key(KEY_RIGHT);check(root.gui_get_focus_owner() in game.mission_ui.difficulty_buttons,"Keyboard right reaches difficulty")
 game.mission_ui.rows[0].grab_focus();await joy(JOY_BUTTON_DPAD_DOWN);await joy(JOY_BUTTON_A)
 check(game.selected_mission.id==game.db.stores.MissionDataStore.missionsList[1],"Controller D-pad and A select mission")
 await joy(JOY_BUTTON_B);check(game.screen=="home","Controller B returns home")
 game.show_missions();await settle();await key(KEY_ESCAPE);check(game.screen=="home","Escape returns home from briefing")
 game.show_missions();await settle();game.mission_ui.select_mission(0);await settle()
 game.mission_ui.launch_button.grab_focus();await key(KEY_ENTER)
 check(game.screen=="game" and game.run.mission.id==game.selected_mission.id,"Deploy directly enters the selected mission")
 await settle();check(game.screen=="game","No extra confirmation is needed")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={"checks":checks,"geometry":geometry,"captures":captures,"raster_sizes":raster_sizes,"passed":checks.all(func(c):return c.passed),"controller":"Injected Godot events; no physical controller acceptance"}
 FileAccess.open("res://artifacts/mission-ui-test-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report));quit(0 if report.passed else 1)
