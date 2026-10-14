extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
var checks: Array = []
var snapshots: Dictionary = {}
func _initialize(): call_deferred("execute")
func check(ok: bool, label: String):
	checks.append({"name": label, "passed": ok})
	if not ok: printerr("FAIL: ", label)
func positions(body) -> Array:
	return body.parts.map(func(p): return p.position)
func capture(body, label: String):
	snapshots[label] = body.parts.map(func(p): return [p.position.x, p.position.y])
func execute():
	var db = DB.new()
	var body = Body.new(db)
	var gun = str(db.named("Core_Gun_Gatling").id)
	for i in 20: body.append_segment(gun)
	# Curved, moving pre-skill body proves entry starts at real runtime poses.
	for i in 60: body.step(1.0 / 60, Vector2(1, 0.4), false)
	var battle = Battle.new(db, body)
	var initial = positions(body)
	battle.request_skill(body.head + Vector2.RIGHT * 500)
	capture(body, "entry_0_percent")
	check(positions(body) == initial, "Activation does not move any shell in its first frame")
	var maximum_frame = 0.0
	var bound_ok = true
	var dt = body.coil_rig.ENTER_DURATION / 120
	for frame in 120:
		var before = positions(body)
		body.step(dt, Vector2.ZERO, false)
		for i in body.parts.size():
			var displacement = Vector2(before[i]).distance_to(body.parts[i].position)
			maximum_frame = maxf(maximum_frame, displacement)
			bound_ok = bound_ok and displacement <= body.coil_rig.max_speed * dt + 0.001
		if frame == 29:
			capture(body, "entry_25_percent")
			check(Vector2(initial[-1]).distance_to(body.parts[-1].position) < 0.001, "Tail waits while front shells begin coiling")
		if frame == 59: capture(body, "entry_50_percent")
	capture(body, "entry_100_percent")
	check(bound_ok and maximum_frame > 1, "All entry frames move continuously within explicit speed bound")
	check(body.coil_rig.phase == "hold", "Whole chain reaches spiral at 100 percent")
	check(Vector2(body.parts[-1].position).distance_to(body.head) < 200, "Completed coil concentrates actual body and gun sockets")
	var frozen = positions(body)
	var elapsed = body.coil_rig.elapsed
	for i in 100: body.refresh_positions()
	body.step(0, Vector2.RIGHT, false)
	check(positions(body) == frozen and body.coil_rig.elapsed == elapsed, "Pause and repeated redraws cannot advance coil")
	var synced = true
	for i in range(1, body.parts.size()):
		synced = synced and body.parts[i].position == body.body_poses[int(body.parts[i].segment)].point
		synced = synced and body.weapon_origin(i).distance_to(body.parts[i].position) <= 13
	check(synced, "Collision centers and weapon origins follow animated physical poses")
	# UID identities survive loss, renumbering, and assembly reorder while coiled.
	body.parts.remove_at(3)
	var survivor = positions(body)
	body.refresh_positions()
	check(positions(body) == survivor, "Middle module loss does not teleport surviving modules")
	body.swap_piece(2, 5)
	check(positions(body) == survivor, "Assembly reorder keeps physical identities continuous")
	for i in 30: body.step(1.0 / 60, Vector2.ZERO, false)
	check(body.coil_rig.current.size() == body.parts.size() - 1, "Removed modules leave no stale transition state")
	var before_exit = positions(body)
	battle.character_abilities.finish()
	capture(body, "exit_0_percent")
	check(positions(body) == before_exit and not body.coil_active, "Buff expires without an exit teleport")
	var exit_bound = body.coil_rig.max_speed
	bound_ok = true
	for frame in 120:
		var before = positions(body)
		body.step(body.coil_rig.EXIT_DURATION / 120, Vector2.ZERO, false)
		for i in body.parts.size(): bound_ok = bound_ok and Vector2(before[i]).distance_to(body.parts[i].position) <= exit_bound * body.coil_rig.EXIT_DURATION / 120 + 0.01
		if frame == 59: capture(body, "exit_50_percent")
	capture(body, "exit_100_percent")
	check(bound_ok and not body.coil_rig.engaged(), "Release is bounded and hands physical chain back to ordinary motion")
	var released = positions(body)
	body.step(1.0 / 60, Vector2.ZERO, false)
	check(Vector2(released[-1]).distance_to(body.parts[-1].position) < 1, "First ordinary follower frame has no release snap")
	body.begin_coil(); body.step(0.1, Vector2.RIGHT, false)
	body.configure_character("spider")
	check(not body.coil_active and not body.coil_rig.engaged(), "Character changes clear old coil state safely")
	body.configure_character("centipede")
	battle = Battle.new(db, body)
	battle.request_skill(Vector2.ZERO)
	for i in 144:
		body.step(1.0 / 60, Vector2.ZERO, false)
		battle.character_abilities.update(1.0 / 60)
	battle.character_abilities.update(0.0001)
	check(not body.coil_active and battle.character_abilities.cooldown > 0, "Original 2.4 second skill duration and longer cooldown are retained")
	for count in [0, 1, 60]:
		for fps in [30, 60, 120]:
			body = Body.new(db)
			for i in count: body.append_segment(gun)
			body.begin_coil()
			var valid = true
			for frame in fps * 2:
				var previous = positions(body)
				body.step(1.0 / fps, Vector2.from_angle(frame * 0.035), false)
				for i in body.parts.size():
					valid = valid and body.parts[i].position.is_finite()
					valid = valid and Vector2(previous[i]).distance_to(body.parts[i].position) <= (body.coil_rig.max_speed + body.velocity.length()) / fps + 0.01
			body.end_coil()
			for frame in fps:
				body.step(1.0 / fps, Vector2.RIGHT, false)
				for part in body.parts: valid = valid and part.position.is_finite()
			check(valid and not body.coil_rig.engaged(), "%d-module moving entry/release remains stable at %d FPS" % [count, fps])
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "maximum_entry_frame_displacement": maximum_frame, "samples": snapshots}
	var file = FileAccess.open("res://artifacts/centipede-round9-coil-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
