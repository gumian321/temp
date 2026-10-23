extends SceneTree
const World = preload("res://scripts/cave_world.gd")
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
var checks: Array = []

class StripWall extends World:
	func original_solid(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.x <= 2 and absi(cell.y) < 19
	func nearby(_area: Rect2) -> Array: return []
	func ore(cell: Vector2i) -> int: return 1 if cell.x == 0 and absi(cell.y) <= 2 else 0

class DeepRock extends StripWall:
	func original_solid(cell: Vector2i) -> bool: return cell.x >= 0
	func ore(_cell: Vector2i) -> int: return 0

func check(value: bool, title: String):
	checks.append({"name": title, "passed": value})
	if not value: printerr("FAIL: ", title)

func _initialize(): call_deferred("execute")

func make_body(db, world):
	var body = Body.new(db); body.configure_character("centipede"); body.terrain = world
	body.head = Vector2(-180, 12); body.facing = Vector2.RIGHT
	for i in body.history.size(): body.history[i] = body.head - Vector2(i * 4, 0)
	for i in 8: body.append_segment(db.named("Core_Gun_Gatling").id)
	body.motion.reset(); body.refresh_positions()
	return body

func execute():
	var db = DB.new()
	var generated = World.new(); generated.reset_cave(true)
	check(not generated.blocked(Vector2.ZERO, 30), "Production generator starts in a clear chamber")
	var start_trail = generated.initial_trail(Vector2.ZERO, Vector2.RIGHT)
	var trail_length = 0.0
	for i in range(1, start_trail.size()): trail_length += start_trail[i].distance_to(start_trail[i - 1])
	check(trail_length > 3600 and start_trail.all(func(point): return not generated.blocked(point, 30)), "The starting chamber provides a valid folded trail for 60 newly installed modules")
	check(generated.wall_blocked(Vector2(420, 0)), "Eastern shortcut is a continuous solid rock layer")
	check(not generated.wall_blocked(Vector2(760, 0), 30), "A second chamber exists beyond the shortcut")
	var before = generated.move(Vector2.ZERO, Vector2(1000, 0), 30)
	check(before.x < 360 and not generated.blocked(before, 30), "Swept player movement cannot cross an unmined wall")
	var safe = generated.safe_position(Vector2(420, 0), 35)
	check(not generated.blocked(safe, 35), "Spawns requested in rock relocate to a complete clear footprint")
	var far = Vector2i(123, -87)
	var original = generated.solid(far)
	generated.reset_cave(true)
	check(generated.solid(far) == original, "Distant positive and negative chunks regenerate deterministically")
	var terrain = StripWall.new(); terrain.reset_cave(true)
	var body = make_body(db, terrain)
	var battle = Battle.new(db, body)
	check(not terrain.ray_clear(Vector2(-160, 12), Vector2(220, 12)), "Rock blocks aiming and fire before excavation")
	var core = db.named("Core_Gun_Gatling")
	var behind = battle.spawn(db.pool["250"], Vector2(220, 12))
	behind.warp = 0; behind.guns = []; behind.components = []; behind.hp = 1000; behind.max_hp = 1000; behind.stun = 100
	check(battle.target_for(core, Vector2(-150, 12), 1000).is_empty(), "Automatic weapons do not acquire targets through solid rock")
	battle.fire(core, Vector2(-150, 12), Vector2.RIGHT, true)
	var shot = battle.bullets.back(); shot.velocity = Vector2(10000, 0); shot.radius = 0.5; shot.damage = 2; shot.pierce = 1
	battle.step(0.05, Vector2.ZERO, false, false)
	check(behind.hp == 1000 and battle.bullets.is_empty(), "A real high-speed bullet is stopped before damaging an actor behind rock")
	battle.enemies.clear()
	var memory = {}
	var previous_direction = Vector2.ZERO
	for frame in 90:
		terrain.begin_navigation_frame()
		previous_direction = terrain.direction(Vector2(-180, 12), Vector2(220, 12), 18, memory)
		if not previous_direction.is_zero_approx(): break
	if absf(previous_direction.y)<=.05:print("NAV_DIAGNOSTIC=",JSON.stringify({"direction":previous_direction,"memory":memory,"filled":terrain.nav_grids.values().map(func(data):return data.filled.size()),"nav_cells":terrain.nav_cells_left,"prepare_us":terrain.nav_prepare_us}))
	check(absf(previous_direction.y) > 0.05, "Navigation initially routes around the solid rock layer")
	var stopped = terrain.move(Vector2(-180, 12), Vector2(1300, 12), 27)
	check(stopped.x < 0 and not terrain.blocked(stopped, 27), "A high speed sweep stays on the entry side with its complete physical footprint outside rock")
	var untouched = terrain.removed_count
	for i in 30: terrain.dig(stopped, Vector2.ZERO, Vector2.RIGHT, 27, 1.0 / 60)
	check(terrain.removed_count == untouched, "Standing beside a wall without movement input does not mine")
	var all_clear = true
	var max_move = 0.0
	var rewarded_before_break = false
	var samples: Array = []
	for frame in 480:
		var old: Vector2 = body.head
		body.step(1.0 / 60, Vector2.RIGHT, false)
		battle.flush_mining_events()
		if terrain.ore_total > 0 and terrain.solid(Vector2i(0, 0)): rewarded_before_break = true
		max_move = maxf(max_move, old.distance_to(body.head))
		for pose in body.body_poses:
			all_clear = all_clear and not terrain.blocked(pose.point, 26)
		if frame % 30 == 0: samples.append([frame, body.head.x, terrain.removed_count, terrain.ore_total])
		if body.head.x > 260: break
	check(body.head.x > 240, "Pressing a wall chews through it and advances into the next chamber")
	check(all_clear, "Head and eight followers remain outside solid rock throughout excavation")
	check(max_move < 5, "Breaking a wall never teleports the head forward")
	check(terrain.ore_total > 0 and rewarded_before_break, "Ore pays gradually before its rock cell is fully removed")
	check(battle.loot.size() > 0 and battle.loot.all(func(drop): return drop.value > 0 and not terrain.blocked(drop.position)), "Ore uses existing pickups and drops on the open side of the face")
	check(terrain.ray_clear(Vector2(-160, 12), Vector2(220, 12)), "The same newly mined opening admits fire")
	behind = battle.spawn(db.pool["250"], Vector2(220, 12))
	behind.warp = 0; behind.guns = []; behind.components = []; behind.hp = 1000; behind.max_hp = 1000; behind.stun = 100
	battle.fire(core, Vector2(-150, 12), Vector2.RIGHT, true)
	shot = battle.bullets.back(); shot.velocity = Vector2(10000, 0); shot.radius = 0.5; shot.damage = 2; shot.pierce = 1
	battle.step(0.05, Vector2.ZERO, false, false)
	check(behind.hp < 1000, "The same high-speed bullet damages an actor through the newly mined opening")
	battle.enemies.clear()
	var next_direction = terrain.direction(Vector2(-180, 12), Vector2(220, 12), 18, memory)
	check(next_direction.x > 0.9 and absf(next_direction.y) < 0.2, "Existing enemy navigation memory discovers the new shortcut")
	var earned = terrain.ore_total
	for i in 30: terrain.dig(Vector2(-28, 12), Vector2.RIGHT, Vector2.RIGHT, 27, 1.0 / 60)
	check(terrain.ore_total == earned, "Already excavated ore cannot pay a second time")
	var enemy = battle.spawn(db.pool["250"], Vector2(-180, 12))
	enemy.guns = []; enemy.warp = 0; enemy.stop_distance = 0
	var reached = false
	for frame in 360:
		var dir = battle.ground_direction(enemy, body.head)
		battle.move_actor(enemy, Vector2(enemy.position) + dir * 150.0 / 60)
		if enemy.position.x > 160: reached = true; break
	check(reached and not terrain.blocked(enemy.position, enemy.radius), "A production monster physically follows the player through the mined tunnel")
	var backward = DeepRock.new(); backward.reset_cave(true)
	var retreating = make_body(db, backward)
	for i in 360:
		retreating.step(1.0 / 60, Vector2.RIGHT, false)
		if retreating.head.x > 60: break
	var entrance: Vector2 = retreating.head
	var did_reverse = false
	for i in 90:
		retreating.step(1.0 / 60, Vector2.LEFT, false)
		did_reverse = did_reverse or retreating.motion.reversing
	check(retreating.head.x < entrance.x - 70 and not backward.blocked(retreating.head, 27), "Opposite input can retreat from a narrow mined tunnel")
	check(did_reverse, "The narrow-tunnel reverse branch is exercised before turning in open space")
	check(retreating.body_poses.all(func(pose): return not backward.blocked(pose.point, 26)), "Followers remain clear while backing out")
	var corner = DeepRock.new(); corner.reset_cave(true)
	var turning = make_body(db, corner)
	for i in 300:
		turning.step(1.0 / 60, Vector2.RIGHT, false)
		if turning.head.x > 60: break
	var corner_clear = true
	var corner_failure: Array = []
	for i in 240:
		turning.step(1.0 / 60, Vector2.UP, false)
		corner_clear = corner_clear and turning.body_poses.all(func(pose): return not corner.blocked(pose.point, 26))
		if not corner_clear and corner_failure.is_empty(): corner_failure = [i, turning.head, turning.body_poses]
	if turning.head.y >= -130 or not corner_clear: print("CORNER_DIAGNOSTIC=", JSON.stringify({"head": turning.head, "facing": turning.facing, "hit": corner.wall_hit(turning.head, turning.head + Vector2.UP * 12, 30), "blocked": corner.wall_blocked(turning.head, 30), "first_failure": corner_failure, "mined": corner.removed_count, "active": corner.mining_active}))
	check(turning.head.y < -130 and corner_clear, "Head and eight modules chew and follow a right-angle bend inside continuous rock")
	turning.begin_coil()
	for i in 90: turning.step(1.0 / 60, Vector2.ZERO, false)
	turning.end_coil()
	for i in 180: turning.step(1.0 / 60, Vector2.ZERO, false)
	if turning.coil_rig.engaged(): print("COIL_DIAGNOSTIC=", JSON.stringify({"phase": turning.coil_rig.phase, "head": turning.head, "goals": turning.coil_rig.targets(turning), "poses": turning.body_poses}))
	check(not turning.coil_rig.engaged() and turning.body_poses.all(func(pose): return not corner.blocked(pose.point, 26)), "Coiling and uncoiling in a confined passage finish without trapping the body")
	turning.parts[3].hp = 0; turning.remove_destroyed_parts([3])
	check(turning.detached_module_count() == 5, "A cave bend preserves five living modules behind a destroyed middle segment")
	turning.detached_fragments[0].state = "waking"
	for i in 420:
		turning.step(1.0 / 60, Vector2.ZERO, false)
		if turning.detached_fragments.is_empty(): break
	check(turning.detached_fragments.is_empty() and turning.segment_count() == 7 and turning.body_poses.all(func(pose): return not corner.blocked(pose.point, 26)), "Awakened fragments follow the cave bend and rejoin without entering rock")
	var long_world = DeepRock.new(); long_world.reset_cave(true)
	var long_body = make_body(db, long_world)
	for i in 52: long_body.append_segment(core.id)
	var long_clear = true
	var long_started = Time.get_ticks_usec()
	for i in 180:
		long_body.step(1.0 / 60, Vector2.RIGHT, false)
		if i % 15 == 0: long_clear = long_clear and long_body.body_poses.all(func(pose): return not long_world.blocked(pose.point, 26))
	check(long_body.segment_count() == 60 and long_clear, "Maximum-length 60-module body remains outside rock during excavation")
	# Frame-rate independence and zero-fuel access are gameplay requirements.
	var outcomes: Array = []
	for fps in [30, 60, 120]:
		var world = StripWall.new(); world.reset_cave(true)
		var actor = make_body(db, world); actor.fuel = 0
		for i in fps * 5: actor.step(1.0 / fps, Vector2.RIGHT, false)
		outcomes.append(actor.head.x)
	check(float(outcomes.max()) - float(outcomes.min()) < 12, "30/60/120 FPS give equivalent free excavation progress")
	check(float(outcomes.min()) > 72, "Fuel is never required to escape through ordinary rock")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "excavation_samples": samples, "fps_positions": outcomes, "long_body_simulation_ms": float(Time.get_ticks_usec() - long_started) / 1000.0}
	FileAccess.open("res://artifacts/cave-mining-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
