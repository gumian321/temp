extends RefCounted
## Ordered broad phase. Keep dead actors and array order: splash and ties depend on both.
const CELL = 256.0
const Mineral = preload("res://scripts/mineral_erosion.gd")
var cells: Dictionary = {}
var actors: Array = []
var locations: Dictionary = {}
var by_uid: Dictionary = {}
var shield_actors: Array = []
var allies: Array = []
var max_radius = 0.0
var extent_low = Vector2.ZERO
var extent_high = Vector2.ZERO
var query_cache:Dictionary={}
const MAX_QUERIES=128
var use_query_cache=OS.get_environment("RBPEW_LEGACY_QUERY_CACHE")!="1"
var use_cell_reuse=OS.get_environment("RBPEW_ENABLE_SPATIAL_CELL_REUSE")=="1" and OS.get_environment("RBPEW_LEGACY_SPATIAL_CELL_REUSE")!="1"
var actor_refs:Array=[]
var uid_sequence:Array=[]
var validated_count=-1
var full_rebuilds=0
var reuse_frames=0
var use_spatial_build=OS.get_environment("RBPEW_ENABLE_SPATIAL_BUILD")!="0" and OS.get_environment("RBPEW_LEGACY_SPATIAL_BUILD")!="1"

func rebuild(source: Array, db):
	if use_cell_reuse and can_reuse_cells(source):
		reuse_cells(source,db);reuse_frames+=1;return
	full_rebuilds+=1
	query_cache.clear()
	cells.clear(); locations.clear(); by_uid.clear(); shield_actors.clear(); allies.clear()
	actors = source
	max_radius = 0.0
	var shield_classes:Dictionary={}
	for i in source.size():
		var e: Dictionary = source[i]
		by_uid[e.uid] = i
		max_radius = maxf(max_radius, Mineral.bounds_radius(e,db) if e.get("kind","")=="Asteroid" else float(e.radius))
		if e.role == "friendly": allies.append(e)
		for gun in e.guns:
			var shield_class
			if use_spatial_build:
				shield_class=shield_classes.get(gun.id)
				if shield_class==null:
					shield_class=db.asset(gun.id).get("class")=="ShieldCore"
					shield_classes[gun.id]=shield_class
			else:shield_class=db.asset(gun.id).get("class")=="ShieldCore"
			if shield_class:
				shield_actors.append(e); break
		if use_spatial_build:
			# rebuild() has already cleared every query and membership bucket.
			# Keep insert's coordinate expression, bucket order and exact extents.
			var at:Vector2=e.position
			var cell=Vector2i((at/CELL).floor())
			if not cells.has(cell):cells[cell]=[]
			cells[cell].append(i)
			locations[i]=cell
			if i==0:extent_low=at;extent_high=at
			else:extent_low=extent_low.min(at);extent_high=extent_high.max(at)
		else:insert(i, e.position)
	if use_cell_reuse:
		# Copy the container, retaining each live Dictionary identity. Cleanup
		# may produce a new Array every frame; its ordered actors are what count.
		# Capture once after a fallback, without adding work inside the normal
		# metadata loop when this optional experiment is disabled.
		actor_refs=source.duplicate();uid_sequence.resize(source.size());validated_count=source.size()
		for i in source.size():uid_sequence[i]=source[i].uid
	elif validated_count>=0:
		actor_refs.clear();uid_sequence.clear();validated_count=-1

func can_reuse_cells(source:Array)->bool:
	var count=source.size()
	if count!=validated_count or count!=actor_refs.size() or count!=uid_sequence.size() or count!=by_uid.size() or count!=locations.size():return false
	for i in count:
		var e:Dictionary=source[i]
		if not is_same(e,actor_refs[i]) or not is_same(e.uid,uid_sequence[i]) or by_uid.get(e.uid,-1)!=i or not locations.has(i):return false
	return true

func reuse_cells(source:Array,db):
	actors=source
	# Membership caches are independent of mutable metadata. Refresh all of
	# these from live actors/catalogs exactly as in a full rebuild every frame.
	shield_actors.clear();allies.clear();max_radius=0.0
	for i in source.size():
		var e:Dictionary=source[i]
		max_radius=maxf(max_radius,Mineral.bounds_radius(e,db) if e.get("kind","")=="Asteroid" else float(e.radius))
		if e.role=="friendly":allies.append(e)
		for gun in e.guns:
			if db.asset(gun.id).get("class")=="ShieldCore":shield_actors.append(e);break
		moved(e)
		# insert() conservatively expands extents on crossings. Starting again
		# with this frame's first actor discards any historical extent growth.
		var at:Vector2=e.position
		if i==0:extent_low=at;extent_high=at
		else:extent_low=extent_low.min(at);extent_high=extent_high.max(at)
	# Empty rebuilds preserve the prior extents, matching the original public
	# behavior. nearest() returns before consulting them when actors is empty.

func insert(index: int, at: Vector2):
	if not query_cache.is_empty():query_cache.clear()
	var cell = Vector2i((at / CELL).floor())
	if not cells.has(cell): cells[cell] = []
	cells[cell].append(index)
	locations[index] = cell
	# Conservative extent can grow during a frame; never hides a moved actor.
	if locations.size() == 1: extent_low = at; extent_high = at
	else: extent_low = extent_low.min(at); extent_high = extent_high.max(at)

func moved(e: Dictionary):
	var index: int = by_uid.get(e.uid, -1)
	if index < 0: return
	var cell = Vector2i((Vector2(e.position) / CELL).floor())
	if cell == locations[index]: return
	var old: Vector2i = locations[index]
	cells[old].erase(index)
	if cells[old].is_empty(): cells.erase(old)
	insert(index, e.position)

func query(low_point: Vector2, high_point: Vector2) -> Array:
	var low = Vector2i((low_point / CELL).floor())
	var high = Vector2i((high_point / CELL).floor())
	var key=Vector4i(low.x,low.y,high.x,high.y)
	# Results contain live actor dictionaries. Membership only changes when a
	# center crosses a cell boundary; HP, shields and exact range remain live.
	if use_query_cache and query_cache.has(key):return query_cache[key].duplicate()
	var indices: Array = []
	# Very large radii should not enumerate millions of empty cells.
	if float(high.x-low.x+1) * float(high.y-low.y+1) > cells.size() * 2:
		for cell in cells:
			if cell.x >= low.x and cell.x <= high.x and cell.y >= low.y and cell.y <= high.y:
				indices.append_array(cells[cell])
	else:
		for x in range(low.x, high.x+1):
			for y in range(low.y, high.y+1): indices.append_array(cells.get(Vector2i(x,y), []))
	indices.sort()
	var result: Array = []
	for index in indices: result.append(actors[index])
	if use_query_cache and query_cache.size()<MAX_QUERIES:query_cache[key]=result.duplicate()
	return result

func nearest(at: Vector2, reach: float) -> Dictionary:
	if actors.is_empty(): return {}
	var radius = minf(CELL, absf(reach))
	var limit = maxf((at-extent_low).abs().x, (at-extent_low).abs().y)
	limit = maxf(limit, maxf((at-extent_high).abs().x, (at-extent_high).abs().y)) + CELL
	while true:
		var result: Dictionary = {}
		var best = reach * reach
		for e in query(at-Vector2.ONE*radius, at+Vector2.ONE*radius):
			if e.hp <= 0 or not e.damageable or e.role == "friendly": continue
			var distance = at.distance_squared_to(e.position)
			if distance < best: best = distance; result = e
		# Every unvisited center is outside this square, hence at least radius away.
		# Strict inequality also ensures equal-distance array-order ties are visited.
		if (not result.is_empty() and best < radius*radius) or radius >= absf(reach) or radius >= limit:
			return result
		radius = minf(radius*2.0, minf(absf(reach), limit))
	return {}
