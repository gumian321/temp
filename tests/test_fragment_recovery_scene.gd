extends "res://tests/test_centipede_scene.gd"
## Actual main-scene playback and bounded native render fixture. No production saves.
## FRAGMENT_RECOVERY_FRAMES=1 records 30 fps PNGs for the native preview.
var clip_frames = 0
var simulation_frames = 0
var max_fragment_step = 0.0
var max_attach_step = 0.0
var dormant_unchanged = true
var premature_ownership = false
var sequential_wake_seen = false
var timeline: Array = []
var dense_stats: Dictionary = {}
var dense_render_ms: Array = []
var title_label: Label
var detail_label: Label
var fixed_camera = Vector2(140, 0)
var original_rear: Array = []
var preserved_state: Array = []
var frozen_poses: Array = []
var previous_state = "intact"
var recording = false
var wake_trigger_distance = INF
var wake_trigger_age = 0.0

func stage(title: String, detail: String):
	title_label.text = title
	detail_label.text = detail

func set_direction(direction: Vector2):
	for action in ["move_right", "move_up", "move_left", "move_down"]: Input.action_release(action)
	if direction.x > 0.01: Input.action_press("move_right", direction.x)
	if direction.x < -0.01: Input.action_press("move_left", -direction.x)
	if direction.y > 0.01: Input.action_press("move_down", direction.y)
	if direction.y < -0.01: Input.action_press("move_up", -direction.y)

func pose_map() -> Dictionary:
	var result = {}
	for group in game.player.detached_fragments:
		for index in group.parts.size(): result[int(group.parts[index].feedback_uid)] = Vector2(group.poses[index].point)
	return result

func advance(direction: Vector2, frames: int, record: bool = true):
	for frame in frames:
		var before = pose_map()
		set_direction(direction)
		game._process(1.0 / 60.0)
		game.camera = fixed_camera
		game.camera_recoil = Vector2.ZERO; game.camera_kick = Vector2.ZERO
		game.sync_camera_layers(); game.queue_redraw()
		var after = pose_map()
		for uid in before:
			if after.has(uid): max_fragment_step = maxf(max_fragment_step, Vector2(before[uid]).distance_to(after[uid]))
			else:
				for part in game.player.parts:
					if int(part.feedback_uid) == uid: max_attach_step = maxf(max_attach_step, Vector2(before[uid]).distance_to(part.position))
		var state = "reattached" if game.player.detached_fragments.is_empty() and not original_rear.is_empty() else "intact"
		if not game.player.detached_fragments.is_empty():
			var group = game.player.detached_fragments[0]
			state = str(group.state)
			if state == "dormant": dormant_unchanged = dormant_unchanged and group.poses == frozen_poses
			if state == "waking":
				for part in group.parts:
					if game.player.parts.has(part): premature_ownership = true
				if group.poses.size() > 1 and float(group.poses[0].activation) > float(group.poses[-1].activation) + 0.1: sequential_wake_seen = true
		if state != previous_state:
			if state == "waking":
				wake_trigger_age = float(game.player.detached_fragments[0].age)
				for pose in frozen_poses: wake_trigger_distance = minf(wake_trigger_distance, game.player.head.distance_to(pose.point))
			timeline.append({"frame": simulation_frames, "seconds": simulation_frames / 60.0, "state": state, "connected": game.player.parts.size() - 1, "detached": game.player.detached_module_count()})
			previous_state = state
		simulation_frames += 1
		if record and simulation_frames % 2 == 0: await record_frame()

func record_frame():
	if not recording: return
	await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	if picture == null or picture.is_empty():
		printerr("ERROR: Native fragment preview did not produce a frame")
		return
	var path = "res://artifacts/fragment-recovery-frames/frame-%04d.png" % clip_frames
	if picture.save_png(path) != OK: printerr("ERROR: Could not save fragment preview frame ", clip_frames)
	clip_frames += 1

func dense_fixture():
	game.player.reset(); game.combat.enemies.clear(); game.combat.effects.clear(); game.combat.bullets.clear()
	var gun = game.db.named("Core_Gun_Gatling").id
	for index in 60: game.player.append_segment(gun)
	game.combat.hurt_player(game.player.part_at(10), 100000, 100000)
	game.combat.step(0.0, game.player.head + Vector2.RIGHT * 1000, false)
	check(game.player.detached_module_count() == 50 and game.player.segment_count() == 9, "Dense scene contains exactly 50 dormant modules and 9 connected modules")
	check(game.player.append_segment(gun) and not game.player.append_segment(gun), "Live scene respects 60 modules including the 50 detached modules")
	game.zoom = 0.33; game.camera = Vector2(-1900, 0)
	stage("密集残段 · 50 节静止保留", "原生渲染压力检查 · 材质与批次数量固定")
	game.queue_redraw(); await process_frame; await process_frame
	game.fragment_art.paint(game)
	dense_stats = game.fragment_art.stats()
	check(int(dense_stats.visible_parts) == 50, "All 50 dormant modules are inside the actual render viewport")
	check(int(dense_stats.materials) <= 14 and int(dense_stats.batches) <= 15, "Fragment renderer uses a fixed budget of 14 materials and 15 batches")
	if DisplayServer.get_name() != "headless":
		for frame in 30:
			var started = Time.get_ticks_usec()
			game.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
			dense_render_ms.append((Time.get_ticks_usec() - started) / 1000.0)
		dense_stats = game.fragment_art.stats()
		check(int(dense_stats.meshes) <= 50, "Dense dormant mesh cache remains bounded to the 50 visible modules")
		await capture("fragment-recovery-06-fifty-dormant")
	game.player.reset(); game.fragment_art.paint(game)
	await process_frame; await process_frame
	check(int(game.fragment_art.stats().visible_parts) == 0 and int(game.fragment_art.stats().meshes) == 0, "Reset clears all dormant visibility and cached fragment meshes")

func execute():
	root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_process(false); game.test_mode = false
	game.save.state.settings.skip_boss = true
	game.save.select_character("centipede"); game.start_run(); game.set_process(false)
	game.combat.enemies.clear(); game.combat.drones.clear()
	game.run.timers = {"swarm": 999.0, "wave": 999.0, "patrol": 999.0}
	game.run.encounters.enabled = false; game.run.rewards.queue.clear(); game.run.packs = 0
	game.tutorials.movement_shown = true; game.tutorials.radar_shown = true; game.tutorials.fuel_shown = true
	var modules = ["Core_Gun_Gatling", "Core_Gun_Cannon", "Core_Gun_Tesla", "Core_Gun_Shotgun", "Core_Gun_EMP", "Core_Gun_Flame Thrower", "Core_Gun_Cannon", "Core_Gun_Tesla", "Core_Gun_Gatling"]
	for module in modules: game.player.append_segment(game.db.named(module).id)
	game.player.parts[7].hp *= 0.43
	game.show_game(); game.zoom = 1.15
	title_label = game.label_at("", Vector2(64, 146), 26, Color("254b5c"))
	detail_label = game.label_at("", Vector2(64, 184), 18, Color("557079"))
	title_label.set_meta("game_ui", true); detail_label.set_meta("game_ui", true)
	title_label.add_theme_color_override("font_color", Color("254b5c"))
	detail_label.add_theme_color_override("font_color", Color("557079"))
	recording = OS.get_environment("FRAGMENT_RECOVERY_FRAMES") == "1" and DisplayServer.get_name() != "headless"
	if recording: DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/fragment-recovery-frames"))
	stage("断链回收 · 原生实机演示", "完整武装前进 → 中段击毁 → 残段苏醒归队")
	await advance(Vector2.RIGHT, 60, false)
	await advance(Vector2.RIGHT, 60)
	await capture("fragment-recovery-00-intact")
	for index in range(5, 10): original_rear.append(game.player.parts[game.player.part_at(index)])
	for part in original_rear: preserved_state.append({"uid": part.feedback_uid, "id": part.id, "hp": part.hp, "fusion": part.fusion_level})
	game.combat.hurt_player(game.player.part_at(4), 100000, 100000)
	game.combat.step(0.0, game.player.head + Vector2.RIGHT * 1000, false)
	check(game.player.segment_count() == 3 and game.player.detached_module_count() == 5, "Actual combat destruction leaves 3 front modules and 5 living rear modules")
	if game.player.detached_fragments.is_empty():
		printerr("ERROR: Actual combat did not produce a fragment"); quit(1); return
	frozen_poses = game.player.detached_fragments[0].poses.duplicate(true)
	stage("中段断裂 · 后方 5 节留在原地", "前方继续移动；残段停止攻击，不再跟随")
	await advance(Vector2.RIGHT, 90)
	check(game.player.detached_fragments[0].state == "dormant" and float(game.player.detached_fragments[0].age) >= 1.0, "After the one-second pickup delay, distant fragments remain dormant")
	await capture("fragment-recovery-01-dormant")
	await advance(Vector2.ZERO, 30)
	var return_point: Vector2 = game.player.detached_fragments[0].poses[0].point
	stage("折返靠近 · 回到残段身边", "头部进入 96 像素范围后，生命活动逐节恢复")
	for frame in 420:
		if game.player.detached_fragments.is_empty() or game.player.detached_fragments[0].state == "waking": break
		await advance(game.player.head.direction_to(return_point), 1)
	check(not game.player.detached_fragments.is_empty() and game.player.detached_fragments[0].state == "waking", "Returning through native movement wakes the fragment within pickup radius")
	check(wake_trigger_distance <= 96.0 and wake_trigger_age >= 1.0, "Native wake begins only within 96 pixels and after the one-second safety delay")
	await capture("fragment-recovery-02-wake-start")
	stage("生命回流 · 逐节苏醒，缓缓接回", "保留原武器与受损生命值；移动完成后才重新加入队伍")
	await advance(Vector2.ZERO, 14)
	await capture("fragment-recovery-03-sequential-wake")
	for frame in 600:
		if game.player.detached_fragments.is_empty(): break
		await advance(Vector2.ZERO, 1)
	check(game.player.detached_fragments.is_empty() and game.player.segment_count() == 8, "All 5 living rear modules physically converge and rejoin, with the destroyed module absent")
	check(dormant_unchanged, "Dormant fragment poses remain exactly frozen while the front leaves and returns")
	check(sequential_wake_seen, "Front and rear activation differ during the sequential wake wave")
	check(not premature_ownership, "Detached modules do not enter player.parts before physical convergence")
	check(max_fragment_step <= 12.001, "Every detached center moves at most 12 pixels per 60 Hz simulation step")
	check(max_attach_step < 4.0, "Final attachment has less than 4 pixels of single-frame center displacement")
	for index in original_rear.size():
		var part = original_rear[index]
		var saved = preserved_state[index]
		check(game.player.parts.any(func(entry): return is_same(entry, part)) and part.feedback_uid == saved.uid and part.id == saved.id and is_equal_approx(part.hp, saved.hp) and part.fusion_level == saved.fusion, "Recovered module %d retains its dictionary identity, weapon, fusion level and damage" % (index + 1))
	await capture("fragment-recovery-04-reattached")
	stage("重新同行 · 原有武装完整保留", "5 节残段已归队；被击毁的 1 节不会复活")
	await advance(Vector2.LEFT, 90)
	await capture("fragment-recovery-05-moving-together")
	set_direction(Vector2.ZERO)
	await dense_fixture()
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(0.25).timeout
	game.queue_free(); await process_frame; await process_frame
	dense_render_ms.sort()
	var report = {"checks": checks, "captures": captures, "passed": checks.all(func(c): return c.passed), "timeline": timeline, "wake_trigger_distance_px": wake_trigger_distance, "wake_trigger_age_seconds": wake_trigger_age, "max_fragment_step_px": max_fragment_step, "max_attach_step_px": max_attach_step, "clip_frames": clip_frames, "clip_fps": 30, "dense_stats": dense_stats, "dense_frame_median_ms": dense_render_ms[dense_render_ms.size() / 2] if not dense_render_ms.is_empty() else null, "dense_frame_max_ms": dense_render_ms.back() if not dense_render_ms.is_empty() else null, "renderer": DisplayServer.get_name(), "scope": "Actual main scene and combat path; staged loadout, clear arena and fixed camera for readable recovery."}
	FileAccess.open("res://artifacts/fragment-recovery-scene-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
