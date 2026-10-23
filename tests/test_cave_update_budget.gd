extends SceneTree
## Large swarms must keep moving while discovering an excavation in batches.
const World = preload("res://scripts/cave_world.gd")
var checks: Array = []

class OpenWorld extends World:
	var probes = 0
	func original_solid(_cell: Vector2i) -> bool: return false
	func clear_segment(_start: Vector2, _finish: Vector2, _radius: float = 0.0) -> bool:
		probes += 1; return true

class UnreachableWorld extends OpenWorld:
	func clear_segment(_start: Vector2, _finish: Vector2, _radius: float = 0.0) -> bool:
		probes += 1; return false
	func navigation(_target: Vector2, _radius: float) -> Dictionary: return {}
	func prepare_navigation(_data: Dictionary, _origin: Vector2, _target: Vector2, _margin: int) -> bool: return true
	func nearest_nav(_id: Vector2i, _data: Dictionary) -> Vector2i: return Vector2i(2147483647, 2147483647)

class LocalDetour extends World:
	var tested_cells = 0
	func nav_passable(id: Vector2i, _radius: int) -> bool:
		tested_cells += 1; return id.x != 0 or absi(id.y) > 4
	func clear_segment(_start: Vector2, _finish: Vector2, _radius: float = 0.0) -> bool: return false

func check(value: bool, title: String):
	checks.append({"name": title, "passed": value})
	if not value: printerr("FAIL: ", title)

func _initialize(): call_deferred("execute")

func execute():
	var world = OpenWorld.new(); world.reset_cave(true)
	var memories: Array = []
	for i in 80:
		var memory = {}
		world.direction(Vector2(240 + i, 0), Vector2.ZERO, 18, memory)
		memories.append(memory)
	world.probes = 0; world.begin_navigation_frame()
	for memory in memories: world.direction(Vector2(240, 0), Vector2.ZERO, 18, memory)
	check(world.probes == 0, "A verified direct route does not repeat the long clearance ray every tick")
	world.revision += 1
	world.probes = 0; world.begin_navigation_frame()
	var moving = true
	for memory in memories: moving = moving and world.direction(Vector2(240, 0), Vector2.ZERO, 18, memory).x < -0.9
	check(world.probes == 4, "An excavation replans four actors instead of the entire swarm in one tick")
	check(moving, "Actors awaiting the new shortcut keep following their previously verified route")
	for frame in 19:
		world.begin_navigation_frame()
		for memory in memories: world.direction(Vector2(240, 0), Vector2.ZERO, 18, memory)
	check(memories.all(func(memory): return memory.cave_revision == world.revision), "All 80 actors discover a shortcut within 20 simulation ticks")
	var sealed = UnreachableWorld.new(); sealed.reset_cave(true)
	memories.clear()
	for i in 80: memories.append({})
	for frame in 20:
		sealed.begin_navigation_frame()
		for memory in memories: sealed.direction(Vector2(240, 0), Vector2.ZERO, 18, memory)
	check(memories.all(func(memory): return memory.has("cave_revision")), "Unreachable actors do not consume every tick's budget and starve later actors")
	var crowded = UnreachableWorld.new(); crowded.reset_cave(true)
	memories.clear()
	for i in 240: memories.append({})
	for frame in 65:
		crowded.begin_navigation_frame()
		for memory in memories: crowded.direction(Vector2(240, 0), Vector2.ZERO, 18, memory)
	check(memories.all(func(memory): return memory.has("cave_revision")), "All 240 actors receive a plan even when early requests expire before a full swarm pass")
	var detour = LocalDetour.new(); detour.reset_cave(true)
	var route = {}; var bounded = true; var found = false
	for frame in 20:
		detour.begin_navigation_frame(); detour.tested_cells = 0
		var direction = detour.direction(Vector2(-240, 0), Vector2(240, 0), 18, route)
		bounded = bounded and detour.tested_cells <= 48
		if not direction.is_zero_approx(): found = true; break
	check(bounded, "A cold clearance grid checks at most 48 cells per simulation tick")
	check(found, "Incrementally prepared cells still produce a real native A* detour")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks}
	FileAccess.open("res://artifacts/cave-update-budget-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
