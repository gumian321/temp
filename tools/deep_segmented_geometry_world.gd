extends "res://scripts/cave_world.gd"
## Alternative candidate. The original geometry Dictionary remains the sole
## readiness authority. Total capacity remains 12000; cheap empty entries have
## a 2048-entry soft quota and yield to polygon entries under cache pressure.
const SEGMENTED_GEOMETRY_LIMIT=12000
const SEGMENTED_EMPTY_LIMIT=2048
var use_segmented_geometry=OS.get_environment("RBPEW_LEGACY_EMPTY_GEOMETRY")!="1"
var empty_slots:Dictionary={}
var polygon_slots:Dictionary={}
var empty_ring:Array[Vector2i]=[]
var polygon_ring:Array[Vector2i]=[]
var empty_cursor=0
var polygon_cursor=0
var segmented_empty_evictions=0
var segmented_polygon_evictions=0

func reset_cave(active:bool,world_seed:int=20261020):
	super.reset_cave(active,world_seed);clear_geometry_slots()
	segmented_empty_evictions=0;segmented_polygon_evictions=0

func clear_geometry_slots():
	empty_slots.clear();polygon_slots.clear();empty_ring.clear();polygon_ring.clear()
	empty_cursor=0;polygon_cursor=0

func evict_geometry_slot(empty:bool,slot:int)->bool:
	var ring=empty_ring if empty else polygon_ring
	var slots=empty_slots if empty else polygon_slots
	var cell:Vector2i=ring[slot]
	# A dig may erase/reclassify/reinsert a cell. A ring slot owns it only
	# while the reverse map still points back to this exact slot.
	if int(slots.get(cell,-1))!=slot:return false
	slots.erase(cell)
	if not geometry.has(cell):return false
	geometry.erase(cell);geometry_evictions+=1
	if empty:segmented_empty_evictions+=1
	else:segmented_polygon_evictions+=1
	return true

func evict_oldest_geometry(empty:bool)->bool:
	var slots=empty_slots if empty else polygon_slots
	# Once polygons displace the last empty entry, the bounded ring still has
	# 2048 historical positions. The former full empty scan returned false
	# and brought its cursor back to the same position; avoid repeating it.
	if slots.is_empty():return false
	var count=empty_ring.size() if empty else polygon_ring.size()
	for _attempt in count:
		var cursor=empty_cursor if empty else polygon_cursor
		var removed=evict_geometry_slot(empty,cursor)
		if empty:empty_cursor=(cursor+1)%count
		else:polygon_cursor=(cursor+1)%count
		if removed:return true
	return false

func store_segmented_geometry(cell:Vector2i,result:Dictionary):
	var empty:bool=result.pieces.is_empty()
	var slots=empty_slots if empty else polygon_slots
	var other_slots=polygon_slots if empty else empty_slots
	other_slots.erase(cell)
	var slot=int(slots.get(cell,-1))
	if slot<0:
		var ring=empty_ring if empty else polygon_ring
		var limit=SEGMENTED_EMPTY_LIMIT if empty else SEGMENTED_GEOMETRY_LIMIT
		slot=ring.size()
		if slot==limit:
			slot=empty_cursor if empty else polygon_cursor
			evict_geometry_slot(empty,slot)
			ring[slot]=cell
			if empty:empty_cursor=(slot+1)%limit
			else:polygon_cursor=(slot+1)%limit
		else:ring.append(cell)
	if geometry.size()>=SEGMENTED_GEOMETRY_LIMIT and not geometry.has(cell):
		geometry_eviction_batches+=1
		if not evict_oldest_geometry(true) and not evict_oldest_geometry(false):
			# Only external direct Dictionary writes can bypass both slot maps.
			geometry.erase(geometry.keys()[0]);geometry_evictions+=1
	# Publish ownership after eviction; the new key does not yet exist in
	# geometry, so pressure eviction must not consume its reserved slot.
	slots[cell]=slot
	geometry[cell]=result

func cell_shape(cell:Vector2i)->Dictionary:
	if not use_segmented_geometry:return super.cell_shape(cell)
	if geometry.is_empty() and (not empty_slots.is_empty() or not polygon_slots.is_empty()):clear_geometry_slots()
	if geometry.has(cell):geometry_hits+=1;return geometry[cell]
	geometry_misses+=1
	var mask=0
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
				if solid(cell+Vector2i(x-1,y-1)):mask|=1<<(y*3+x)
	if mask==0:geometry_mask_zero+=1
	elif mask==511:geometry_mask_full+=1
	else:geometry_mask_mixed+=1
	var source=ContourMesh.fractured_template(mask,cell,seed_value)
	if source.pieces.is_empty():
		geometry_empty_misses+=1;store_segmented_geometry(cell,empty_shape)
		return empty_shape
	var corners=PackedVector2Array([vertex(cell),vertex(cell+Vector2i.RIGHT),vertex(cell+Vector2i.ONE),vertex(cell+Vector2i.DOWN)])
	var pieces:Array=[];var outline=PackedVector2Array()
	for local_polygon in source.pieces:
		var polygon=PackedVector2Array()
		for at in local_polygon:polygon.append(project_contour(at,corners))
		pieces.append(cave_piece(polygon))
	for at in source.outline:outline.append(project_contour(at,corners))
	var result={"pieces":pieces,"outline":outline}
	store_segmented_geometry(cell,result)
	return result
