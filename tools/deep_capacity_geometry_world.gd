extends "res://scripts/cave_world.gd"
## Capacity-only diagnostic control; defaults preserve current cache budgets.
## Geometry and row eviction/build algorithms remain identical to World.
var geometry_capacity=maxi(128,int(OS.get_environment("RBPEW_GEOMETRY_CAPACITY"))) if not OS.get_environment("RBPEW_GEOMETRY_CAPACITY").is_empty() else 12000
var collision_row_capacity=maxi(128,int(OS.get_environment("RBPEW_COLLISION_ROW_CAPACITY"))) if not OS.get_environment("RBPEW_COLLISION_ROW_CAPACITY").is_empty() else 2048

func cell_shape(cell: Vector2i) -> Dictionary:
	if geometry.has(cell):geometry_hits+=1;return geometry[cell]
	geometry_misses+=1
	var mask = 0
	var local_x=posmod(cell.x,CHUNK);var local_y=posmod(cell.y,CHUNK)
	if local_x>0 and local_x<CHUNK-1 and local_y>0 and local_y<CHUNK-1:
		var solids:PackedByteArray=chunk_at(chunk_id(cell)).solid
		var index:int=local_y*CHUNK+local_x
		for y:int in 3:
			for x:int in 3:
				if solids[index+(y-1)*CHUNK+x-1]!=0:mask|=1<<(y*3+x)
	else:
		for y in 3:
			for x in 3:
				if solid(cell + Vector2i(x - 1, y - 1)): mask |= 1 << (y * 3 + x)
	if mask==0:geometry_mask_zero+=1
	elif mask==511:geometry_mask_full+=1
	else:geometry_mask_mixed+=1
	var source = ContourMesh.fractured_template(mask, cell, seed_value)
	if source.pieces.is_empty():
		geometry_empty_misses+=1
		if geometry.size()>=geometry_capacity:
			var oldest=geometry.keys()
			for i in 128:geometry.erase(oldest[i])
			geometry_evictions+=128;geometry_eviction_batches+=1
		geometry[cell]=empty_shape
		return empty_shape
	var corners = PackedVector2Array([vertex(cell), vertex(cell + Vector2i.RIGHT), vertex(cell + Vector2i.ONE), vertex(cell + Vector2i.DOWN)])
	var pieces: Array = []; var outline = PackedVector2Array()
	for local_polygon in source.pieces:
		var polygon = PackedVector2Array()
		for at in local_polygon: polygon.append(project_contour(at, corners))
		pieces.append(cave_piece(polygon))
	for at in source.outline: outline.append(project_contour(at, corners))
	var result = {"pieces": pieces, "outline": outline}
	if geometry.size() >= geometry_capacity:
		var oldest = geometry.keys()
		for i in 128: geometry.erase(oldest[i])
		geometry_evictions+=128;geometry_eviction_batches+=1
	geometry[cell] = result
	return result


func collision_row(y: int, left: int, right: int) -> Array:
	# Only the exposed contour can stop an outside body. Interior tessellation
	# edges are for rendering/penetration recovery, not a second physical wall.
	var key = Vector3i(left, right, y)
	if collision_rows.has(key):collision_row_hits+=1;return collision_rows[key]
	collision_row_misses+=1
	var edges: Array = []
	if use_collision_blocks:edges=collision_fragments(y,left,right)
	else:
		for x in range(left, right + 1):
			var outline: PackedVector2Array = cell_shape(Vector2i(x, y)).outline
			for i in range(0, outline.size(), 2):
				var a = outline[i]; var b = outline[i + 1]; var delta = b - a
				var edge=ContourEdge.new(a,Vector2i(x,y))
				edge.b=b;edge.delta=delta;edge.length_squared=delta.length_squared()
				edge.normal=Vector2(delta.y,-delta.x).normalized();edge.bounds=Rect2(a,Vector2.ZERO).expand(b)
				edges.append(edge)
	if collision_rows.size() >= collision_row_capacity:
		var oldest = collision_rows.keys()
		for i in 128: collision_rows.erase(oldest[i])
		collision_row_evictions+=128
	collision_rows[key] = edges
	return edges

