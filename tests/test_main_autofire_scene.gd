extends "res://tests/test_centipede_scene.gd"
var pointer_position=Vector2.ZERO
var input_viewport:SubViewport
func mouse(point:Vector2,pressed=false):
	pointer_position=point
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
	input_viewport.push_input(motion,true)
	var button=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_LEFT;button.position=point;button.global_position=point;button.pressed=pressed;Input.parse_input_event(button)
	input_viewport.push_input(button,true)
func axis(id:int,value:float):
	var event=InputEventJoypadMotion.new();event.device=0;event.axis=id;event.axis_value=value;Input.parse_input_event(event)
	input_viewport.push_input(event,true)
func shots():return int(game.combat.statistics.get("stat_BulletsFired",0))
func simulate(frames=90):
	for frame in range(frames):game._process(1.0/60)
func execute():
	root.size=Vector2i(1440,900)
	# A real SubViewport keeps injected local coordinates independent of the
	# desktop cursor while the native test window is offscreen on Windows.
	input_viewport=SubViewport.new();input_viewport.size=root.size;input_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(input_viewport)
	game=load("res://main.tscn").instantiate();input_viewport.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.state.settings.skip_boss=true
	game.start_run();await process_frame
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
	game.combat.enemies.clear();game.combat.drones.clear()
	game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true
	var enemy=game.combat.spawn(game.db.pool["250"],game.player.head+Vector2(180,0))
	enemy.guns=[];enemy.mission_controlled=true;enemy.hp=100000;enemy.max_hp=100000
	mouse(Vector2(700,600));await process_frame
	check(not game.main_weapon_input().manual,"Pointer motion alone leaves automatic mode active")
	simulate()
	check(shots()>0 and enemy.hp<enemy.max_hp,"Real main scene automatically fires and damages target without any fire input")
	mouse(Vector2(700,700),true);await process_frame
	check(game.main_weapon_input().manual,"Held left mouse takes manual control")
	simulate()
	var expected_aim=(pointer_position-game.center)/game.zoom+game.camera
	check(absf(angle_difference(game.player.parts[0].angle,(expected_aim-game.player.weapon_origin(0)).angle()))<.02,"Mouse aim follows the injected pointer direction away from the automatic target")
	mouse(Vector2(700,700));await process_frame;simulate()
	check(not game.main_weapon_input().manual and absf(game.player.parts[0].angle)<0.01,"Mouse release returns to auto aim")
	axis(JOY_AXIS_RIGHT_Y,0.1);await process_frame
	check(not game.main_weapon_input().manual,"Controller drift below deadzone does not steal automatic control")
	axis(JOY_AXIS_RIGHT_Y,1.0);await process_frame
	check(game.main_weapon_input().manual,"Right stick above deadzone fires without needing trigger")
	simulate();check(absf(game.player.parts[0].angle-PI/2)<0.01,"Controller manual direction overrides enemy")
	axis(JOY_AXIS_RIGHT_Y,0);await process_frame;simulate()
	check(not game.main_weapon_input().manual and absf(game.player.parts[0].angle)<0.01,"Neutral stick restores automatic targeting")
	axis(JOY_AXIS_TRIGGER_RIGHT,1);await process_frame
	check(game.main_weapon_input().manual,"Existing controller trigger manual control remains available")
	axis(JOY_AXIS_TRIGGER_RIGHT,0);await process_frame
	var key=InputEventKey.new();key.physical_keycode=KEY_W;key.pressed=true;Input.parse_input_event(key);await process_frame
	check(not game.main_weapon_input().manual,"Keyboard movement after controller use does not steal auto aim")
	key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
	var blocker=Button.new();blocker.position=Vector2(580,520);blocker.size=Vector2(260,210);game.panel.add_child(blocker)
	mouse(Vector2(700,600),true);await process_frame;await process_frame
	check(not game.main_weapon_input().enabled,"Hovered UI button blocks weapon input")
	var before=shots();simulate();check(shots()==before,"UI click does not leak any manual or automatic shots")
	blocker.queue_free();await process_frame
	var motion=InputEventMouseMotion.new();motion.position=Vector2(900,650);motion.global_position=motion.position;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(motion);await process_frame
	check(not game.main_weapon_input().enabled,"UI-origin mouse hold cannot leak shots after the UI disappears")
	mouse(Vector2(900,650));await process_frame
	check(game.main_weapon_input().enabled,"Releasing the consumed UI click restores automatic fire")
	game.show_pause();before=shots();simulate()
	check(shots()==before and not game.main_weapon_input().enabled,"Paused screen cannot shoot")
	game.show_game();await process_frame;simulate()
	check(shots()>before,"Resume restores automatic firing")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed),"method":"Production main scene in an isolated native SubViewport, Input.parse_input_event and Viewport.push_input. Physical controller hardware not used."}
	FileAccess.open("res://artifacts/main-autofire-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
