extends SceneTree

const World = preload("res://scripts/cave_world.gd")
var checks: Array = []

func _initialize(): call_deferred("execute")
func check(ok: bool, label: String):
	checks.append({"name": label, "passed": ok})
	if not ok: printerr("FAIL: ", label)

func painted_overlap(point: Vector2, pit: Dictionary) -> bool:
	var corners = PackedVector2Array()
	for corner in [Vector2(-.5, -.5), Vector2(.5, -.5), Vector2(.5, .5), Vector2(-.5, .5)]:
		corners.append(Vector2(pit.at) + (corner * World.SIZE * float(pit.scale)).rotated(pit.angle))
	return Geometry2D.is_point_in_polygon(point, corners)

func execute():
	var world = World.new(); world.reset_cave(true)
	var pits = world.nearby(Rect2(-4200, -4200, 8400, 8400))
	var candidates = 0; var overlap = 0; var blocked_approach = 0; var safe_ore = 0
	var former_overlap = Vector2i.MAX
	for pit in pits:
		var bounds: Rect2 = Rect2(pit.bounds).grow(260)
		var low = Vector2i((bounds.position / World.CELL).floor())
		var high = Vector2i((bounds.end / World.CELL).floor())
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var cell = Vector2i(x, y)
				if world.ore(cell) <= 0: continue
				candidates += 1
				var point = (Vector2(cell) + Vector2.ONE * .5) * World.CELL
				if world.contains(pit, point, 48): blocked_approach += 1
				var overlaps = false
				for offset in [Vector2.ZERO, Vector2(-.5,-.5), Vector2(.5,-.5), Vector2(.5,.5), Vector2(-.5,.5)]:
					if painted_overlap(point + offset * World.CELL, pit): overlaps = true
				if overlaps:
					overlap += 1; former_overlap = cell
				else: safe_ore += 1
	check(pits.size() > 8 and candidates > 40 and safe_ore > 40, "Several distant hard walls retain a substantial surrounding ore field")
	check(overlap == 0, "No mineral cell overlaps a painted hard-wall footprint, including its corners")
	check(blocked_approach == 0, "Ore leaves room for a complete mining head outside the immutable collision lip")
	check(world.ore(Vector2i(14, 0)) == 1 and world.ore(Vector2i(16, 2)) == 1, "The protected opening deposit keeps its original ore and rewards")
	var sample = {}
	for x in range(-100, 101):
		var cell = Vector2i(x, 41); sample[cell] = world.ore(cell)
	world.reset_cave(true)
	check(sample.keys().all(func(cell): return sample[cell] == world.ore(cell)), "Ore exclusion regenerates deterministically after restarting")
	world.reset_cave(false)
	check(not world.nearby(Rect2(-1300, -1000, 2600, 2000)).is_empty(), "Other terrain modes retain their original hard walls")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "hard_walls": pits.size(), "ore_cells": candidates, "overlapping_cells": overlap, "blocked_mining_approaches": blocked_approach, "example_overlap": former_overlap}
	FileAccess.open("res://artifacts/cave-ore-hard-walls-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
