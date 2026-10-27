extends SceneTree
const Writer=preload("res://scripts/runtime_log_writer.gd")
var checks=[]
func _initialize():call_deferred("execute")
func check(value:bool,message:String):
	checks.append({"name":message,"passed":value})
	if not value:push_error(message)
func records(path:String)->Array:
	var result=[];var directory=DirAccess.open(path)
	if directory==null:return result
	var files=directory.get_files();files.sort()
	var valid=true
	for filename in files:
		if not filename.ends_with(".jsonl"):continue
		var file=FileAccess.open(path.path_join(filename),FileAccess.READ)
		while not file.eof_reached():
			var line=file.get_line()
			if line.is_empty():continue
			var row=JSON.parse_string(line)
			valid=valid and row is Dictionary
			if row is Dictionary:result.append(row)
	check(valid,"Every flushed JSONL line is independently readable")
	return result
func execute():
	OS.set_environment("RBPEW_RUNTIME_LOG","1");set_meta("performance_fixture",true);root.size=Vector2i(1440,900)
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	game.test_mode=false;game.save.fresh();game.start_run()
	var trace=game.runtime_log
	check(trace.enabled,"Normal diagnostics can explicitly run inside an isolated test profile")
	var save_before=game.save.state.duplicate(true);var rng_before=game.combat.rng.state
	game.performance_profile_enabled=true;game.combat.profile_enabled=true
	var now=1000000
	# Thirty-one simulated minutes test the logger's elapsed-time, retention and
	# pause handling. This is not a claim of a thirty-minute gameplay benchmark.
	for second in 1860:
		for frame in 20:
			trace.begin_tick(game,now);game.run.elapsed+=.05
			if trace.sampling:
				trace.record_main("combat",12000);game.combat.diagnostic_times["projectiles"]=5000
			trace.end_tick(game,18000);now+=50000
		if second==900:
			game.show_pause()
			for frame in 200:trace.begin_tick(game,now);trace.end_tick(game,100);now+=50000
			game.show_game();trace.mark(game,"synthetic_long_run_marker")
		await process_frame
	var long_path=trace.session_path;trace.finish_session("test_complete")
	var rows=records(long_path);var summaries=rows.filter(func(r):return r.type=="summary")
	var details=rows.filter(func(r):return r.type=="detail")
	check(not summaries.is_empty() and float(summaries[-1].run_elapsed)>1800,"Periodic logs preserve the end of a run beyond thirty minutes")
	check(summaries.all(func(r):return float(r.frame_ms.max)<51 and absf(float(r.frame_ms.mean)-50)<.1),"Pause time never becomes a false combat slow frame")
	check(details.any(func(r):return r.main_us.has("combat") and r.combat_us.has("projectiles")),"Independent main/draw/combat timing channels survive long logging")
	check(rows.any(func(r):return r.type=="slow_trigger") and rows.any(func(r):return r.type=="marker"),"Sustained thirty-FPS drops and player markers both leave diagnostic events")
	check(rows.any(func(r):return r.type=="header" and r.synthetic_clock),"Synthetic-clock validation cannot be mistaken for real gameplay FPS")
	check(game.performance_profile_enabled and game.combat.profile_enabled and not game.combat.diagnostic_profile,"Automatic logging never steals or disables the separate F3 profiler flags")
	check(game.save.state==save_before and game.combat.rng.state==rng_before,"Logging alone leaves save progression and combat RNG unchanged")
	check(trace.frame_times.is_empty() and trace.cpu_times.is_empty(),"Per-second frame buffers release rather than growing with run duration")
	game.performance_profile_enabled=false;game.combat.profile_enabled=false
	# Brief real native scene integration verifies normal process/draw timing;
	# it is separate from the synthetic elapsed-time test above.
	game.start_run();game.reward_snoozed=true;game.reward_snooze_count=2147483647
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	var deadline=Time.get_ticks_usec()+2500000
	while Time.get_ticks_usec()<deadline:
		game._process(game.get_process_delta_time());await process_frame;await RenderingServer.frame_post_draw
	var live_path=trace.session_path;trace.finish_session("live_test_complete")
	var live=records(live_path)
	var logged_frames=0;var logged_us=0.0;var logged_draws=0.0;var logged_draw_frames=0
	for row in live:
		if row.type!="summary":continue
		logged_frames+=int(row.frames);logged_us+=float(row.frames)*float(row.frame_ms.mean)*1000.0
		if row.get("draw_calls") is Dictionary:
			logged_draw_frames+=int(row.draw_calls.frames);logged_draws+=float(row.draw_calls.mean)*int(row.draw_calls.frames)
	var closed=live.filter(func(row):return row.type=="session_end")
	var totals=closed[-1].active_totals if not closed.is_empty() else {}
	check(not totals.is_empty() and totals.frames==logged_frames and totals.microseconds==roundi(logged_us) and logged_draw_frames==logged_frames and absf(totals.draw_calls_mean-logged_draws/maxi(1,logged_draw_frames))<.000001,"Cumulative real-clock FPS and DC exactly cover periodic plus final partial frames")
	var example=FileAccess.open("res://artifacts/runtime-log-example-20261026.jsonl",FileAccess.WRITE)
	example.store_string(FileAccess.get_file_as_string(live_path.path_join("part-001.jsonl")));example.close()
	check(live.any(func(r):return r.type=="detail" and r.main_us.has("combat") and r.main_us.has("draw_terrain") and not r.combat_us.is_empty()),"Real main-scene process and drawing produce aligned detail phases")
	check(live.any(func(r):return r.type=="summary" and r.has("counts") and r.counts.has("nav_grids") and r.counts.has("nodes")),"Real summaries contain late-game terrain/cache growth, node and render pressure")
	check(live.any(func(r):return r.type=="header" and str(r.sources.main.sha256).length()==64),"Header fingerprints identify the actual source build")
	await verify_retention()
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame
	var result={"passed":checks.all(func(c):return c.passed),"checks":checks,"synthetic_elapsed_seconds":1860,"long_run_rows":rows.size(),"live_rows":live.size(),"method":"31-minute synthetic-clock persistence test plus 2.5-second real native main-scene integration; not a thirty-minute gameplay test."}
	FileAccess.open("res://artifacts/runtime-log-validation-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify({"passed":result.passed,"checks":checks.size(),"synthetic_rows":rows.size(),"live_rows":live.size()}))
	quit(0 if result.passed else 1)
func verify_retention():
	var base=ProjectSettings.globalize_path("user://writer-retention")
	DirAccess.make_dir_recursive_absolute(base.path_join("run-player-notes"))
	var note=FileAccess.open(base.path_join("run-player-notes/important.txt"),FileAccess.WRITE);note.store_string("keep");note.close()
	for session in 5:
		var writer=Writer.new();writer.max_part_bytes=512;writer.keep_parts=2;writer.keep_sessions=2
		writer.start(base,"run-%03d"%session,{"type":"header","owner":Writer.OWNER,"schema":1})
		for row in 30:writer.push({"type":"sample","index":row,"text":"012345678901234567890123456789012345678901234567890123456789"})
		writer.close();check(writer.status().dropped_lines==0 and writer.status().error.is_empty(),"Background writer closes and flushes without dropping queued records")
		await process_frame
	var owned=0;var bounded=true
	for folder in DirAccess.open(base).get_directories():
		if not FileAccess.file_exists(base.path_join(folder).path_join("session.json")):continue
		owned+=1
		var files=DirAccess.open(base.path_join(folder)).get_files();var parts=0
		for filename in files:
			if filename.ends_with(".jsonl"):parts+=1
		bounded=bounded and parts<=2
	check(owned==2 and bounded,"Only configured recent sessions and parts remain after repeated log rotation")
	check(FileAccess.get_file_as_string(base.path_join("run-player-notes/important.txt"))=="keep","Retention never recursively deletes player-owned files or directories")
