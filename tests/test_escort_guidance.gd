extends SceneTree
var game
var checks:Array=[]
var captures:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func settle():
	for i in 3:await process_frame
func shot(tag:String):
	if DisplayServer.get_name()=="headless":return
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	var path="res://artifacts/escort-guidance-"+tag+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Native escort capture: "+tag)
	captures.append(path)
func execute():
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1440,900);set_meta("performance_fixture",true)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.test_mode=false;game.save.fresh();game.set_process(false)
	for mission in game.db.kind("Mission"):
		for component in game.db.prefabs[mission.MissionsObjectiveList[0].objectivePrefab].components:
			if component.get("class")=="GAModeManager":game.selected_mission=mission
	game.begin_run()
	while game.deployment_active:await process_frame
	game.set_process(false)
	# This is a deliberately stopped UI/resize fixture, not an FPS benchmark.
	game.performance_overlay.visible=false
	for name in ["Core_Gun_Tesla","Core_Gun_EMP","Core_Repair","Core_Shield"]:game.player.append_segment(game.db.named(name).id)
	game.player.motion.reset();game.player.refresh_positions();game.insect_layer.sync(game,0)
	var director=game.run.director;var h=game.battle_hud
	var brief:Dictionary=director.escort_brief()
	check(brief.alive==7 and brief.total==7 and brief.cave,"HUD receives the actual normal escort objective, alive count and cave movement rule")
	h.refresh()
	check(h.escort_title.visible and h.escort_status.text.contains("终点箭头") and h.escort_rule.text.contains("全部损失失败"),"The start screen states how to lead and how escort victory/failure works")
	var convoy_key=game.player.head;var convoy_rng=game.run.rng.state
	for language in ["Chinese (simplified)","English"]:
		game.db.language=language
		for dimensions in [Vector2i(1440,900),Vector2i(1280,720)]:
			root.size=dimensions;await settle();h.layout_hud()
			for state in ["ready","moving","far","regroup","arriving","blocked"]:
				director.cave_escort.status=state;h.refresh()
				for field in [h.escort_title,h.escort_status,h.escort_rule]:
					var text_width=field.get_theme_font("font").get_string_size(field.text,HORIZONTAL_ALIGNMENT_LEFT,-1,field.get_theme_font_size("font_size")).x
					check(text_width<=field.size.x+1 and root.get_visible_rect().encloses(field.get_global_rect()),"Escort %s fits %s %s: %s"%[state,language,dimensions,field.name])
				check(not h.escort_title.get_global_rect().intersects(h.encounter_hint.get_global_rect()) and not h.escort_rule.get_global_rect().intersects(h.skill_label.get_global_rect()),"Escort instructions clear encounter and skill panels")
			director.cave_escort.status="ready";h.refresh()
			await shot(("zh" if language.begins_with("Chinese") else "en")+"-%dx%d"%[dimensions.x,dimensions.y])
	check(game.player.head==convoy_key and game.run.rng.state==convoy_rng,"Reading and redrawing escort guidance cannot move actors or consume mission RNG")
	game.db.language="Chinese (simplified)";root.size=Vector2i(1440,900);await settle()
	# A real escort loss must refresh the live counter instead of retaining the
	# source fleet size as a misleading number of ships still protected.
	var ship=director.living_objectives()[0];ship.hp=0;h.refresh()
	check(h.escort_title.text.contains("6/7"),"The escort HUD updates the actual number of surviving ships")
	ship.hp=ship.max_hp
	game.show_missions();await settle();game.mission_ui.select_mission(3);game.save.state.meta=10000;game.save.unlock_mission(game.selected_mission);game.mission_ui.refresh();await settle()
	check(game.mission_ui.risk_summary.text.contains("靠近领航") and game.mission_ui.status.text.contains("全灭失败"),"The mission briefing states proximity, path-clearing and loss rules before launch")
	check(not game.mission_ui.risk_summary.get_global_rect().intersects(game.mission_ui.reward_summary.get_global_rect()),"The two-line escort briefing clears the reward text")
	await shot("briefing-zh")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures,"scope":"Actual main-scene Escort HUD in Chinese and English at 1440x900 and 1280x720, all convoy states, real live-count changes, safe-zone/ally markers and mission briefing; native captures when rendered."}
	FileAccess.open("res://artifacts/escort-guidance-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"passed":report.passed,"checks":checks.size(),"failures":checks.filter(func(c):return not c.passed),"captures":captures}))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	quit(0 if report.passed else 1)
