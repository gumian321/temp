extends "res://scripts/cave_world.gd"
## Isolated candidate: empty contours occupy chunk bitmaps, leaving the bounded
## expensive geometry cache for actual polygons. Not wired into production.
const EMPTY_GEOMETRY_CHUNK_LIMIT=512
var use_empty_geometry=OS.get_environment("RBPEW_LEGACY_EMPTY_GEOMETRY")!="1"
var empty_geometry:Dictionary={}
var empty_geometry_ring:Array=[]
var empty_geometry_cursor=0
var empty_geometry_revision=-1
var empty_geometry_anchor=Vector2i.ZERO
var empty_geometry_anchor_valid=false
var empty_geometry_hits=0
var empty_geometry_misses=0
var empty_geometry_evictions=0
var empty_geometry_invalidations=0

func reset_cave(active:bool,world_seed:int=20261020):
	super.reset_cave(active,world_seed)
	clear_empty_geometry()
	empty_geometry_hits=0;empty_geometry_misses=0;empty_geometry_evictions=0;empty_geometry_invalidations=0

func clear_empty_geometry():
	# This one real empty cell anchors even an otherwise all-empty geometry
	# cache. Public geometry.clear() then remains observable on the next read.
	if empty_geometry_anchor_valid:geometry.erase(empty_geometry_anchor)
	empty_geometry.clear();empty_geometry_ring.clear();empty_geometry_cursor=0
	empty_geometry_anchor_valid=false;empty_geometry_revision=revision

func sync_empty_geometry():
	if empty_geometry_revision!=revision or (not empty_geometry.is_empty() and geometry.is_empty()):clear_empty_geometry()

func empty_geometry_entry(cell:Vector2i)->Dictionary:
	var id=chunk_id(cell)
	if not empty_geometry.has(id):return {}
	var entry:Dictionary=empty_geometry[id]
	var version:int=chunk_at(id).version
	if entry.version!=version:
		entry.rows.fill(0);entry.version=version;empty_geometry_invalidations+=1
	return entry

func empty_geometry_ready(cell:Vector2i)->bool:
	var entry=empty_geometry_entry(cell)
	return not entry.is_empty() and (int(entry.rows[posmod(cell.y,CHUNK)])&(1<<posmod(cell.x,CHUNK)))!=0

func store_empty_geometry(cell:Vector2i):
	var id=chunk_id(cell)
	var entry:Dictionary=empty_geometry_entry(cell)
	if entry.is_empty():
		var rows=PackedInt32Array();rows.resize(CHUNK)
		entry={"id":id,"version":int(chunk_at(id).version),"rows":rows}
		if empty_geometry_ring.size()==EMPTY_GEOMETRY_CHUNK_LIMIT:
			empty_geometry.erase(empty_geometry_ring[empty_geometry_cursor].id)
			empty_geometry_ring[empty_geometry_cursor]=entry
			empty_geometry_cursor=(empty_geometry_cursor+1)%EMPTY_GEOMETRY_CHUNK_LIMIT
			empty_geometry_evictions+=1
		else:empty_geometry_ring.append(entry)
		empty_geometry[id]=entry
	entry.rows[posmod(cell.y,CHUNK)]|=1<<posmod(cell.x,CHUNK)
	if geometry.is_empty():
		geometry[cell]=empty_shape
		empty_geometry_anchor=cell;empty_geometry_anchor_valid=true

func cell_shape(cell:Vector2i)->Dictionary:
	if not use_empty_geometry:
		if not empty_geometry.is_empty():clear_empty_geometry()
		return super.cell_shape(cell)
	sync_empty_geometry()
	if geometry.has(cell):geometry_hits+=1;return geometry[cell]
	if empty_geometry_ready(cell):geometry_hits+=1;empty_geometry_hits+=1;return empty_shape
	geometry_misses+=1;empty_geometry_misses+=1
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
		geometry_empty_misses+=1;store_empty_geometry(cell)
		return empty_shape
	var corners=PackedVector2Array([vertex(cell),vertex(cell+Vector2i.RIGHT),vertex(cell+Vector2i.ONE),vertex(cell+Vector2i.DOWN)])
	var pieces:Array=[];var outline=PackedVector2Array()
	for local_polygon in source.pieces:
		var polygon=PackedVector2Array()
		for at in local_polygon:polygon.append(project_contour(at,corners))
		pieces.append(cave_piece(polygon))
	for at in source.outline:outline.append(project_contour(at,corners))
	var result={"pieces":pieces,"outline":outline}
	if geometry.size()>=12000:
		var oldest=geometry.keys()
		for i in 128:geometry.erase(oldest[i])
		geometry_evictions+=128;geometry_eviction_batches+=1
	geometry[cell]=result
	return result

func shape_ready(cell:Vector2i)->bool:
	if not use_empty_geometry:return geometry.has(cell)
	sync_empty_geometry()
	return geometry.has(cell) or empty_geometry_ready(cell)

func visibility_ready(origin:Vector2,target:Vector2,radius:float)->bool:
	if not use_empty_geometry:return super.visibility_ready(origin,target,radius)
	var area=Rect2(origin,Vector2.ZERO).expand(target).grow(radius+6)
	var low=Vector2i((area.position/CELL).floor());var high=Vector2i((area.end/CELL).floor())
	if (high.x-low.x+1)*(high.y-low.y+1)>4096:return false
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			if not shape_ready(Vector2i(x,y)):return false
	return true

func dig(point:Vector2,intent:Vector2,facing:Vector2,radius:float,dt:float,strong:bool=false):
	var before=revision
	super.dig(point,intent,facing,radius,dt,strong)
	# A normal bite advances chunk versions for every affected 3x3 dependency,
	# including neighbors across negative/positive seams. Empty bits in those
	# chunks expire lazily; unrelated chunks survive without a global scan.
	if revision==before+1 and empty_geometry_revision==before:empty_geometry_revision=revision
