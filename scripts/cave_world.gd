extends "res://scripts/chasm_world.gd"
## Persistent excavatable rock. Rendering, swept collisions and navigation read
## these same world cells; removing a cell opens it for every system at once.
const CELL = 24.0
const CHUNK = 16
const DRAW_PATCH = 4
const NAV_STEP = 48.0
const ROOM_STEP = 1056.0
const BITE_INTERVAL = 0.16
const NAV_REPLANS_PER_FRAME = 4
const NAV_CELLS_PER_FRAME = 48
const NAV_PREPARE_USEC=1200
const LOCAL_NAV_RANGE=1536.0
const ContourMesh = preload("res://scripts/cave_contour_mesh.gd")
static var empty_shape={"pieces":[],"outline":PackedVector2Array()}
var enabled = false
var seed_value = 20261020
var chunks: Dictionary = {}
var geometry: Dictionary = {}
var collision_rows: Dictionary = {}
var sweep_neighborhoods: Dictionary = {}
var sweep_neighborhood_order: Array = []
const SWEEP_NEIGHBORHOOD_LIMIT=512
const LOCAL_SWEEP_DISTANCE=8.0
const SWEEP_NEIGHBORHOOD_STEP=8.0
var use_sweep_neighborhoods=true
var legacy_regions: Dictionary = {}
var patch_versions:Dictionary={}
var free_regions:Dictionary={}
var free_radii:Dictionary={}
var blocked_free_regions:Dictionary={}
var move_certificate_step:float=16.0
var use_sweep_clipping=true
var use_clearance_cache=true
var clear_points:Dictionary={}
var clear_point_count=0
var room_cache: Dictionary = {}
var nav_grids: Dictionary = {}
var nav_open: Dictionary = {}
var revision = 0
var mining_active = false
var mining_point = Vector2.ZERO
var bite_timer = 0.0
var bite_serial = 0
var events: Array = []
var loot_events: Array = []
var removed_count = 0
var ore_total = 0
var nav_budget_active = false
var nav_replans = 0
var nav_serial = 0
var nav_cells_left = NAV_CELLS_PER_FRAME
var nav_clock_ms = 0.0
var nav_waiting: Dictionary = {}
var nav_ticket_serial = 0
var nav_ticket_head = 0
var nav_frame = 0
var nav_prepare_us=0

class ContourEdge extends RefCounted:
	var a:Vector2
	var b:Vector2
	var delta:Vector2
	var length_squared:float
	var normal:Vector2
	var bounds:Rect2
	var cell:Vector2i
	func _init(from:Vector2,to:Vector2i):
		a=from;cell=to

func reset_cave(active: bool, world_seed: int = 20261020):
	enabled = active
	seed_value = world_seed
	chunks.clear(); geometry.clear(); collision_rows.clear(); legacy_regions.clear(); room_cache.clear(); nav_grids.clear(); nav_open.clear()
	sweep_neighborhoods.clear();sweep_neighborhood_order.clear()
	patch_versions.clear()
	free_regions.clear()
	free_radii.clear()
	blocked_free_regions.clear()
	clear_points.clear();clear_point_count=0
	cache.clear(); events.clear(); loot_events.clear()
	revision = 0; removed_count = 0; ore_total = 0; bite_timer = 0; bite_serial = 0
	nav_budget_active = false; nav_replans = 0; nav_serial = 0
	nav_cells_left = NAV_CELLS_PER_FRAME
	nav_clock_ms = 0
	nav_waiting.clear(); nav_ticket_serial = 0; nav_ticket_head = 0; nav_frame = 0
	mining_active = false

func noise_id(cell: Vector2i, salt: int = 0) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (seed_value * 83492791) ^ salt)

func initial_trail(origin: Vector2, forward: Vector2) -> Array[Vector2]:
	# New modules need actual open space even before the head has travelled.
	# Seed a roomy spiral in the starting chamber, with a straight neck behind
	# the head, instead of extrapolating an infinite line through unmined rock.
	var points: Array[Vector2] = [origin]
	for i in range(1, 21): points.append(origin - forward * i * 4.0)
	var side = forward.orthogonal()
	var center = origin - forward * 80 + side * 48
	var angle = -PI * 0.5
	var traveled = 80.0
	while points.size() < 1400 and traveled < 4000:
		var radius = 80.0 + 9.0 * absf(angle + PI * 0.5)
		angle -= 4.0 / (radius * 0.8)
		var next = center + forward * cos(angle) * radius + side * sin(angle) * radius * 0.6
		if blocked(next, 31): break
		traveled += points.back().distance_to(next); points.append(next)
	return points

func room_at(id: Vector2i) -> Vector2:
	if not room_cache.has(id):
		var n = noise_id(id, 21371)
		room_cache[id] = Vector2(id) * ROOM_STEP + Vector2(float(n % 149) - 74, float((n / 151) % 127) - 63)
	return room_cache[id]

func segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))

func original_solid(cell: Vector2i) -> bool:
	var p = (Vector2(cell) + Vector2.ONE * 0.5) * CELL
	# Continuous distortion bends chambers and corridors without rectangular
	# generation boundaries or a visible, repeated tile silhouette.
	p += Vector2(sin(p.y * 0.013) * 26 + sin(p.y * 0.027 + p.x * 0.011) * 12,
		sin(p.x * 0.009) * 25 + sin(p.x * 0.019 - p.y * 0.012) * 13)
	var rough = float(noise_id(Vector2i(cell.x / 3, cell.y / 3), 193) % 11) - 5.0
	# A readable first chamber, an ore-bearing shortcut to the east, and an
	# existing northern detour. Subsequent chambers continue without a border.
	if p.x > -600 and p.x < 1120 and absf(p.y) < 450:
		var opening = ((p + Vector2(80, 0)) / Vector2(430 + rough, 300 + rough)).length() < 1.0
		var annex = ((p - Vector2(760, 0)) / Vector2(280 + rough, 250 + rough)).length() < 1.0
		var detour = segment_distance(p, Vector2(40, -250), Vector2(620, -310)) < 75 + rough
		detour = detour or segment_distance(p, Vector2(620, -310), Vector2(760, -100)) < 85 + rough
		if opening or annex or detour: return false
	var low = Vector2i((p / ROOM_STEP).floor())
	for y in 2:
		for x in 2:
			var id = low + Vector2i(x, y)
			var center = room_at(id)
			var n = noise_id(id, 713)
			var extent = Vector2(335 + n % 70, 290 + (n / 73) % 65) + Vector2.ONE * rough
			if id not in [Vector2i.ZERO, Vector2i.RIGHT] and ((p - center) / extent).length_squared() < 1.0: return false
			if id != Vector2i.RIGHT and segment_distance(p, center, room_at(id + Vector2i.LEFT)) < 88 + n % 22 + rough: return false
			if n % 3 != 0 and segment_distance(p, center, room_at(id + Vector2i.UP)) < 86 + n % 29 + rough: return false
	return true

func chunk_id(cell: Vector2i) -> Vector2i:
	return Vector2i((Vector2(cell) / CHUNK).floor())

func cell_index(cell: Vector2i) -> int:
	return posmod(cell.y, CHUNK) * CHUNK + posmod(cell.x, CHUNK)

func chunk_at(id: Vector2i) -> Dictionary:
	if not chunks.has(id):
		var solids = PackedByteArray(); solids.resize(CHUNK * CHUNK)
		for y in CHUNK:
			for x in CHUNK: solids[y * CHUNK + x] = 1 if original_solid(id * CHUNK + Vector2i(x, y)) else 0
		chunks[id] = {"solid": solids, "damage": {}, "paid": {}, "version": 0, "damage_version": 0}
	return chunks[id]

func solid(cell: Vector2i) -> bool:
	return chunk_at(chunk_id(cell)).solid[cell_index(cell)] != 0

func ore(cell: Vector2i) -> int:
	# The first deposit is visible from the starting chamber.
	if cell.x >= 14 and cell.x <= 16 and absi(cell.y) <= 2: return 1
	var block = Vector2i((Vector2(cell) / 12.0).floor())
	var n = noise_id(block, 7793)
	if n % 9 != 0: return 0
	var center = block * 12 + Vector2i(3 + n % 5, 3 + (n / 17) % 5)
	return 1 + n % 3 if Vector2(cell - center).length_squared() <= 5.0 else 0

func durability(cell: Vector2i) -> int:
	return 6 if ore(cell) > 0 else 2

func vertex(point: Vector2i) -> Vector2:
	var p = Vector2(point) * CELL
	return p + Vector2(sin(p.y * 0.029 + p.x * 0.008) * 2.8 + sin(p.y * 0.067) * 0.9,
		sin(p.x * 0.027 - p.y * 0.013) * 2.6 + sin(p.x * 0.061) * 0.8)

func project_contour(at: Vector2, corners: PackedVector2Array) -> Vector2:
	return corners[0].lerp(corners[1], at.x).lerp(corners[3].lerp(corners[2], at.x), at.y)

func cave_piece(polygon: PackedVector2Array) -> Dictionary:
	var normals = PackedVector2Array()
	var bounds = Rect2(polygon[0], Vector2.ZERO)
	for i in polygon.size():
		bounds = bounds.expand(polygon[i])
		var edge = polygon[(i + 1) % polygon.size()] - polygon[i]
		normals.append(Vector2(edge.y, -edge.x).normalized())
	return {"polygon": polygon, "normals": normals, "bounds": bounds, "miter": 1.0, "cave_piece": true}

func cell_shape(cell: Vector2i) -> Dictionary:
	if geometry.has(cell): return geometry[cell]
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
	var source = ContourMesh.fractured_template(mask, cell, seed_value)
	if source.pieces.is_empty():
		if geometry.size()>=12000:
			var oldest=geometry.keys()
			for i in 128:geometry.erase(oldest[i])
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
	if geometry.size() >= 12000:
		var oldest = geometry.keys()
		for i in 128: geometry.erase(oldest[i])
	geometry[cell] = result
	return result

func contains(pit: Dictionary, point: Vector2, radius: float) -> bool:
	if not pit.has("cave_piece"): return super.contains(pit, point, radius)
	if not Rect2(pit.bounds).grow(radius).has_point(point): return false
	if Geometry2D.is_point_in_polygon(point,pit.polygon): return true
	if radius <= 0: return false
	for i in pit.polygon.size():
		if Geometry2D.get_closest_point_to_segment(point, pit.polygon[i], pit.polygon[(i + 1) % pit.polygon.size()]).distance_squared_to(point) <= radius * radius: return true
	return false

func sweep(pit: Dictionary, start: Vector2, delta: Vector2, radius: float) -> Dictionary:
	if not pit.has("cave_piece") or radius <= 0: return super.sweep(pit, start, delta, radius)
	if not Rect2(pit.bounds).grow(radius + 0.4).intersects(Rect2(start, Vector2.ZERO).expand(start + delta).grow(0.4)): return {}
	var squared = delta.length_squared()
	if squared < 0.0000000001: return {}
	var earliest = INF; var normal = Vector2.ZERO
	for i in pit.polygon.size():
		var a: Vector2 = pit.polygon[i]; var b: Vector2 = pit.polygon[(i + 1) % pit.polygon.size()]
		var n: Vector2 = pit.normals[i]
		var speed = n.dot(delta)
		if speed < -0.0000001:
			var time = (radius - n.dot(start - a)) / speed
			if time >= 0 and time <= 1 and time < earliest:
				var edge = b - a
				var along = (start + delta * time - n * radius - a).dot(edge) / edge.length_squared()
				if along >= 0 and along <= 1: earliest = time; normal = n
		var offset = start - a
		var projection = offset.dot(delta)
		var discriminant = projection * projection - squared * (offset.length_squared() - radius * radius)
		if discriminant < 0: continue
		var time = (-projection - sqrt(discriminant)) / squared
		if time >= 0 and time <= 1 and time < earliest:
			earliest = time; normal = (start + delta * time - a).normalized()
	return {"time": earliest, "normal": normal, "pit": pit} if earliest <= 1 else {}

func nearby(area: Rect2) -> Array:
	# All legacy pits in cave mode are outside the protected first chambers.
	# Their maximum painted radius is below 620px; centers are beyond 1850px.
	# Avoid recreating/filtering those distant definitions for every swarm move.
	if not enabled: return super.nearby(area)
	if area.position.abs().max(area.end.abs()).length_squared() < 1000 * 1000: return []
	# All five opening centers are inside the cave's 1700px exclusion. The
	# remaining pit set depends only on this procedural grid rectangle. Reuse
	# its exact ordered geometry for orbiting map guards and repeated sweeps.
	var search: Rect2 = area.grow(620)
	var low: Vector2i = Vector2i(((search.position-Vector2(430,270))/1450).floor())
	var high: Vector2i = Vector2i(((search.end-Vector2(430,270))/1450).floor())
	var key = Vector4i(low.x,low.y,high.x,high.y)
	if legacy_regions.has(key): return legacy_regions[key]
	var result: Array = []
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var point = Vector2(x,y)*1450+Vector2(430,270)
			if point.length()<1850: continue
			var pit_seed = absi(x*73856093 ^ y*19349663)
			if pit_seed%3==0: continue
			result.append(shape("%d:%d"%[x,y],point,.85+(pit_seed%5)*.09,float(pit_seed%17)*.23))
	if legacy_regions.size()>=256: legacy_regions.erase(legacy_regions.keys()[0])
	legacy_regions[key] = result
	return result

func collision_row(y: int, left: int, right: int) -> Array:
	# Only the exposed contour can stop an outside body. Interior tessellation
	# edges are for rendering/penetration recovery, not a second physical wall.
	var key = Vector3i(left, right, y)
	if collision_rows.has(key): return collision_rows[key]
	var edges: Array = []
	for x in range(left, right + 1):
		var outline: PackedVector2Array = cell_shape(Vector2i(x, y)).outline
		for i in range(0, outline.size(), 2):
			var a = outline[i]; var b = outline[i + 1]; var delta = b - a
			var edge=ContourEdge.new(a,Vector2i(x,y))
			edge.b=b;edge.delta=delta;edge.length_squared=delta.length_squared()
			edge.normal=Vector2(delta.y,-delta.x).normalized();edge.bounds=Rect2(a,Vector2.ZERO).expand(b)
			edges.append(edge)
	if collision_rows.size() >= 2048:
		var oldest = collision_rows.keys()
		for i in 128: collision_rows.erase(oldest[i])
	collision_rows[key] = edges
	return edges

func wall_blocked(point: Vector2, radius: float = 0.0) -> bool:
	if not enabled: return false
	# Rock only shrinks between resets. A previously clear exact footprint
	# remains clear, including a head/guard held at the same wall contact.
	# Keep radius as a full-precision dictionary key, not a quantized Vector3.
	if use_clearance_cache and clear_points.has(radius) and clear_points[radius].has(point):return false
	# A center already inside rock is blocked even when its entire query lies
	# deep inside a solid region, far from the external contour.
	var center_low = Vector2i(((point - Vector2.ONE * 6) / CELL).floor())
	var center_high = Vector2i(((point + Vector2.ONE * 6) / CELL).floor())
	for y in range(center_low.y, center_high.y + 1):
		for x in range(center_low.x, center_high.x + 1):
			for piece in cell_shape(Vector2i(x, y)).pieces:
				if contains(piece, point, 0): return true
	if radius > 0:
		var low = Vector2i(((point - Vector2.ONE * (radius + 6)) / CELL).floor())
		var high = Vector2i(((point + Vector2.ONE * (radius + 6)) / CELL).floor())
		for y in range(low.y, high.y + 1):
			for item:ContourEdge in collision_row(y, low.x, high.x):
				if item.bounds.grow(radius).has_point(point) and Geometry2D.get_closest_point_to_segment(point, item.a, item.b).distance_squared_to(point) <= radius * radius: return true
	if use_clearance_cache:
		if clear_point_count>=8192:clear_points.clear();clear_point_count=0
		if not clear_points.has(radius):clear_points[radius]={}
		clear_points[radius][point]=true;clear_point_count+=1
	return false

func blocked(point: Vector2, radius: float = 0.0) -> bool:
	return wall_blocked(point, radius) or super.blocked(point, radius)

func wall_hit(start: Vector2, finish: Vector2, radius: float = 0.0) -> Dictionary:
	if not enabled: return {}
	var area = Rect2(start, Vector2.ZERO).expand(finish).grow(radius + 6)
	var low = Vector2i((area.position / CELL).floor())
	var high = Vector2i((area.end / CELL).floor())
	var delta:Vector2=finish-start
	var squared:float=delta.length_squared()
	if squared<0.0000000001:return {}
	if use_sweep_neighborhoods and radius<=512 and squared<=LOCAL_SWEEP_DISTANCE*LOCAL_SWEEP_DISTANCE:
		return local_wall_hit(start,finish,radius,delta,squared)
	var query:Rect2=Rect2(start,Vector2.ZERO).expand(finish).grow(radius+.8)
	var earliest:float=INF
	var closest:ContourEdge
	var closest_row=2147483647
	var delta_y:float=finish.y-start.y
	var reverse_rows=use_sweep_clipping and delta_y<0
	for row in range(high.y-low.y+1):
		var y:int=high.y-row if reverse_rows else low.y+row
		var limit=minf(1,earliest) if use_sweep_clipping else 1.0
		if use_sweep_clipping and absf(delta_y)>.0001:
			# A nearer contact makes rows beyond its expanded footprint irrelevant.
			# Visit in travel order, with a conservative cell/jitter/radius margin.
			var minimum_time=((float(y+1)*CELL+radius+6-start.y) if reverse_rows else (float(y)*CELL-radius-6-start.y))/delta_y
			if minimum_time>limit+.0000001:break
		# Restrict each row to the swept corridor. A long diagonal ray must not
		# inspect every rock in its entire rectangular bounding box.
		var row_low = low.x
		var row_high = high.x
		if absf(delta_y) > 0.0001:
			var a = (float(y) * CELL - radius - 6 - start.y) / delta_y
			var b = (float(y + 1) * CELL + radius + 6 - start.y) / delta_y
			var enter = clampf(minf(a, b), 0, limit)
			var leave = clampf(maxf(a, b), 0, limit)
			var left = lerpf(start.x, finish.x, enter)
			var right = lerpf(start.x, finish.x, leave)
			row_low = floori((minf(left, right) - radius - 6) / CELL)
			row_high = floori((maxf(left, right) + radius + 6) / CELL)
		elif use_sweep_clipping and limit<1:
			var clipped_x=start.x+delta.x*limit
			row_low=floori((minf(start.x,clipped_x)-radius-6)/CELL)
			row_high=floori((maxf(start.x,clipped_x)+radius+6)/CELL)
		for item:ContourEdge in collision_row(y, row_low, row_high):
			if not item.bounds.intersects(query):continue
			var time:float=contour_time(item,start,delta,squared,radius)
			# Keep the original ascending-row winner for exact-time corner ties.
			if time<earliest or (closest!=null and time==earliest and y<closest_row):earliest=time;closest=item;closest_row=y
	if closest==null:return {}
	var position:Vector2=start+delta*earliest
	var contact:Vector2=Geometry2D.get_closest_point_to_segment(position,closest.a,closest.b)
	var normal:Vector2=(position-contact).normalized() if radius>0 else closest.normal
	return {"time":earliest,"normal":normal,"cell":closest.cell,"position":position}

func local_sweep_edges(start:Vector2,radius:float,distance:float)->Array:
	var tile=Vector3i(floori(start.x/SWEEP_NEIGHBORHOOD_STEP),floori(start.y/SWEEP_NEIGHBORHOOD_STEP),int(distance))
	if sweep_neighborhoods.has(radius) and sweep_neighborhoods[radius].has(tile):return sweep_neighborhoods[radius][tile].edges
	# Every <=8px sweep from this cell fits in this conservative disk. Retain
	# only edges that can intersect its moving circumference, in original order.
	# Large boss footprints otherwise scan dozens of rows of irrelevant edges
	# on every tiny slide along the same wall.
	var center=(Vector2(tile.x,tile.y)+Vector2.ONE*.5)*SWEEP_NEIGHBORHOOD_STEP
	var margin=SWEEP_NEIGHBORHOOD_STEP*sqrt(.5)+distance+.01
	var outer=radius+margin;var inner=maxf(0,radius-margin)
	var low=Vector2i(((center-Vector2.ONE*(outer+6))/CELL).floor())
	var high=Vector2i(((center+Vector2.ONE*(outer+6))/CELL).floor())
	var edges:Array=[]
	for y in range(low.y,high.y+1):
		for edge:ContourEdge in collision_row(y,low.x,high.x):
			if Geometry2D.get_closest_point_to_segment(center,edge.a,edge.b).distance_squared_to(center)>outer*outer:continue
			# An edge wholly inside the circle for every start cannot yield an
			# entering contact. Penetration recovery still uses wall_blocked.
			if inner>0 and center.distance_squared_to(edge.a)<inner*inner and center.distance_squared_to(edge.b)<inner*inner:continue
			edges.append(edge)
	if sweep_neighborhood_order.size()>=SWEEP_NEIGHBORHOOD_LIMIT:
		var oldest:Array=sweep_neighborhood_order.pop_front()
		sweep_neighborhoods[oldest[0]].erase(oldest[1])
		if sweep_neighborhoods[oldest[0]].is_empty():sweep_neighborhoods.erase(oldest[0])
	if not sweep_neighborhoods.has(radius):sweep_neighborhoods[radius]={}
	sweep_neighborhoods[radius][tile]={"edges":edges,"bounds":Rect2i(low,high-low+Vector2i.ONE)}
	sweep_neighborhood_order.append([radius,tile])
	return edges

func local_wall_hit(start:Vector2,finish:Vector2,radius:float,delta:Vector2,squared:float)->Dictionary:
	var query=Rect2(start,Vector2.ZERO).expand(finish).grow(radius+.8)
	var earliest:float=INF
	var closest:ContourEdge
	var distance=1.0 if squared<=1 else (2.0 if squared<=4 else (4.0 if squared<=16 else LOCAL_SWEEP_DISTANCE))
	for edge:ContourEdge in local_sweep_edges(start,radius,distance):
		if not edge.bounds.intersects(query):continue
		var time:float=contour_time(edge,start,delta,squared,radius)
		if time<earliest:earliest=time;closest=edge
	if closest==null:return {}
	var position:Vector2=start+delta*earliest
	var contact:Vector2=Geometry2D.get_closest_point_to_segment(position,closest.a,closest.b)
	var normal:Vector2=(position-contact).normalized() if radius>0 else closest.normal
	return {"time":earliest,"normal":normal,"cell":closest.cell,"position":position}

func contour_time(edge:ContourEdge,start:Vector2,delta:Vector2,squared:float,radius:float)->float:
	# Keep the same face/circular-corner sweep, but allocate one hit dictionary
	# for the winning contact. Static types avoid Variant math on every edge.
	var earliest:float=INF
	var n: Vector2 = edge.normal
	var speed:float = n.dot(delta)
	if speed < -0.0000001:
		var time:float = (radius - n.dot(start - edge.a)) / speed
		if time >= 0 and time <= 1:
			var along:float = (start + delta * time - n * radius - edge.a).dot(edge.delta) / edge.length_squared
			if along >= 0 and along <= 1: earliest = time
	if radius > 0:
		for i in 2:
			var vertex:Vector2=edge.a if i==0 else edge.b
			# The native helper also reports exit contacts for inside starts; the
			# movement sweep only accepts the entering root, as before.
			if start.distance_squared_to(vertex)<radius*radius:continue
			var time:float=Geometry2D.segment_intersects_circle(start,start+delta,vertex,radius)
			if time >= 0 and time <= 1 and time < earliest: earliest = time
	return earliest

func move(start: Vector2, desired: Vector2, radius: float) -> Vector2:
	if not enabled:return super.move(start,desired,radius)
	# A verified empty disk contains every straight motion between its points.
	# Cache a conservative disk around a 16px cell, including a subpixel skin;
	# open-space movement then needs no repeated overlap/sweep queries. Close
	# wall contact retains the exact contour solver below.
	var free_key=Vector3i(floori(start.x/move_certificate_step),floori(start.y/move_certificate_step),ceili(radius/8.0)*8)
	var free_center=(Vector2(free_key.x,free_key.y)+Vector2.ONE*.5)*move_certificate_step
	if radius<=64 and desired.distance_squared_to(free_center)<=move_certificate_step*move_certificate_step:
		if not free_regions.has(free_key):
			if free_regions.size()>=8192:
				var oldest=free_regions.keys()
				for i in 128:
					var old:Vector3i=oldest[i]
					if not free_regions[old]:
						var tile=Vector2i(old.x,old.y)
						blocked_free_regions[tile].erase(old.z)
						if blocked_free_regions[tile].is_empty():blocked_free_regions.erase(tile)
					free_regions.erase(old)
			free_regions[free_key]=not blocked(free_center,float(free_key.z)+move_certificate_step+.5)
			if not free_regions[free_key]:
				var tile=Vector2i(free_key.x,free_key.y)
				if not blocked_free_regions.has(tile):blocked_free_regions[tile]={}
				blocked_free_regions[tile][free_key.z]=true
			free_radii[free_key.z]=true
		if free_regions[free_key]:return desired
	return move_contour(start,desired,radius)

func move_contour(start:Vector2,desired:Vector2,radius:float)->Vector2:
	var legacy_area=Rect2(start,Vector2.ZERO).expand(desired).grow(radius*2)
	var destination=desired if legacy_area.position.abs().max(legacy_area.end.abs()).length_squared()<1000*1000 else super.move(start,desired,radius)
	var point = start
	var remaining = destination - start
	# Consecutive slides at an irregular corner can end a fraction inside an
	# adjacent expanded face. Resolve that tiny overlap before the next sweep.
	if wall_blocked(point, radius):
		var lip=separate_lip(point,radius)
		if lip!=Vector2.INF:point=lip
		else:
			var shapes: Array = []
			var low = Vector2i(((point - Vector2.ONE * (radius + CELL)) / CELL).floor())
			var high = Vector2i(((point + Vector2.ONE * (radius + CELL)) / CELL).floor())
			for y in range(low.y, high.y + 1):
				for x in range(low.x, high.x + 1):shapes.append_array(cell_shape(Vector2i(x,y)).pieces)
			var clear = safe_among(point, radius, shapes)
			if point.distance_squared_to(clear) < CELL * CELL: point = clear
	for iteration in 3:
		if remaining.length_squared() < 0.0000001: break
		var hit = wall_hit(point, point + remaining, radius)
		if hit.is_empty(): point += remaining; break
		var travel = maxf(0, float(hit.time) - 0.35 / maxf(0.35, remaining.length()))
		point += remaining * travel
		remaining *= 1.0 - travel
		var normal: Vector2 = hit.normal
		remaining -= normal * minf(0, remaining.dot(normal))
	return point

func separate_lip(point:Vector2,radius:float)->Vector2:
	# Repair subpixel lip overlap against the exposed boundary, rather than
	# oscillating through internal tessellation faces. Accept only <=2px moves
	# that pass the complete original clearance query; deeper recovery retains
	# the filled-polygon solver above.
	var low=Vector2i(((point-Vector2.ONE*(radius+6))/CELL).floor())
	var high=Vector2i(((point+Vector2.ONE*(radius+6))/CELL).floor())
	var best=Vector2.INF;var distance=4.0
	for y in range(low.y,high.y+1):
		for edge:ContourEdge in collision_row(y,low.x,high.x):
			var contact=Geometry2D.get_closest_point_to_segment(point,edge.a,edge.b)
			var normal=(point-contact).normalized()
			if normal.dot(edge.normal)<=0:normal=edge.normal
			var candidate=contact+normal*(radius+.4)
			var squared=candidate.distance_squared_to(point)
			if squared<distance and not wall_blocked(candidate,radius):best=candidate;distance=squared
	return best

func chamber_candidates(point:Vector2,radius:float)->Array[Vector2]:
	# Whole enemy formations can be much wider than a corridor. Searching 720
	# concentric probes for each new map node caused quarter-second stalls.
	# Try nearby chamber interiors first, then verify the full circular footprint
	# against the same exact rock/legacy collisions before accepting a placement.
	var candidates:Array[Vector3]=[Vector3(-80,0,280),Vector3(760,0,230)]
	var region=Vector2i((point/ROOM_STEP).floor())
	for y in range(-1,3):
		for x in range(-1,3):
			var id=region+Vector2i(x,y)
			if id in [Vector2i.ZERO,Vector2i.RIGHT]:continue
			var n=noise_id(id,713)
			var room=room_at(id)
			candidates.append(Vector3(room.x,room.y,minf(335+n%70,290+(n/73)%65)-20))
	var chamber_points:Array[Vector2]=[]
	for entry:Vector3 in candidates:
		if radius>entry.z:continue
		var center=Vector2(entry.x,entry.y)
		# Invert the generation warp; the final physical check remains decisive.
		var candidate=center
		for i in 3:
			var warp=Vector2(sin(candidate.y*.013)*26+sin(candidate.y*.027+candidate.x*.011)*12,sin(candidate.x*.009)*25+sin(candidate.x*.019-candidate.y*.012)*13)
			candidate=center-warp
		var toward=point-candidate
		candidate+=toward.limit_length(maxf(0,entry.z-radius-30))
		chamber_points.append(candidate)
	chamber_points.sort_custom(func(a,b):return a.distance_squared_to(point)<b.distance_squared_to(point))
	return chamber_points

func safe_position(point: Vector2, radius: float) -> Vector2:
	if not enabled: return super.safe_position(point, radius)
	if not blocked(point, radius): return point
	for candidate:Vector2 in chamber_candidates(point,radius):
		if not blocked(candidate,radius):return candidate
	# Search close rings first; preserve whole-prefab formation footprints.
	for ring in range(1, 37):
		for i in 20:
			var candidate = point + Vector2.from_angle(float(i) * TAU / 20.0) * ring * 48.0
			if not blocked(candidate, radius): return candidate
	return super.safe_position(point, radius)

func prepare_placement(memory:Dictionary,requested:Vector2,radius:float)->bool:
	# New map columns are several chambers offscreen. Warm one small batch of
	# their exact placement geometry per frame before spawning a whole prefab.
	if memory.is_empty():
		var candidates:Array[Vector2]=[requested]
		candidates.append_array(chamber_candidates(requested,radius))
		memory.candidates=candidates;memory.which=0;memory.cursor=-1
	if memory.which>=memory.candidates.size():
		memory.point=requested;memory.split=true;memory.revision=revision
		return true
	var at:Vector2=memory.candidates[memory.which]
	if memory.cursor<0:
		if wall_blocked(at):memory.which+=1;return false
		memory.low=Vector2i(((at-Vector2.ONE*(radius+6))/CELL).floor())
		memory.high=Vector2i(((at+Vector2.ONE*(radius+6))/CELL).floor())
		memory.cursor=0
	var width:int=memory.high.x-memory.low.x+1
	var count:int=width*(memory.high.y-memory.low.y+1)
	if memory.cursor<count:
		var began=Time.get_ticks_usec()
		while memory.cursor<count:
			var index=int(memory.cursor)
			cell_shape(Vector2i(memory.low)+Vector2i(index%width,index/width));memory.cursor+=1
			if Time.get_ticks_usec()-began>=750:break
		return false
	if not blocked(at,radius):
		memory.point=at;memory.radius=radius;memory.revision=revision
		return true
	memory.which+=1;memory.cursor=-1
	return false

func clear_segment(start: Vector2, finish: Vector2, radius: float = 0.0) -> bool:
	if not enabled: return super.clear_segment(start, finish, radius)
	# One continuous sweep shares the movement contour, instead of repeating a
	# circle/rock overlap query every 22px along the same route.
	if wall_blocked(start,radius) or wall_blocked(finish,radius) or not wall_hit(start,finish,radius).is_empty():return false
	return super.clear_segment(start, finish, radius)

func ray_clear(start: Vector2, finish: Vector2) -> bool:
	if not enabled: return true
	return not wall_blocked(start) and not wall_blocked(finish) and wall_hit(start,finish).is_empty()

func dig(point: Vector2, intent: Vector2, facing: Vector2, radius: float, dt: float, strong: bool = false):
	mining_active = false
	if not enabled or dt <= 0 or intent.length_squared() < 0.05:
		bite_timer = 0; return
	var direction = intent.normalized()
	if facing.dot(direction) < 0.4: bite_timer = 0; return
	# Start outside the same swept footprint used by movement. Expanding the
	# radius here would put a resting head inside the wall and hide its first hit.
	var hit = wall_hit(point, point + direction * 12.0, radius)
	# A shallow fractured lip can still stop forward travel. Accept every
	# approaching face; only a tangent or receding side wall should not chew.
	if hit.is_empty() or Vector2(hit.normal).dot(direction) >= -0.001:
		bite_timer = 0; return
	mining_active = true
	mining_point = point + direction * (radius + 10)
	bite_timer += minf(dt, 0.1)
	if bite_timer < BITE_INTERVAL: return
	bite_timer -= BITE_INTERVAL; bite_serial += 1
	var low = Vector2i(((point - Vector2.ONE * 82) / CELL).floor())
	var high = Vector2i(((point + Vector2.ONE * 82) / CELL).floor())
	var removed = 0
	var changed_low=Vector2i.MAX;var changed_high=Vector2i.MIN
	# A rounded mouth footprint tapers the end of a bite. A small continuous
	# variation in width keeps a long excavation from becoming a square slot.
	var width = 55.0 + sin(point.x * 0.028 + point.y * 0.023) * 3.0
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell = Vector2i(x, y)
			if not solid(cell): continue
			var offset = (Vector2(cell) + Vector2.ONE * 0.5) * CELL - point
			var forward = offset.dot(direction)
			var sideways = absf(offset.cross(direction))
			var brush = Vector2((forward - 28.0) / 43.0, sideways / width)
			if forward < 4 or brush.length_squared() > 1.0: continue
			var data = chunk_at(chunk_id(cell))
			var index = cell_index(cell)
			var health = durability(cell)
			var damage = mini(health, int(data.damage.get(index, 0)) + (2 if strong else 1))
			data.damage[index] = damage; data.damage_version += 1
			var value = 2 if ore(cell) > 0 else 0
			var paid = int(data.paid.get(index, 0))
			var earned = floori(float(damage * value) / health)
			if earned > paid:
				var drop = point - direction * 10 + direction.orthogonal() * float((noise_id(cell) % 21) - 10)
				loot_events.append({"position": drop, "value": earned - paid, "pack": false, "cave_ore": true})
				ore_total += earned - paid; data.paid[index] = earned
			if damage >= health:
				data.solid[index] = 0; data.damage.erase(index)
				data.version += 1
				removed += 1; removed_count += 1
				# Opening either side of a corner also changes its curve. Refresh
				# the shared collision/paint contour, including diagonal chunks.
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var neighbor_cell = cell + Vector2i(dx, dy)
						changed_low=changed_low.min(neighbor_cell);changed_high=changed_high.max(neighbor_cell)
						geometry.erase(neighbor_cell)
						var patch=Vector2i((Vector2(neighbor_cell)/DRAW_PATCH).floor())
						patch_versions[patch]=int(patch_versions.get(patch,0))+1
						var neighbor_id = chunk_id(neighbor_cell)
						if neighbor_id != chunk_id(cell) and chunks.has(neighbor_id): chunks[neighbor_id].version += 1
	if removed > 0:
		for key:Vector3i in collision_rows.keys():
			if key.z>=changed_low.y and key.z<=changed_high.y and key.x<=changed_high.x and key.y>=changed_low.x:collision_rows.erase(key)
		var changed=Rect2i(changed_low,changed_high-changed_low+Vector2i.ONE)
		for i in range(sweep_neighborhood_order.size()-1,-1,-1):
			var key:Array=sweep_neighborhood_order[i]
			if not sweep_neighborhoods[key[0]][key[1]].bounds.intersects(changed):continue
			sweep_neighborhoods[key[0]].erase(key[1]);sweep_neighborhood_order.remove_at(i)
			if sweep_neighborhoods[key[0]].is_empty():sweep_neighborhoods.erase(key[0])
		# Excavation only removes material: certified empty disks stay valid.
		# Only previously blocked disks near this bite can change their answer.
		var free_low=Vector2i(((Vector2(changed_low)*CELL-Vector2.ONE*104)/move_certificate_step).floor())
		var free_high=Vector2i(((Vector2(changed_high+Vector2i.ONE)*CELL+Vector2.ONE*104)/move_certificate_step).floor())
		for y in range(free_low.y,free_high.y+1):
			for x in range(free_low.x,free_high.x+1):
				var tile=Vector2i(x,y)
				if not blocked_free_regions.has(tile):continue
				for radius_bucket in blocked_free_regions[tile]:free_regions.erase(Vector3i(x,y,radius_bucket))
				blocked_free_regions.erase(tile)
		revision += 1
		# Existing A* regions update only near the bite, not across the whole map.
		invalidate_navigation(point, 160.0)
	events.append({"position": mining_point, "normal": -direction, "serial": bite_serial, "broken": removed > 0})

func nav_passable(id: Vector2i, radius: int) -> bool:
	var key = Vector3i(id.x, id.y, radius)
	if nav_open.size() > 60000: nav_open.clear()
	if not nav_open.has(key): nav_open[key] = not blocked((Vector2(id) + Vector2.ONE * 0.5) * NAV_STEP, radius)
	return nav_open[key]

func navigation(target: Vector2, radius: float) -> Dictionary:
	var bucket = ceili(maxf(8, radius) / 8.0) * 8
	var goal = Vector2i((target / NAV_STEP).floor())
	if not nav_grids.has(bucket) or not Rect2i(nav_grids[bucket].region).grow(-12).has_point(goal):
		var grid = AStarGrid2D.new()
		var region = Rect2i(goal - Vector2i(40, 40), Vector2i(81, 81))
		grid.region = region; grid.cell_size = Vector2.ONE * NAV_STEP; grid.offset = Vector2.ONE * NAV_STEP * 0.5
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()
		# Unknown cells remain blocked until checked. Preparing all 6,561 cells
		# synchronously used to freeze the first enemy that needed a detour.
		grid.fill_solid_region(region, true)
		nav_grids[bucket] = {"grid": grid, "region": region, "radius": bucket, "filled": {},"preparing":{},"prepared":{}}
	return nav_grids[bucket]

func prepare_navigation(data: Dictionary, origin: Vector2, target: Vector2, margin: int) -> bool:
	var start = Vector2i((origin / NAV_STEP).floor())
	var goal = Vector2i((target / NAV_STEP).floor())
	var low = start.min(goal); var high = start.max(goal)
	var wanted = Rect2i(low, high - low + Vector2i.ONE).grow(margin).intersection(data.region)
	if data.prepared.has(wanted):return true
	var cursor=int(data.preparing.get(wanted,0))
	var count=wanted.size.x*wanted.size.y
	while cursor<count:
		if nav_budget_active and (nav_cells_left<=0 or nav_prepare_us>=NAV_PREPARE_USEC):data.preparing[wanted]=cursor;return false
		var id=wanted.position+Vector2i(cursor%wanted.size.x,cursor/wanted.size.x)
		cursor+=1
		if data.filled.has(id):continue
		var began=Time.get_ticks_usec()
		data.grid.set_point_solid(id,not nav_passable(id,data.radius))
		data.filled[id]=true;nav_cells_left-=1
		nav_prepare_us+=Time.get_ticks_usec()-began
	data.preparing.erase(wanted)
	if data.prepared.size()>=256:data.prepared.clear()
	data.prepared[wanted]=true
	return true

func invalidate_navigation(point: Vector2, reach: float):
	for data in nav_grids.values():
		data.prepared.clear();data.preparing.clear()
		var low = Vector2i(((point - Vector2.ONE * (reach + data.radius)) / NAV_STEP).floor())
		var high = Vector2i(((point + Vector2.ONE * (reach + data.radius)) / NAV_STEP).floor())
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var id = Vector2i(x, y)
				nav_open.erase(Vector3i(x, y, data.radius))
				# Reopen dirty clearance cells through the existing per-frame budget.
				# A bite must not synchronously test hundreds of circles for every
				# actor radius. Movement still sweeps the actual rock each tick.
				if data.filled.has(id):
					data.filled.erase(id);data.grid.set_point_solid(id,true)

func nearest_nav(id: Vector2i, data: Dictionary) -> Vector2i:
	if data.region.has_point(id) and not data.grid.is_point_solid(id): return id
	for ring in range(1, 9):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring: continue
				var candidate = id + Vector2i(x, y)
				if data.region.has_point(candidate) and not data.grid.is_point_solid(candidate): return candidate
	return Vector2i(2147483647, 2147483647)

func begin_navigation_frame(dt: float = 1.0 / 60):
	# A removed wall cannot obstruct an existing route. Let the swarm keep its
	# verified routes while a few actors per tick discover the new shortcut.
	nav_budget_active = true; nav_replans = 0; nav_cells_left = NAV_CELLS_PER_FRAME
	nav_prepare_us=0
	nav_clock_ms += maxf(0, dt) * 1000.0
	nav_frame += 1
	# Drop requests belonging to actors that died or stopped navigating.
	for ticket in nav_waiting.keys():
		if nav_frame - int(nav_waiting[ticket]) > 2: nav_waiting.erase(ticket)
	advance_navigation_queue()

func advance_navigation_queue():
	while nav_ticket_head < nav_ticket_serial and not nav_waiting.has(nav_ticket_head): nav_ticket_head += 1

func follow_route(origin: Vector2, target: Vector2, memory: Dictionary) -> Vector2:
	var path: PackedVector2Array = memory.get("cave_path", PackedVector2Array())
	while path.size() > 0 and origin.distance_squared_to(path[0]) < 24 * 24: path.remove_at(0)
	memory.cave_path = path
	if path.size() > 0: return origin.direction_to(path[0])
	if memory.get("cave_visible", false): return origin.direction_to(target)
	return Vector2.ZERO

func visibility_ready(origin:Vector2,target:Vector2,radius:float)->bool:
	var area=Rect2(origin,Vector2.ZERO).expand(target).grow(radius+6)
	var low=Vector2i((area.position/CELL).floor());var high=Vector2i((area.end/CELL).floor())
	if (high.x-low.x+1)*(high.y-low.y+1)>4096:return false
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			if not geometry.has(Vector2i(x,y)):return false
	return true

func direction(origin: Vector2, target: Vector2, radius: float, memory: Dictionary) -> Vector2:
	if not enabled: return super.direction(origin, target, radius, memory)
	if origin.distance_squared_to(target)>LOCAL_NAV_RANGE*LOCAL_NAV_RANGE:
		# A map guard several chambers away cannot use the player's 81x81 local
		# grid. Casting its entire 9,000px route generated cold rock for hundreds
		# of milliseconds. Steer around the nearby wall until within local A*;
		# positions, collisions, weapon timers and damage still update every tick.
		if memory.has("cave_far_direction") and nav_clock_ms<float(memory.get("cave_far_until",0)) and origin.distance_squared_to(memory.cave_far_origin)<24*24:
			return memory.cave_far_direction
		var toward=origin.direction_to(target)
		var finish=origin+toward*72
		var hit=wall_hit(origin,finish,radius+1)
		var legacy=first_hit(origin,finish,radius+1,nearby(Rect2(origin,Vector2.ZERO).expand(finish).grow(radius*2)))
		if not legacy.is_empty() and (hit.is_empty() or legacy.time<hit.time):hit=legacy
		if not hit.is_empty():
			var normal:Vector2=hit.normal
			var tangent=normal.orthogonal()
			if tangent.dot(toward)<0:tangent=-tangent
			toward=(tangent+normal*.25).normalized()
		var steering=toward
		memory.cave_far_direction=steering;memory.cave_far_origin=origin;memory.cave_far_until=nav_clock_ms+220
		var ticket=int(memory.get("cave_ticket",-1))
		if nav_waiting.has(ticket):nav_waiting.erase(ticket);memory.erase("cave_ticket");advance_navigation_queue()
		return steering
	# Most actors share the player goal and a small set of clearance sizes.
	var tick = nav_clock_ms
	var cached = int(memory.get("cave_revision", -1)) == revision and float(memory.get("cave_radius", -1)) == radius and Vector2(memory.get("cave_target", Vector2.INF)).distance_squared_to(target) < 96 * 96
	var following = follow_route(origin, target, memory)
	if cached and tick < int(memory.get("cave_until", 0)) and (not following.is_zero_approx() or memory.get("cave_no_route", false) or origin.distance_squared_to(target) < 24 * 24): return following
	if nav_budget_active:
		# FIFO requests also serve large swarms where early actors' routes expire
		# before the last actor has received its first plan.
		if not nav_waiting.has(int(memory.get("cave_ticket", -1))):
			memory.cave_ticket = nav_ticket_serial; nav_ticket_serial += 1
		nav_waiting[memory.cave_ticket] = nav_frame
		if nav_replans >= NAV_REPLANS_PER_FRAME or int(memory.cave_ticket) != nav_ticket_head: return following
	nav_replans += 1; nav_serial += 1
	var path = PackedVector2Array()
	if visibility_ready(origin,target,radius+1) and clear_segment(origin, target, radius + 1):
		# Swept movement still checks collisions each tick. Rechecking this long
		# line for every actor every tick just repeats the same clearance work.
		memory.cave_visible = true
	else:
		var data = navigation(target, radius + 2)
		var margin = int(memory.get("cave_margin", 8))
		if not prepare_navigation(data, origin, target, margin): return following
		memory.cave_visible = false
		var start = nearest_nav(Vector2i((origin / NAV_STEP).floor()), data)
		var goal = nearest_nav(Vector2i((target / NAV_STEP).floor()), data)
		path = PackedVector2Array()
		if start.x != 2147483647 and goal.x != 2147483647:
			path = data.grid.get_point_path(start, goal)
			while path.size() > 0 and origin.distance_squared_to(path[0]) < 24 * 24: path.remove_at(0)
			# Skip waypoints only where the actor's complete footprint fits.
			# Bound smoothing too: repeatedly extending the same ray all the way
			# to a distant goal bypassed the cell budget and rebuilt cold geometry.
			if path.size()>3 and clear_segment(origin,path[3],radius+1):
				for i in 3:path.remove_at(0)
			elif path.size()>1 and clear_segment(origin,path[1],radius+1):path.remove_at(0)
		# A long wall may need a wider detour than the first local search. Grow
		# it on a later retry using the same preparation budget.
		memory.cave_margin = mini(40, margin + 8) if path.is_empty() else 8
	memory.cave_path = path; memory.cave_revision = revision; memory.cave_radius = radius; memory.cave_target = target
	memory.cave_no_route = path.is_empty() and not memory.cave_visible
	memory.cave_until = tick + 300 + (nav_serial * 73) % 225
	if nav_budget_active:
		nav_waiting.erase(int(memory.cave_ticket)); memory.erase("cave_ticket"); advance_navigation_queue()
	return follow_route(origin, target, memory)
