extends SceneTree
## Render real screens and a reproducible combat fixture without reading user saves.
var game
var checks: Array=[]
var captures: Array=[]
const Ink = preload("res://scripts/blue_ink.gd")
func _initialize(): call_deferred("execute")
func check(value:bool,title:String):
	checks.append({"name":title,"passed":value})
	if not value:printerr("FAIL: ",title)

func capture(label:String):
	game._process(0)
	game.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var picture=root.get_texture().get_image()
	var path="res://artifacts/blue-ink-"+label+".png"
	check(picture.save_png(path)==OK,"Captured "+label)
	captures.append(path)

func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.save.state.settings.skip_boss=true
	game.show_menu()
	await capture("01-menu")
	game.show_missions()
	await capture("02-missions")
	check(is_instance_valid(game.mission_ui) and game.mission_ui.rows.size()==6,"Mission briefing uses the new six-mission ink layout")
	game.show_options()
	await capture("03-options")
	var audio_config=game.source_ui.components["22641"]
	check(game.source_ui.labels[str(int(audio_config.sliderPercent.fileID))].text=="%d%%"%roundi(game.options_draft.volume*100),"Audio percentage matches the actual slider value")
	game.show_lab()
	await capture("04-research")
	var research=game.panel.get_child(0)
	research.show_detail(game.db.research[0],0)
	await capture("05-research-detail")
	game.start_run()
	game.show_loading()
	await capture("06-loading")
	game.run.rewards.enqueue(true)
	game.show_rewards()
	await capture("07-rewards")
	check(game.reward_ui.buttons.size()==3,"Reward view preserves three source choices")
	game.postpone_rewards()
	game.show_pause()
	await capture("08-pause")
	game.show_game()
	game.camera_focus.clear()
	game.combat.enemies.clear()
	game.combat.drones.clear()
	for name in ["Core_Gun_Gatling","Core_Gun_Cannon","Core_Gun_Shotgun"]:game.player.append_segment(game.db.named(name).id)
	for frame in range(170):
		game.player.step(1.0/60.0,Vector2.from_angle(-0.6+frame*0.006),false)
	game.camera=game.player.head-Vector2(80,0)
	for offset in [Vector2(240,-190),Vector2(300,100),Vector2(410,-30)]:
		var enemy=game.combat.spawn(game.db.pool["250"],game.player.head+offset)
		enemy.angle=(game.player.head-enemy.position).angle()
	game.combat.fire(game.db.named("Core_Gun_Cannon"),game.player.head,Vector2(1,-0.4).normalized(),true)
	game.combat.explosion(game.player.head+Vector2(190,100),80)
	game._process(0.016)
	await create_timer(0.08).timeout
	await capture("09-combat")
	# Same head position and aim; only the independently animated mouth changes.
	game.combat.enemies.clear();game.combat.effects.clear();game.combat.bullets.clear();game.particle_effects.clear()
	game.zoom=2.2;game.camera=game.player.head-Vector2(30,0);game.mouth_activity=1.0
	game.test_time=0.04
	await capture("10-mouth-open")
	game.test_time=0.22
	await capture("11-mouth-close")
	check(game.player.parts[1].position.distance_to(game.player.parts[2].position)>50,"Square mounted segments remain separate after turning")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear()
	game.process_mode=Node.PROCESS_MODE_DISABLED
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed),"scope":"Real screens plus explicitly staged enemy/explosion and mouth-animation fixtures."}
	FileAccess.open("res://artifacts/blue-ink-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
