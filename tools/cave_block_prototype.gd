extends "res://scripts/cave_world.gd"
## Reuse immutable contour fragments between overlapping row-range queries.
const BLOCK_LIMIT=2048
var blocks:Dictionary={}
var block_ring:Array=[]
var block_cursor=0
var block_revision=-1
var block_hits=0
var block_misses=0
var fragment_hits=0
var fragment_misses=0

func reset_cave(active:bool,world_seed:int=20261020):
	super.reset_cave(active,world_seed)
	clear_blocks();block_hits=0;block_misses=0;fragment_hits=0;fragment_misses=0

func clear_blocks():
	blocks.clear();block_ring.clear();block_cursor=0;block_revision=-1

func collision_row(y:int,left:int,right:int)->Array:
	var row_key=Vector3i(left,right,y)
	if collision_rows.has(row_key):return collision_rows[row_key]
	if block_revision!=revision:clear_blocks();block_revision=revision
	var edges:Array=[]
	for bx in range(floori(float(left)/CHUNK),floori(float(right)/CHUNK)+1):
		var key=Vector2i(bx,y)
		var version:int=chunk_at(Vector2i(bx,floori(float(y)/CHUNK))).version
		var entry:Dictionary
		if blocks.has(key):
			entry=blocks[key];block_hits+=1
			if int(entry.version)!=version:entry.cells.clear();entry.version=version
		else:
			block_misses+=1;entry={"version":version,"cells":{}}
			if block_ring.size()==BLOCK_LIMIT:
				blocks.erase(block_ring[block_cursor]);block_ring[block_cursor]=key;block_cursor=(block_cursor+1)%BLOCK_LIMIT
			else:block_ring.append(key)
			blocks[key]=entry
		for x in range(maxi(left,bx*CHUNK),mini(right,(bx+1)*CHUNK-1)+1):
			var local=x-bx*CHUNK
			if entry.cells.has(local):fragment_hits+=1
			else:
				fragment_misses+=1
				var fragments:Array=[]
				var outline:PackedVector2Array=cell_shape(Vector2i(x,y)).outline
				for i in range(0,outline.size(),2):
					var a=outline[i];var b=outline[i+1];var delta=b-a
					var edge=ContourEdge.new(a,Vector2i(x,y))
					edge.b=b;edge.delta=delta;edge.length_squared=delta.length_squared()
					edge.normal=Vector2(delta.y,-delta.x).normalized();edge.bounds=Rect2(a,Vector2.ZERO).expand(b)
					fragments.append(edge)
				entry.cells[local]=fragments
			edges.append_array(entry.cells[local])
	if collision_rows.size()>=2048:
		var oldest=collision_rows.keys()
		for i in 128:collision_rows.erase(oldest[i])
	collision_rows[row_key]=edges
	return edges

func dig(point:Vector2,intent:Vector2,facing:Vector2,radius:float,dt:float,strong:bool=false):
	var before=revision
	super.dig(point,intent,facing,radius,dt,strong)
	# Bites already advance every affected chunk's version, including seam
	# neighbors. Only an unexplained/public revision change needs a full reset.
	if revision==before+1 and block_revision==before:block_revision=revision
