extends "res://scripts/cave_world.gd"
## Frozen exact point/circle overlap oracle.
func wall_blocked(point: Vector2, radius: float = 0.0) -> bool:
	if not enabled: return false
	# A center already inside rock is blocked even when its entire query lies
	# deep inside a solid region, far from the external contour.
	var center_low = Vector2i(((point - Vector2.ONE * 6) / CELL).floor())
	var center_high = Vector2i(((point + Vector2.ONE * 6) / CELL).floor())
	for y in range(center_low.y, center_high.y + 1):
		for x in range(center_low.x, center_high.x + 1):
			for piece in cell_shape(Vector2i(x, y)).pieces:
				if contains(piece, point, 0): return true
	if radius <= 0: return false
	var low = Vector2i(((point - Vector2.ONE * (radius + 6)) / CELL).floor())
	var high = Vector2i(((point + Vector2.ONE * (radius + 6)) / CELL).floor())
	for y in range(low.y, high.y + 1):
		for item:ContourEdge in collision_row(y, low.x, high.x):
			if item.bounds.grow(radius).has_point(point) and Geometry2D.get_closest_point_to_segment(point, item.a, item.b).distance_squared_to(point) <= radius * radius: return true
	return false

