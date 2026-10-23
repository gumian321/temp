extends SceneTree
## Fixed 80-monster excavation fixture. Measure the bite/drop frames themselves,
## including native rendering, rather than timing only the finished tunnel.
var game
var rows: Array = []
var report_directory="res://artifacts"
class SilentAudio extends "res://scripts/audio_system.gd":
	func play_event(_event: Dictionary): pass
class HiddenWeaponFX extends "res://scripts/weapon_fx.gd":
	func paint_projectile(_canvas,_bullet:Dictionary,_time:float,_zoom:float):pass
	func paint(_canvas,_battle,_time:float,_zoom:float):pass

class MeasuredGame extends "res://scripts/main.gd":
	var draw_ms = 0.0
	func _draw():
		var started = Time.get_ticks_usec()
		super._draw()
		draw_ms = float(Time.get_ticks_usec() - started) / 1000.0

class MeasuredWorld extends "res://scripts/cave_world.gd":
	var times: Dictionary = {}
	var in_move=false
	var collision_profile=OS.get_environment("RBPEW_COLLISION_PROFILE")=="1"
	var placements:Array=[]
	func safe_position(at:Vector2,radius:float)->Vector2:
		var started=Time.get_ticks_usec()
		var result=super.safe_position(at,radius)
		var ms=float(Time.get_ticks_usec()-started)/1000.0
		if ms>2:placements.append({"ms":ms,"radius":radius,"point":at,"result":result,"stack":get_stack()})
		return result
	func add_time(key: String, started: int): times[key] = float(times.get(key, 0)) + float(Time.get_ticks_usec() - started) / 1000.0
	func dig(point: Vector2, intent: Vector2, facing: Vector2, radius: float, dt: float, strong: bool = false):
		var started = Time.get_ticks_usec()
		super.dig(point, intent, facing, radius, dt, strong)
		add_time("dig_ms", started)
	func invalidate_navigation(point: Vector2, reach: float):
		var started = Time.get_ticks_usec()
		super.invalidate_navigation(point, reach)
		add_time("nav_invalidate_ms", started)
	func navigation(target: Vector2, radius: float) -> Dictionary:
		var started = Time.get_ticks_usec()
		var data = super.navigation(target, radius)
		add_time("nav_grid_ms", started)
		return data
	func direction(origin: Vector2, target: Vector2, radius: float, memory: Dictionary) -> Vector2:
		var started = Time.get_ticks_usec()
		var result = super.direction(origin, target, radius, memory)
		add_time("directions_ms", started)
		return result
	func move(start: Vector2, desired: Vector2, radius: float) -> Vector2:
		var started = Time.get_ticks_usec()
		in_move=true
		var result = super.move(start, desired, radius)
		in_move=false
		add_time("movement_ms", started)
		return result
	func wall_blocked(at:Vector2,radius:float=0.0)->bool:
		var started=Time.get_ticks_usec()
		var result=super.wall_blocked(at,radius)
		if in_move and collision_profile:
			add_time("move_overlap_ms",started);times.move_overlap_calls=int(times.get("move_overlap_calls",0))+1
		return result
	func wall_hit(start:Vector2,finish:Vector2,radius:float=0.0)->Dictionary:
		var began=Time.get_ticks_usec()
		var result=super.wall_hit(start,finish,radius)
		if in_move and collision_profile:
			add_time("move_sweep_ms",began);times.move_sweep_calls=int(times.get("move_sweep_calls",0))+1
		return result
	func safe_among(at:Vector2,radius:float,shapes:Array)->Vector2:
		var started=Time.get_ticks_usec()
		var result=super.safe_among(at,radius,shapes)
		if in_move and collision_profile and not shapes.is_empty():
			add_time("move_recovery_ms",started);times.move_recovery_calls=int(times.get("move_recovery_calls",0))+1
		return result

class MeasuredTerrain extends "res://scripts/cave_terrain.gd":
	var render_hidden = false
	var build_ms = 0.0
	var builds = 0
	var ore_ms = 0.0
	var weathering_ms = 0.0
	var build_details: Array = []
	func sync():
		super.sync()
		if render_hidden: visible = false
	func build_chunk(id: Vector2i, data: Dictionary) -> Dictionary:
		var started = Time.get_ticks_usec()
		var previous_ore = ore_ms; var previous_weathering = weathering_ms
		var cold = not meshes.has(id)
		var result = super.build_chunk(id, data)
		var elapsed = float(Time.get_ticks_usec() - started) / 1000.0
		build_ms += elapsed
		build_details.append({"chunk": id, "cold": cold, "ms": elapsed, "ore_ms": ore_ms - previous_ore, "weathering_ms": weathering_ms - previous_weathering})
		builds += 1
		return result
	func build_ore(cell: Vector2i, pieces: Array, kind: int, buffer: Dictionary):
		var started = Time.get_ticks_usec()
		super.build_ore(cell, pieces, kind, buffer)
		ore_ms += float(Time.get_ticks_usec() - started) / 1000.0
	func build_weathering(edges: PackedVector2Array) -> Dictionary:
		var started = Time.get_ticks_usec()
		var result = super.build_weathering(edges)
		weathering_ms += float(Time.get_ticks_usec() - started) / 1000.0
		return result

func _initialize(): call_deferred("execute")

func statistics(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	return {"median": values[values.size() / 2], "p95": values[mini(values.size() - 1, floori(values.size() * 0.95))], "max": values.back()}

func execute():
	root.size = Vector2i(1440, 900)
	set_meta("performance_fixture",true)
	if not OS.get_environment("RBPEW_PERF_REPORT_DIR").is_empty():report_directory=OS.get_environment("RBPEW_PERF_REPORT_DIR").replace("\\","/")
	var actor_count=80 if OS.get_environment("RBPEW_MINING_ACTORS").is_empty() else clampi(OS.get_environment("RBPEW_MINING_ACTORS").to_int(),0,120)
	var frame_count=240 if OS.get_environment("RBPEW_MINING_FRAMES").is_empty() else clampi(OS.get_environment("RBPEW_MINING_FRAMES").to_int(),240,2400)
	var live_map=OS.get_environment("RBPEW_MINING_LIVE_MAP")=="1"
	var mission_name=OS.get_environment("RBPEW_MINING_MISSION")
	if mission_name.is_empty():mission_name="Survival Mission"
	var route=OS.get_environment("RBPEW_MINING_ROUTE")
	game = MeasuredGame.new(); root.add_child(game); await process_frame
	game.set_process(false); game.test_mode = false; game.save.fresh()
	if OS.get_environment("RBPEW_PROFILE_HIDE_WEAPONS")=="1":game.weapon_fx=HiddenWeaponFX.new()
	if OS.get_environment("RBPEW_PROFILE_SILENT")=="1":
		game.audio_system.shutdown();game.audio_system.queue_free()
		game.audio_system=SilentAudio.new();game.add_child(game.audio_system);game.audio_system.setup(game.db,game.save);game.music=game.audio_system.music
	var world = MeasuredWorld.new()
	game.charcoal_terrain.world = world
	game.cave_terrain.queue_free()
	game.cave_terrain = MeasuredTerrain.new(); game.add_child(game.cave_terrain); game.cave_terrain.setup(game)
	await process_frame
	game.selected_mission = game.db.named(mission_name); game.begin_run()
	while game.deployment_active: await process_frame
	game.set_process(false)
	game.combat.rng.seed = 20261021
	game.combat.enemies.clear(); game.combat.drones.clear(); game.combat.enemy_drones.clear(); game.combat.loot.clear(); game.combat.effects.clear()
	game.run.timers = {"swarm": 9999.0, "wave": 9999.0, "patrol": 9999.0}; game.run.encounters.enabled = false
	var entry = world.wall_hit(Vector2.ZERO, Vector2(1000, 0), 30)
	game.player.head = Vector2(entry.position) + Vector2(entry.normal) * 0.35
	game.player.facing = Vector2.RIGHT
	for i in game.player.history.size(): game.player.history[i] = game.player.head - Vector2(i * 4, 0)
	for i in 6: game.player.append_segment(game.db.named("Core_Gun_Gatling").id)
	game.player.motion.reset(); game.player.refresh_positions()
	for part in game.player.parts:part.hp=100000;part.max_hp=100000
	for i in actor_count:
		var e = game.combat.spawn(game.db.pool["250"], Vector2(630 + (i % 10) * 15, (i / 10) * 17 - 60))
		e.guns = []; e.components = []; e.warp = 0; e.stop_distance = 0; e.hp = 100000; e.max_hp = 100000
	game.tutorials.movement_shown = true; game.tutorials.radar_shown = true; game.tutorials.fuel_shown = true
	game.show_game()
	# Warm native materials and the enemy clearance grid before measurements.
	var warmup_times: Array = []
	var warmup_phases: Array = []
	for i in 12:
		game.performance_samples.clear(); world.times.clear()
		var warmup_started = Time.get_ticks_usec()
		game._process(1.0 / 60); game.run.rewards.queue.clear(); game.run.packs = 0
		warmup_times.append(float(Time.get_ticks_usec() - warmup_started) / 1000.0)
		warmup_phases.append({"main": game.performance_samples.duplicate(true), "world": world.times.duplicate()})
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	game.combat.profile_enabled = true
	Input.action_press("move_right")
	var turned=false
	for frame in frame_count:
		if game.screen=="pause":game.show_game()
		game.camera_focus.clear()
		var old_elapsed=game.run.elapsed
		if route=="excavate" and not turned and frame>=150 and game.player.head.x>412:
			Input.action_release("move_right");Input.action_press("move_up");turned=true
		world.times.clear(); game.combat.phase_times.clear(); game.performance_samples.clear()
		world.placements.clear()
		game.cave_terrain.build_ms = 0; game.cave_terrain.builds = 0
		game.cave_terrain.ore_ms = 0; game.cave_terrain.weathering_ms = 0
		game.cave_terrain.build_details.clear()
		var old_bites = world.bite_serial; var old_ore = world.ore_total; var old_removed = world.removed_count
		var started = Time.get_ticks_usec()
		game._process(1.0 / 60)
		var simulation_ms = float(Time.get_ticks_usec() - started) / 1000.0
		var sync_started = Time.get_ticks_usec()
		game.cave_terrain.sync()
		var sync_ms = float(Time.get_ticks_usec() - sync_started) / 1000.0
		var row = {"frame": frame, "simulation_ms": simulation_ms, "terrain_sync_ms": sync_ms, "cpu_ms": simulation_ms + sync_ms,
			"bite": world.bite_serial > old_bites, "ore": world.ore_total - old_ore, "removed": world.removed_count - old_removed,
			"world": world.times.duplicate(), "terrain_build_ms": game.cave_terrain.build_ms, "terrain_builds": game.cave_terrain.builds,
			"terrain_ore_ms": game.cave_terrain.ore_ms, "terrain_weathering_ms": game.cave_terrain.weathering_ms,
			"terrain_build_details": game.cave_terrain.build_details.duplicate(true),
			"combat_us": game.combat.phase_times.duplicate(), "actors": game.combat.enemies.size(), "bullets": game.combat.bullets.size(),
			"nav_replans": world.nav_replans, "main_phases": game.performance_samples.duplicate(true)}
		game.run.rewards.queue.clear(); game.run.packs = 0
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		row.frame_ms = float(Time.get_ticks_usec() - started) / 1000.0
		row.main_draw_ms = game.draw_ms
		row.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		row.drawn_objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		row.primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		row.terrain_build_ms=game.cave_terrain.build_ms;row.terrain_builds=game.cave_terrain.builds
		row.terrain_build_details=game.cave_terrain.build_details.duplicate(true)
		row.placements=world.placements.duplicate(true)
		row.head=[game.player.head.x,game.player.head.y]
		var control_direction=game.controls.movement(true)
		row.move_direction=[control_direction.x,control_direction.y]
		row.screen=game.screen;row.simulated=game.run.elapsed>old_elapsed;row.run_elapsed=game.run.elapsed
		rows.append(row)
	Input.action_release("move_right")
	Input.action_release("move_up")
	var counter = game.performance_overlay
	var counter_reading = {"fps": counter.current_fps, "average_ms": counter.average_ms, "peak_ms": counter.peak_ms, "text": counter.reading.text, "peak_text": counter.peak_reading.text, "visible": counter.display.is_visible_in_tree()}
	var counter_capture = ""
	if DisplayServer.get_name() != "headless":
		counter_capture = report_directory+"/cave-performance-fps.png"
		root.get_texture().get_image().save_png(counter_capture)
	var all_times: Array = []; var bite_times: Array = []; var drop_times: Array = []; var frame_times: Array = []
	var bite_frames: Array = []; var drop_frames: Array = []
	for row in rows:
		all_times.append(row.cpu_ms); frame_times.append(row.frame_ms)
		if row.bite: bite_times.append(row.cpu_ms); bite_frames.append(row.frame_ms)
		if row.ore > 0: drop_times.append(row.cpu_ms); drop_frames.append(row.frame_ms)
	var ranked = rows.duplicate(); ranked.sort_custom(func(a, b): return a.cpu_ms > b.cpu_ms)
	var rendering_ab: Dictionary = {}
	if DisplayServer.get_name() != "headless":
		# Freeze this exact battle and change rendering only: mining/collision and
		# enemy counts stay identical while counting the rock layer's contribution.
		for hidden in [false, true]:
			game.cave_terrain.render_hidden = hidden
			var calls: Array = []; var primitives: Array = []; var frames: Array = []
			for frame in 40:
				var started = Time.get_ticks_usec()
				game.queue_redraw()
				await process_frame; await RenderingServer.frame_post_draw
				if frame < 10: continue
				calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
				frames.append(float(Time.get_ticks_usec() - started) / 1000.0)
			rendering_ab["rock_hidden" if hidden else "rock_visible"] = {"draw_calls": statistics(calls), "primitives": statistics(primitives), "frame_ms": statistics(frames)}
		game.cave_terrain.render_hidden = false
	var stroke_captures:Array=[]
	if DisplayServer.get_name()!="headless" and OS.get_environment("RBPEW_STROKE_COMPARE")=="1":
		var terrain=game.cave_terrain
		terrain.reparent(root);game.hide()
		for layer in game.find_children("*","CanvasLayer",true,false):layer.hide()
		terrain.visible=true;terrain.hints.hide()
		for zoom in [1.0,1.75,.65]:
			terrain.position=root.size*.5-game.camera*zoom;terrain.scale=Vector2.ONE*zoom
			for use_mesh in [false,true]:
				terrain.use_stroke_meshes=use_mesh;terrain.queue_redraw();terrain.details.queue_redraw()
				await process_frame;await RenderingServer.frame_post_draw
				await process_frame;await RenderingServer.frame_post_draw
				var capture="res://artifacts/cave-strokes-%s-%s.png"%[str(zoom),"mesh" if use_mesh else "native"]
				root.get_texture().get_image().save_png(capture);stroke_captures.append(capture)
		terrain.queue_free()
	var report = {"passed": world.ore_total > 0 and world.removed_count > 0 and rows.all(func(row): return row.screen=="game" and row.simulated and (row.actors >= actor_count if live_map else row.actors == actor_count) and row.nav_replans <= MeasuredWorld.NAV_REPLANS_PER_FRAME and (not row.bite or row.removed > 0 or row.terrain_build_details.all(func(item):return item.cold))),
		"conditions": "1440x900 native OpenGL; six Gatling modules; %d fixed seeded, non-shooting monsters across the shortcut; production _process, drops, weapons, audio and rendering; reward-choice interruptions suppressed; 12 warmup + %d measured frames at 1/60s input."%[actor_count,frame_count],
		"cpu_ms": statistics(all_times), "bite_cpu_ms": statistics(bite_times), "drop_cpu_ms": statistics(drop_times), "frame_ms": statistics(frame_times),
		"bite_frame_ms": statistics(bite_frames), "drop_frame_ms": statistics(drop_frames), "warmup_simulation_ms": warmup_times,
		"frame_rate_counter": counter_reading, "counter_capture": counter_capture,
		"rendering_ab": rendering_ab,
		"stroke_captures":stroke_captures,
		"live_map_spawns":live_map,"runtime":OS.get_executable_path(),"embedded_export":OS.has_feature("standalone"),
		"mission":mission_name,"route":route,
		"diagnostic_audio_disabled":OS.get_environment("RBPEW_PROFILE_SILENT")=="1",
		"diagnostic_weapon_fx_hidden":OS.get_environment("RBPEW_PROFILE_HIDE_WEAPONS")=="1",
		"diagnostic_collision_profile":OS.get_environment("RBPEW_COLLISION_PROFILE")=="1",
		"warmup_phases": warmup_phases,
		"mined_cells": world.removed_count, "ore_value": world.ore_total, "worst_frames": ranked.slice(0, 12), "frames": rows}
	var tag = OS.get_environment("RBPEW_MINING_PERF_TAG")
	if tag.is_empty(): tag = "latest"
	var path = report_directory+"/cave-mining-performance-" + tag + ".json"
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify({"passed": report.passed, "report": path, "cpu_ms": report.cpu_ms, "bite_cpu_ms": report.bite_cpu_ms, "drop_cpu_ms": report.drop_cpu_ms, "worst": ranked[0]}))
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.queue_free()
	await process_frame; await process_frame
	quit(0 if report.passed else 1)
