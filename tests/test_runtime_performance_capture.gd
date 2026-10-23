extends SceneTree
var game
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func execute():
	root.size=Vector2i(1440,900);set_meta("performance_fixture",true)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=false;game.save.fresh();game.start_run()
	game.performance_overlay.capture_filename="runtime-performance-fixture.json"
	game.reward_snoozed=true;game.reward_snooze_count=2147483647
	var profile_before=game.performance_profile_enabled;var combat_before=game.combat.profile_enabled
	var state_before=game.save.state.duplicate(true);var rng_before=game.combat.rng.state
	var key=InputEventKey.new();key.keycode=KEY_F3;key.physical_keycode=KEY_F3;key.pressed=true
	Input.parse_input_event(key);await process_frame;await process_frame
	check(game.performance_overlay.capture_active,"Real F3 input starts an explicit diagnostic capture")
	var began=Time.get_ticks_usec()
	while game.performance_overlay.capture_active and Time.get_ticks_usec()-began<5000000:
		await process_frame
	var overlay=game.performance_overlay
	check(not overlay.capture_active and not overlay.capture_path.is_empty(),"Capture finishes and exposes its actual output path")
	var report=JSON.parse_string(FileAccess.get_file_as_string(overlay.capture_path))
	check(report!=null and int(report.frames)>1 and report.rows.size()<=overlay.MAX_CAPTURE_ROWS,"Normal-play report contains bounded real frame samples")
	check(report.rows.all(func(row):return row.has("main_phases") and row.has("draw_calls") and row.has("hostile_bullets")),"Report includes CPU phases, render load and red projectile pressure")
	check(report.loadout.size()==game.player.parts.size() and report.has("run_elapsed") and str(report.source_combat_sha256).length()==64 and str(report.source_terrain_sha256).length()==64,"Capture records equipment, run age and the combat/terrain source fingerprints")
	check(game.performance_profile_enabled==profile_before and game.combat.profile_enabled==combat_before,"Profiler flags restore their previous state after recording")
	check(game.save.state==state_before and game.combat.rng.state==rng_before,"Sampling alone never changes player progress or gameplay random state")
	game.show_pause();overlay.begin_capture(.1)
	check(not overlay.capture_active,"A paused screen cannot start a live-combat capture")
	game.show_game();overlay.begin_capture(.1)
	var live_deadline=Time.get_ticks_usec()+3000000
	while overlay.capture_active and Time.get_ticks_usec()<live_deadline:
		game._process(1.0/60);await process_frame
	var live_report=JSON.parse_string(FileAccess.get_file_as_string(overlay.capture_path))
	check(live_report.rows.any(func(row):return row.main_phases.has("combat") and not row.combat_phases_us.is_empty()),"Active gameplay capture records actual main/combat timing phases")
	game.show_game();overlay.begin_capture(.1);game.show_menu()
	var deadline=Time.get_ticks_usec()+300000
	while Time.get_ticks_usec()<deadline:await process_frame
	check(not overlay.capture_active and game.performance_profile_enabled==profile_before and game.combat.profile_enabled==combat_before,"Leaving gameplay during capture still releases profiling after the deadline")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame
	var result={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/runtime-performance-capture-test.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result));quit(0 if result.passed else 1)
