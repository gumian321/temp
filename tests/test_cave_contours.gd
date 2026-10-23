extends SceneTree
const World = preload("res://scripts/cave_world.gd")
var checks: Array = []

class TwoRocks extends World:
	func original_solid(cell: Vector2i) -> bool: return cell in [Vector2i(15, 0), Vector2i(16, 0)]
	func ore(cell: Vector2i) -> int: return 1 if cell.x == 15 else 0
	func nearby(_area: Rect2) -> Array: return []

func check(value: bool, title: String):
	checks.append({"name": title, "passed": value})
	if not value: printerr("FAIL: ", title)

func _initialize(): call_deferred("execute")

func execute():
	var world = World.new(); world.reset_cave(true)
	var convex = true; var beveled = 0; var boundary_samples = 0; var boundary_matches = true
	for y in range(-20, 21):
		for x in range(-26, 48):
			var cell = Vector2i(x, y)
			var shape = world.cell_shape(cell)
			if not shape.outline.is_empty(): beveled += 1
			for piece in shape.pieces:
				var polygon: PackedVector2Array = piece.polygon
				for i in polygon.size():
					var a = polygon[(i + 1) % polygon.size()] - polygon[i]
					var b = polygon[(i + 2) % polygon.size()] - polygon[(i + 1) % polygon.size()]
					convex = convex and a.cross(b) >= -0.00001
			for i in range(0, shape.outline.size(), 2):
				var a: Vector2 = shape.outline[i]; var b: Vector2 = shape.outline[i + 1]
				var outward = Vector2((b - a).y, -(b - a).x).normalized()
				var middle = a.lerp(b, 0.5)
				boundary_matches = boundary_matches and world.wall_blocked(middle - outward * 0.5) and not world.wall_blocked(middle + outward * 0.5)
				boundary_samples += 1
	check(convex, "Irregular rock cells remain convex for the production swept collision solver")
	check(beveled > 30 and boundary_samples > 100, "Generated chamber boundaries use densely sampled continuous material contours")
	check(boundary_matches, "Both sides of every painted boundary sample agree with physical rock clearance")
	var seam = TwoRocks.new(); seam.reset_cave(true)
	var old_shape = seam.cell_shape(Vector2i(15, 0))
	var old_version = int(seam.chunk_at(Vector2i.ZERO).version)
	var contact = seam.wall_hit(Vector2(480, 12), Vector2(0, 12), 27)
	var head = Vector2(contact.position) + Vector2(contact.normal) * 0.5
	for i in 10: seam.dig(head, Vector2.LEFT, Vector2.LEFT, 27, 1.0 / 60, true)
	check(not seam.solid(Vector2i(16, 0)) and seam.solid(Vector2i(15, 0)), "A real bite removes only the outer rock across a chunk boundary")
	var new_shape = seam.cell_shape(Vector2i(15, 0))
	check(new_shape.outline != old_shape.outline and seam.chunk_at(Vector2i.ZERO).version > old_version, "Excavating a neighbor refreshes the surviving rock's curved collision and cached drawing across the chunk seam")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "beveled_cells": beveled, "boundary_samples": boundary_samples}
	FileAccess.open("res://artifacts/cave-contours-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
