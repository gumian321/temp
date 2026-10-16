extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/grid_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Brood = preload("res://scripts/brood_theme.gd")
var checks: Array = []
var measurements: Array = []

func _initialize(): call_deferred("execute")

func check(value: bool, title: String):
	checks.append({"name": title, "passed": value})
	if not value: printerr("FAIL: ", title)

func execute():
	var db = DB.new()
	var body = Body.new(db)
	var battle = Battle.new(db, body)
	var species_seen: Dictionary = {}
	var radius_seen: Dictionary = {}
	var small_count = 0
	var large_count = 0
	var actual_valid = true
	# Exercise actual actor creation, including every multipart prefab's children.
	for prefab in db.entities:
		for blueprint in db.entities[prefab]:
			var e = battle.spawn_actor(prefab, blueprint, Vector2.ZERO)
			if not Brood.eligible(e): continue
			var before = e.duplicate(true)
			var extent = Brood.extent(e)
			var old_extent = maxf(38.0, float(e.radius) * 2.7)
			var species = Brood.species(e)
			species_seen[species] = true
			radius_seen[str(e.radius)] = true
			actual_valid = actual_valid and e == before
			actual_valid = actual_valid and extent >= old_extent and extent <= old_extent * 1.214
			if float(e.radius) < 22.0:
				small_count += 1
				actual_valid = actual_valid and extent > old_extent
			else:
				large_count += 1
				actual_valid = actual_valid and is_equal_approx(extent, old_extent)
			measurements.append({"name": e.name, "kind": e.kind, "species": species, "radius": e.radius, "old_extent": old_extent, "extent": extent})
	check(actual_valid, "All actual prefabs gain at most 21.4% visually with no entity mutation; radius 22+ is unchanged")
	check(small_count > 0 and large_count > 0 and species_seen.size() == 6, "Audit covers small and large spawned actors and all six species")
	check(is_equal_approx(Brood.extent({"radius": 15}), 48.6), "Ordinary small bugs gain exactly 20%")
	check(is_equal_approx(Brood.extent({"radius": 12}), 46.1), "Encounter hatchlings gain bounded visibility and remain smaller than ordinary bugs")
	var monotonic = true
	var previous = 0.0
	for i in range(120, 1051):
		var extent = Brood.extent({"radius": float(i) / 10.0})
		monotonic = monotonic and extent >= previous
		previous = extent
	check(monotonic, "Visual size remains monotonic through the taper and into boss sizes")
	for radius in [22.0, 24.0, 32.0, 45.0, 52.5, 67.5, 75.0, 82.5, 84.0, 90.0, 105.0]:
		check(is_equal_approx(Brood.extent({"radius": radius}), radius * 2.7), "Larger encounter / boss extent unchanged: " + str(radius))
	# Projectile contact still uses the original combat radius, not the larger rig.
	var enemy = battle.spawn(db.pool["250"], Vector2(400, 0))
	for e in battle.enemies: e.guns.clear()
	var before = enemy.duplicate(true)
	var shot = {"position": enemy.position - Vector2(50, 0), "previous": enemy.position - Vector2(100, 0), "velocity": Vector2.RIGHT, "radius": 0.0}
	var contact = battle.visual_contact(enemy, shot)
	check(is_equal_approx(Vector2(contact.position).distance_to(enemy.position), float(enemy.radius)), "Combat contact remains on the unchanged hit radius")
	Brood.extent(enemy)
	check(enemy == before, "Size evaluation preserves health, damage, movement, transform and collision data")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "species": species_seen.keys(), "radii": radius_seen.keys(), "small_actors": small_count, "large_actors": large_count, "measurements": measurements}
	FileAccess.open("res://artifacts/enemy-sizes-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify({"passed": report.passed, "checks": checks, "small_actors": small_count, "large_actors": large_count}))
	quit(0 if report.passed else 1)
