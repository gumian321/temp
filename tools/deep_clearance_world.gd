extends "res://scripts/cave_world.gd"
## Exact positive overlap certificates: real rock/edge points inside the circle.
const WITNESS_LIMIT=4096
const WITNESS_STEP=8.0
var witnesses:Dictionary={}
var witness_ring:Array=[]
var witness_cursor=0
var witness_revision=-1
var witness_hits=0
var witness_misses=0
var witness_builds=0
func reset_cave(active:bool,world_seed:int=20261020):
	super.reset_cave(active,world_seed)
	clear_witnesses();witness_hits=0;witness_misses=0;witness_builds=0
func clear_witnesses():
	witnesses.clear();witness_ring.clear();witness_cursor=0;witness_revision=-1
func store_witness(point:Vector2,cell:Vector2i,query:Vector2,bounds=null):
	var key=Vector2i((query/WITNESS_STEP).floor())
	var id=chunk_id(cell)
	var entry={"point":point,"chunk":id,"version":chunk_at(id).version}
	if bounds!=null:entry.bounds=bounds
	if witnesses.has(key):witnesses[key]=entry;return
	if witness_ring.size()==WITNESS_LIMIT:
		witnesses.erase(witness_ring[witness_cursor]);witness_ring[witness_cursor]=key;witness_cursor=(witness_cursor+1)%WITNESS_LIMIT
	else:witness_ring.append(key)
	witnesses[key]=entry

func wall_blocked(point:Vector2,radius:float=0.0)->bool:
	if not enabled or radius<1:return super.wall_blocked(point,radius)
	if witness_revision!=revision:clear_witnesses();witness_revision=revision
	var key=Vector2i((point/WITNESS_STEP).floor())
	if witnesses.has(key):
		var witness:Dictionary=witnesses[key]
		if int(chunk_at(witness.chunk).version)==int(witness.version) and point.distance_squared_to(witness.point)<radius*radius and (not witness.has("bounds") or Rect2(witness.bounds).grow(radius).has_point(point)):
			witness_hits+=1;return true
	witness_misses+=1
	if use_clearance_cache and clear_points.has(radius) and clear_points[radius].has(point):return false
	var center_low=Vector2i(((point-Vector2.ONE*6)/CELL).floor())
	var center_high=Vector2i(((point+Vector2.ONE*6)/CELL).floor())
	for y in range(center_low.y,center_high.y+1):
		for x in range(center_low.x,center_high.x+1):
			var cell=Vector2i(x,y)
			for piece in cell_shape(cell).pieces:
				if contains(piece,point,0):store_witness(point,cell,point);witness_builds+=1;return true
	var low=Vector2i(((point-Vector2.ONE*(radius+6))/CELL).floor())
	var high=Vector2i(((point+Vector2.ONE*(radius+6))/CELL).floor())
	for y in range(low.y,high.y+1):
		for edge:ContourEdge in collision_row(y,low.x,high.x):
			if not edge.bounds.grow(radius).has_point(point):continue
			var closest=Geometry2D.get_closest_point_to_segment(point,edge.a,edge.b)
			if closest.distance_squared_to(point)<=radius*radius:
				store_witness(closest,edge.cell,point,edge.bounds);witness_builds+=1;return true
	if use_clearance_cache:
		if clear_point_count>=8192:clear_points.clear();clear_point_count=0
		if not clear_points.has(radius):clear_points[radius]={}
		clear_points[radius][point]=true;clear_point_count+=1
	return false

func dig(point:Vector2,intent:Vector2,facing:Vector2,radius:float,dt:float,strong:bool=false):
	var before=revision;super.dig(point,intent,facing,radius,dt,strong)
	if revision==before+1 and witness_revision==before:witness_revision=revision
