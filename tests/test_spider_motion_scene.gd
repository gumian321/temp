extends "res://tests/test_centipede_scene.gd"
## Native main-scene fixture. Run tools/run_checks.py spider_motion_scene --render.
var planted_samples = 0
var stepping_samples = 0
var synchronization_ok = true
var stance_ok = true
func advance(direction: Vector2, frames: int):
	for frame in frames:
		var before = game.player.spider_rig.legs.duplicate(true)
		game.player.step(1.0 / 60, direction, false)
		for leg_index in 8:
			var leg = game.player.spider_rig.legs[leg_index]
			if leg.stepping: stepping_samples += 1
			elif not before[leg_index].stepping:
				planted_samples += 1
				stance_ok = stance_ok and leg.foot == before[leg_index].foot
		for index in range(1, game.player.parts.size()):
			var part = game.player.parts[index]
			var pose = game.player.spider_rig.mount_pose(part.segment)
			synchronization_ok = synchronization_ok and part.position.distance_to(pose.point) < 0.001 and game.player.weapon_origin(index).distance_to(pose.point) < 0.001
	game.camera = game.player.head
	game.battle_hud.refresh()
func record_motion_if_requested():
	if OS.get_environment("SPIDER_MOTION_FRAMES") != "1" or DisplayServer.get_name() == "headless": return
	var directory = "res://artifacts/spider-motion-video"
	DirAccess.make_dir_recursive_absolute(directory)
	game.show_game(); game.player.configure_character("spider")
	game.combat.enemies.clear(); game.combat.bullets.clear(); game.combat.effects.clear()
	var gun = game.db.named("Core_Gun_Gatling").id
	for leg in 8: game.player.install_module(gun, game.player.spider_mount(leg, 0))
	advance(Vector2.ZERO, 60)
	for frame in 90:
		if frame == 12:
			for depth in range(1, 4): game.player.install_module(gun, game.player.spider_mount(0, depth))
		if frame == 65:
			game.combat.hurt_player(game.player.part_at(9), 100000, 100000)
			game.combat.step(0.0, game.player.head + Vector2.RIGHT * 500, false)
		advance(Vector2.RIGHT if frame < 42 else Vector2.DOWN, 2)
		game._process(0.0); game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image = root.get_texture().get_image()
		check(image != null and not image.is_empty() and image.save_png(directory + "/frame%03d.png" % frame) == OK, "Motion video frame %d" % frame)
	print("SPIDER_MOTION_VIDEO_FRAMES=90 FPS=30 PATH=artifacts/spider-motion-video/frame%03d.png")

func execute():
	root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_process(false)
	game.save.state.settings.skip_boss = true
	game.save.state.roster_unlocked = ["centipede", "spider", "beetle"]
	game.save.select_character("spider"); game.begin_run(); game.set_process(false)
	game.combat.enemies.clear(); game.camera_focus.clear(); game.zoom = 2.2
	game.show_game(); await process_frame
	advance(Vector2.RIGHT, 60)
	check(game.player.parts.size() == 1 and game.player.spider_rig.legs.size() == 8 and stepping_samples > 0, "Eight empty legs walk in the actual main scene")
	await capture("spider-motion-01-bare-walking")
	var gun = game.db.named("Core_Gun_Gatling").id
	for leg in 8: game.player.install_module(gun, game.player.spider_mount(leg, 0))
	advance(Vector2.RIGHT, 90)
	await capture("spider-motion-02-eight-towers")
	for depth in range(1, 4): game.player.install_module(gun, game.player.spider_mount(0, depth))
	advance(Vector2.RIGHT, 90)
	check(is_equal_approx(game.player.spider_rig.legs[0].length, 200.0) and is_equal_approx(game.player.spider_rig.legs[1].length, 110.0), "Adding towers lengthens only the equipped leg")
	await capture("spider-motion-03-grown-leg")
	advance(Vector2.DOWN, 18)
	await capture("spider-motion-04-turning")
	advance(Vector2.DOWN, 60)
	check(planted_samples > 500 and stance_ok, "Stance feet stay fixed in world coordinates through movement and turns")
	check(synchronization_ok, "Actual tower and weapon origins stay on the animated limb path")
	var survivor = game.player.parts[game.player.part_at(25)]
	var uid = survivor.feedback_uid
	var hp = survivor.hp
	var other_mounts = game.player.spider_leg_indices(1).map(func(index): return game.player.parts[index].segment)
	game.combat.hurt_player(game.player.part_at(9), 100000, 100000)
	game.combat.step(0.01, game.player.head + Vector2.RIGHT * 500, false)
	advance(Vector2.DOWN, 90)
	check(survivor.feedback_uid == uid and survivor.hp == hp and survivor.segment == 17 and game.player.spider_leg_count(0) == 3, "Middle destruction retains outer tower identity and slides it inward on its own leg")
	check(game.player.spider_leg_indices(1).map(func(index): return game.player.parts[index].segment) == other_mounts and is_equal_approx(game.player.spider_rig.legs[0].length, 170.0), "Damage shortens the affected leg without altering neighboring leg modules")
	await capture("spider-motion-05-shortened-leg")
	# Use the actual combat firing path, not just a geometry accessor.
	var firing_index = game.player.part_at(17)
	var emitter: Vector2 = game.player.weapon_origin(firing_index)
	var target = game.combat.spawn(game.db.pool["250"], emitter + Vector2.RIGHT * 150)
	target.warp = 0.0; target.hp = 10000.0; target.max_hp = 10000.0
	target.guns = []; target.components = []; target.kind = "AISwarmingUnit"
	for part in game.player.parts: part.cooldown = 100.0
	game.player.parts[firing_index].cooldown = 0.0
	game.player.parts[firing_index].angle = 0.0
	game.player.parts[firing_index].barrel_index = 0
	game.combat.effects.clear(); game.combat.bullets.clear()
	var core = game.player.effective_core(firing_index)
	var prefab = str(game.db.asset(core.get("coreTurret", "")).get("turretsBarrels", ""))
	var refs: Array = game.db.component(prefab, "TurretBarrelsController").get("barrels", [])
	var barrel: Dictionary = {} if refs.is_empty() else game.db.prefab_transforms.get(prefab, {}).get(str(int(refs[0].fileID)), {})
	var expected_muzzle = emitter + Vector2(float(barrel.get("x", 0)), float(barrel.get("y", 0))).rotated(PI / 2) * 48 * game.player.weapon_visual_scale(firing_index)
	game.combat.step(0.0, target.position, false)
	var flashes = game.combat.effects.filter(func(effect): return effect.kind == "muzzle")
	check(flashes.size() == 1 and Vector2(flashes[0].position).distance_to(expected_muzzle) < 0.001, "Actual firing muzzle follows the damaged leg tower plus its real barrel offset")
	var hit = game.combat.player_visual_contact(firing_index, {"position": emitter, "previous": emitter + Vector2.RIGHT * 100, "velocity": Vector2.LEFT, "radius": 0.0})
	check(absf(Vector2(hit.position).distance_to(emitter) - game.player.collision_radius(firing_index)) < 0.001, "Hit contact is centered on the same animated tower socket")
	await capture("spider-motion-06-firing")
	var old_legs = game.player.spider_rig.legs.duplicate(true)
	game.show_pause()
	for frame in 30: game._process(1.0 / 60)
	check(game.player.spider_rig.legs == old_legs, "Actual pause screen freezes planted feet, gait phase, and growth")
	await capture("spider-motion-07-paused")
	game.show_game(); game.combat.enemies.clear(); game.combat.bullets.clear(); game.combat.effects.clear()
	while game.player.parts.size() < 33: game.player.append_segment(gun)
	advance(Vector2.LEFT, 120)
	check(game.player.spider_rig.legs.all(func(leg): return is_equal_approx(leg.length, 200.0)), "Maximum-load fixture extends all eight legs for 32 actual towers")
	await capture("spider-motion-08-full-32-towers")
	await record_motion_if_requested()
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.queue_free()
	await process_frame; await process_frame
	var report = {"checks": checks, "captures": captures, "planted_samples": planted_samples, "stepping_samples": stepping_samples, "passed": checks.all(func(c): return c.passed)}
	FileAccess.open("res://artifacts/spider-motion-scene-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
