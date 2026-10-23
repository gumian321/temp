extends "res://scripts/cave_world.gd"
## Frozen pre-optimization sweep oracle.
func wall_hit(start: Vector2, finish: Vector2, radius: float = 0.0) -> Dictionary:
	if not enabled: return {}
	var area = Rect2(start, Vector2.ZERO).expand(finish).grow(radius + 6)
	var low = Vector2i((area.position / CELL).floor())
	var high = Vector2i((area.end / CELL).floor())
	var delta:Vector2=finish-start
	var squared:float=delta.length_squared()
	if squared<0.0000000001:return {}
	var query:Rect2=Rect2(start,Vector2.ZERO).expand(finish).grow(radius+.8)
	var earliest:float=INF
	var closest:ContourEdge
	for y in range(low.y, high.y + 1):
		# Restrict each row to the swept corridor. A long diagonal ray must not
		# inspect every rock in its entire rectangular bounding box.
		var row_low = low.x
		var row_high = high.x
		var delta_y = finish.y - start.y
		if absf(delta_y) > 0.0001:
			var a = (float(y) * CELL - radius - 6 - start.y) / delta_y
			var b = (float(y + 1) * CELL + radius + 6 - start.y) / delta_y
			var enter = clampf(minf(a, b), 0, 1)
			var leave = clampf(maxf(a, b), 0, 1)
			var left = lerpf(start.x, finish.x, enter)
			var right = lerpf(start.x, finish.x, leave)
			row_low = floori((minf(left, right) - radius - 6) / CELL)
			row_high = floori((maxf(left, right) + radius + 6) / CELL)
		for item:ContourEdge in collision_row(y, row_low, row_high):
			if not item.bounds.intersects(query):continue
			var time:float=contour_time(item,start,delta,squared,radius)
			if time<earliest:earliest=time;closest=item
	if closest==null:return {}
	var position:Vector2=start+delta*earliest
	var contact:Vector2=Geometry2D.get_closest_point_to_segment(position,closest.a,closest.b)
	var normal:Vector2=(position-contact).normalized() if radius>0 else closest.normal
	return {"time":earliest,"normal":normal,"cell":closest.cell,"position":position}

