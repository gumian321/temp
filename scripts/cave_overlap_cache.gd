extends RefCounted
## Exact boundary-overlap accelerator storage. The owning world retains its
## original filled-center/material/clear-point flow and fallback algorithm.
const TILE_STEP=32.0
const CELL=24.0
const LIMIT=512
var entries:Dictionary={}
var order:Array=[]
var cursor=0
var revision=-1
var matched_edge=null
var hits=0
var misses=0
var invalidations=0

func clear():
	entries.clear();order.clear();cursor=0;revision=-1;matched_edge=null

func query(world,point:Vector2,radius:float,accelerator)->int:
	matched_edge=null
	if world==null or accelerator==null or not world.enabled or not is_finite(radius) or radius<=0 or radius>512 or not is_finite(point.x) or not is_finite(point.y) or absf(point.x)>=32768 or absf(point.y)>=32768:return -2
	if revision!=int(world.revision):clear();revision=int(world.revision)
	var tile=Vector2i((point/TILE_STEP).floor())
	var bucket=entries.get(radius)
	var entry=bucket.get(tile) if bucket!=null else null
	if entry==null or not entry.valid:
		misses+=1
		var tile_low=Vector2(tile)*TILE_STEP
		var low=Vector2i(((tile_low-Vector2.ONE*(radius+6))/CELL).floor())
		var high=Vector2i(((tile_low+Vector2.ONE*TILE_STEP+Vector2.ONE*(radius+6))/CELL).floor())
		var edges:Array=[]
		for y in range(low.y,high.y+1):edges.append_array(world.collision_row(y,low.x,high.x))
		entry={"radius":radius,"tile":tile,"bounds":Rect2i(low,high-low+Vector2i.ONE),"edges":edges,"valid":true}
		if bucket!=null and bucket.has(tile):
			# Preserve the original FIFO slot when rebuilding an invalid entry.
			var previous:Dictionary=bucket[tile]
			previous.clear();previous.merge(entry);entry=previous
		else:
			if order.size()==LIMIT:
				var old:Dictionary=order[cursor]
				entries[old.radius].erase(old.tile)
				if entries[old.radius].is_empty():entries.erase(old.radius)
				order[cursor]=entry;cursor=(cursor+1)%LIMIT
			else:order.append(entry)
			# Eviction may have removed this radius bucket; reacquire it.
			if not entries.has(radius):entries[radius]={}
			bucket=entries[radius];bucket[tile]=entry
	else:hits+=1
	var result:int=accelerator.overlap(entry.edges,entry,point,radius)
	if result<0:return result if result in [-2,-1] else -2
	if result>=entry.edges.size():return -2
	var edge=entry.edges[result]
	var tight_low=Vector2i(((point-Vector2.ONE*(radius+6))/CELL).floor())
	var tight_high=Vector2i(((point+Vector2.ONE*(radius+6))/CELL).floor())
	var tight=Rect2i(tight_low,tight_high-tight_low+Vector2i.ONE)
	# The cached superset uses original ascending row/cell/outline ordering.
	# An earlier witness outside the original query rectangle must fall back;
	# accepting a later tight witness would change material-certificate state.
	if not tight.has_point(Vector2i(edge.cell)):return -2
	matched_edge=edge
	return result

func invalidate(changed:Rect2i,new_revision:int):
	matched_edge=null
	if revision!=new_revision-1:return
	for entry:Dictionary in order:
		if entry.valid and Rect2i(entry.bounds).intersects(changed):
			entry.valid=false;invalidations+=1
	revision=new_revision
