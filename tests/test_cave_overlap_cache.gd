extends SceneTree
const Cache=preload("res://scripts/cave_overlap_cache.gd")
var checks:Array=[]

class Edge extends RefCounted:
	var cell:Vector2i
	func _init(at:Vector2i):cell=at

class MockWorld extends RefCounted:
	var enabled=true
	var revision=0
	var rows=0
	func collision_row(y:int,left:int,right:int)->Array:
		rows+=1
		var edges:Array=[]
		for x in range(left,right+1):edges.append(Edge.new(Vector2i(x,y)))
		return edges

class MockAccelerator extends RefCounted:
	var forced_result=-1
	var witness=Vector2i.ZERO
	var find_witness=false
	var packs=0
	func overlap(edges:Array,entry:Dictionary,_point:Vector2,_radius:float)->int:
		if not entry.has("test_native_pack"):packs+=1;entry.test_native_pack=packs
		if find_witness:
			for i in edges.size():
				if edges[i].cell==witness:return i
			return -1
		return forced_result

func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)

func _initialize():
	var world=MockWorld.new();var accelerator=MockAccelerator.new();var cache=Cache.new()
	var point=Vector2(31,31);var radius=15.0
	check(cache.query(world,point,radius,accelerator)==-1,"A clear superset is returned as an exact negative boundary result")
	var first_rows=world.rows;var first_packs=accelerator.packs
	cache.query(world,point-Vector2(.0001,.0001),radius,accelerator)
	check(world.rows==first_rows and accelerator.packs==first_packs,"Same tile and full-precision radius retain immutable edges and accelerator packing")
	accelerator.find_witness=true;accelerator.witness=Vector2i(-1,-1)
	check(cache.query(world,point,radius,accelerator)==-2 and cache.matched_edge==null,"A positive superset witness outside the original tight cell rectangle falls back")
	accelerator.witness=Vector2i(0,0)
	var result=cache.query(world,point,radius,accelerator)
	check(result>=0 and cache.matched_edge.cell==Vector2i(0,0),"An original-query witness retains its ordered edge identity")
	accelerator.find_witness=false
	cache.query(world,point,15.0000001,accelerator)
	check(cache.entries.size()==2,"Distinct full-precision radii have distinct cache buckets")
	world.revision=1;cache.invalidate(Rect2i(100,100,1,1),1)
	var rows=world.rows;var packs=accelerator.packs
	cache.query(world,point,radius,accelerator)
	check(world.rows==rows and accelerator.packs==packs,"A distant single-step edit retains unrelated edges and packing")
	world.revision=2;cache.invalidate(Rect2i(0,0,1,1),2)
	cache.query(world,point,radius,accelerator)
	check(world.rows>rows and accelerator.packs==packs+1 and cache.invalidations>0,"An intersecting edit rebuilds edges and discards the previous native pack")
	world.revision=5;cache.invalidate(Rect2i(100,100,1,1),5)
	cache.query(world,point,radius,accelerator)
	check(cache.revision==5 and cache.order.size()==1,"A skipped revision clears all entries before the next query")
	accelerator.forced_result=999999
	check(cache.query(world,point,radius,accelerator)==-2 and cache.matched_edge==null,"An invalid accelerator index conservatively falls back")
	accelerator.forced_result=-1
	for i in Cache.LIMIT+9:cache.query(world,Vector2(i*32,0),1.0,accelerator)
	check(cache.order.size()==Cache.LIMIT,"FIFO storage stays bounded at 512 entries")
	var before=cache.order.size()
	check(cache.query(world,Vector2(32768,0),radius,accelerator)==-2 and cache.query(world,point,513.0,accelerator)==-2 and cache.order.size()==before,"Out-of-domain coordinates and radii bypass without cache mutation")
	cache.clear()
	check(cache.entries.is_empty() and cache.order.is_empty() and cache.revision==-1 and cache.matched_edge==null,"Reset clears geometry, pack entries, revision and witness")
	var report={"passed":checks.all(func(item):return item.passed),"checks":checks,"scope":"Bounded mock API coverage: ordered edge/witness identity, original tight-cell fallback, full-precision radius keys, packing reuse, local invalidation, revision jumps, FIFO cap and reset. Actual native geometry differentials are separate; no game/FPS claim."}
	print(JSON.stringify(report));quit(0 if report.passed else 1)
