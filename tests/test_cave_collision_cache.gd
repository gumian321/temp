extends SceneTree
const World = preload("res://scripts/cave_world.gd")
var checks: Array = []
func _initialize(): call_deferred("execute")
func check(ok: bool, label: String):
	checks.append({"passed": ok, "label": label})
	if not ok: push_error(label)
func reference_blocked(world, point: Vector2, radius: float) -> bool:
	var low = Vector2i(((point - Vector2.ONE * (radius + 6)) / World.CELL).floor())
	var high = Vector2i(((point + Vector2.ONE * (radius + 6)) / World.CELL).floor())
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			for piece in world.cell_shape(Vector2i(x, y)).pieces:
				if world.contains(piece, point, radius): return true
	return false
func reference_hit(world, start: Vector2, finish: Vector2, radius: float) -> Dictionary:
	var area = Rect2(start, Vector2.ZERO).expand(finish).grow(radius + 6)
	var low = Vector2i((area.position / World.CELL).floor()); var high = Vector2i((area.end / World.CELL).floor())
	var closest: Dictionary = {}
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			for piece in world.cell_shape(Vector2i(x, y)).pieces:
				var hit = world.sweep(piece, start, finish - start, radius)
				if not hit.is_empty() and (closest.is_empty() or hit.time < closest.time): closest = hit
	return closest
func verify(world, rng) -> Dictionary:
	var blocked_mismatches = 0; var sweep_mismatches = 0; var sweep_count = 0
	var worst_error = 0.0
	for i in 1200:
		var at = Vector2(rng.randf_range(-450, 1080), rng.randf_range(-400, 350))
		var radius: float = [0.0, 15.0, 28.0, 48.0][i % 4]
		if reference_blocked(world, at, radius) != world.wall_blocked(at, radius): blocked_mismatches += 1
		if i % 5 != 0 or reference_blocked(world, at, radius): continue
		var finish = at + Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(30, 260)
		var old = reference_hit(world, at, finish, radius); var current = world.wall_hit(at, finish, radius)
		sweep_count += 1
		if old.is_empty() != current.is_empty(): sweep_mismatches += 1
		elif not old.is_empty():
			var error = absf(old.time - current.time) * at.distance_to(finish)
			worst_error = maxf(worst_error, error)
			if error > .025: sweep_mismatches += 1
	return {"blocked_mismatches": blocked_mismatches, "sweep_mismatches": sweep_mismatches, "sweeps": sweep_count, "max_contact_error": worst_error}
func execute():
	var world = World.new(); world.reset_cave(true)
	var rng = RandomNumberGenerator.new(); rng.seed = 20261021
	var before = verify(world, rng)
	check(before.blocked_mismatches == 0 and before.sweep_mismatches == 0, "Contour collisions match the original filled polygons for 1200 seeded circle/ray probes")
	var entry = world.wall_hit(Vector2.ZERO, Vector2(1000, 0), 28)
	var head: Vector2 = entry.position + entry.normal * .4
	for i in 240:
		world.dig(head, Vector2.RIGHT, Vector2.RIGHT, 28, 1.0 / 60)
		head = world.move(head, head + Vector2.RIGHT * 2.2, 28)
	var after = verify(world, rng)
	check(world.removed_count > 0 and after.blocked_mismatches == 0 and after.sweep_mismatches == 0, "Bites invalidate cached exposed edges and preserve exact post-excavation contacts")
	var movement_error=0.0;var moves=0
	for i in 200:
		var start=Vector2(rng.randf_range(-350,950),rng.randf_range(-350,350))
		var radius:float=[15.0,27.0,48.0][i%3]
		if world.blocked(start,radius):continue
		for step in 8:
			var desired=start+Vector2.from_angle(rng.randf_range(-PI,PI))*rng.randf_range(.1,8)
			var reference=world.move_contour(start,desired,radius)
			var cached=world.move(start,desired,radius)
			movement_error=maxf(movement_error,reference.distance_to(cached));moves+=1;start=reference
	check(movement_error<.002 and moves>200,"Certified empty-space movement matches the full swept solver across open rock, contact and legacy-pit footprints")
	for i in 2300: world.collision_row(i % 30, i - 1000, i - 1000)
	check(world.collision_rows.size() <= 2048, "Long expeditions keep the collision cache bounded")
	world.reset_cave(true, 111)
	check(world.collision_rows.is_empty() and world.free_regions.is_empty(), "Restart/seed changes discard all old collision rows and free-space certificates")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "before": before, "after": after,"movement_comparisons":moves,"movement_max_error":movement_error}
	FileAccess.open("res://artifacts/cave-collision-cache-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
