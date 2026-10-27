extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Candidate=preload("res://tools/deep_empty_geometry_world.gd")
class EmptyWorld extends Candidate:
	func original_solid(_cell:Vector2i)->bool:return false
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func signature(shape:Dictionary)->Array:
	var result:Array=[shape.outline]
	for piece in shape.pieces:result.append([piece.polygon,piece.normals,piece.bounds,piece.miter])
	return result
func fill_material(world,center:Vector2i,update_versions:bool):
	for y in range(-1,2):
		for x in range(-1,2):
			var cell=center+Vector2i(x,y);var data=world.chunk_at(world.chunk_id(cell))
			data.solid[world.cell_index(cell)]=1
			if update_versions:data.version+=1
func execute():
	var rng=RandomNumberGenerator.new();rng.seed=20261026
	var equal=true;var comparisons=0
	for seed_value in [20261020,20261026,7,-43]:
		var old=World.new();old.reset_cave(true,seed_value)
		var current=Candidate.new();current.reset_cave(true,seed_value)
		for i in 1200:
			var cell=Vector2i(rng.randi_range(-100,100),rng.randi_range(-100,100)) if i%3 else Vector2i((i%33-16)*16-1,(i/33-16)*16)
			equal=equal and signature(old.cell_shape(cell))==signature(current.cell_shape(cell));comparisons+=1
			if i%4==0:
				var a=(Vector2(cell)+Vector2.ONE*.5)*24;var b=a+Vector2(11,-7);var radius=[0.0,16.0,64.0,128.0][(i>>2)%4]
				equal=equal and old.wall_blocked(a,radius)==current.wall_blocked(a,radius) and old.wall_hit(a,b,radius)==current.wall_hit(a,b,radius);comparisons+=2
	check(equal,"Actual seeded contours, radius-zero overlap and ordered contacts remain identical across negative/positive seams")
	var empty=EmptyWorld.new();empty.reset_cave(true)
	for y in range(0,6):
		for x in range(0,6):empty.cell_shape(Vector2i(x,y))
	check(empty.visibility_ready(Vector2(24,24),Vector2(120,120),8) and empty.geometry.size()==1,"Visibility treats bitmap-resident empty cells as warm while only one real empty anchor occupies geometry")
	var near=Vector2i(15,15);var far=Vector2i(320,320)
	empty.cell_shape(near);empty.cell_shape(far)
	var far_id=empty.chunk_id(far);var far_entry:Dictionary=empty.empty_geometry[far_id]
	fill_material(empty,near,true)
	check(not empty.shape_ready(near) and not empty.cell_shape(near).pieces.is_empty() and empty.shape_ready(far) and is_same(far_entry,empty.empty_geometry[far_id]),"Changed chunk versions expire empty bits, including seam cells, while distant entries retain their slots")
	var target=Vector2i(-33,31)
	empty.cell_shape(target);fill_material(empty,target,false);empty.geometry.clear()
	check(not empty.cell_shape(target).pieces.is_empty(),"Public geometry.clear invalidates empty metadata even without a revision or chunk-version update")
	var unknown=Vector2i(97,-49)
	empty.cell_shape(unknown);fill_material(empty,unknown,false);empty.revision+=7
	check(not empty.cell_shape(unknown).pieces.is_empty(),"Unknown revision jumps discard every empty certificate, including unversioned diagnostic edits")
	var bounded=EmptyWorld.new();bounded.reset_cave(true)
	for i in Candidate.EMPTY_GEOMETRY_CHUNK_LIMIT+43:bounded.cell_shape(Vector2i(i*16,-32))
	check(bounded.empty_geometry.size()==Candidate.EMPTY_GEOMETRY_CHUNK_LIMIT and bounded.empty_geometry_ring.size()==Candidate.EMPTY_GEOMETRY_CHUNK_LIMIT and bounded.empty_geometry_evictions==43 and bounded.geometry.size()==1,"A 512-slot chunk ring bounds at most 131072 empty bits without evicting expensive polygons")
	var hits=bounded.empty_geometry_hits
	bounded.cell_shape(Vector2i((Candidate.EMPTY_GEOMETRY_CHUNK_LIMIT+42)*16,-32))
	check(bounded.empty_geometry_hits==hits+1,"Repeated empty queries reuse the bitmap without rebuilding contour templates")
	bounded.use_empty_geometry=false;var before=bounded.empty_geometry_hits
	bounded.cell_shape(Vector2i(123,456))
	check(bounded.empty_geometry.is_empty() and bounded.empty_geometry_hits==before and bounded.geometry.has(Vector2i(123,456)),"The same-instance diagnostic switch returns to the original geometry implementation")
	var raw=World.new();raw.reset_cave(true)
	var cached=Candidate.new();cached.reset_cave(true)
	var hit=raw.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
	var head:Vector2=hit.position+hit.normal*.4
	var excavation_equal=true
	for tick in 240:
		for world in [raw,cached]:world.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
		var moved=raw.move(head,head+Vector2.RIGHT*2.2,28)
		excavation_equal=excavation_equal and moved==cached.move(head,head+Vector2.RIGHT*2.2,28);head=moved
		if tick%40==39:
			for y in range(-4,5):
				for x in range(10,40):
					var cell=Vector2i(x,y)
					excavation_equal=excavation_equal and signature(raw.cell_shape(cell))==signature(cached.cell_shape(cell));comparisons+=1
	check(excavation_equal and cached.removed_count>0,"Repeated real excavation preserves every sampled shape and movement without globally discarding distant empty chunks")
	bounded.reset_cave(true,7)
	check(bounded.empty_geometry.is_empty() and bounded.empty_geometry_ring.is_empty() and bounded.empty_geometry_hits==0 and not bounded.empty_geometry_anchor_valid,"Seed reset releases all empty bits, slots, anchors and counters")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"comparisons":comparisons,"excavation_geometry_cells":cached.geometry.size(),"excavation_empty_chunks":cached.empty_geometry.size()}
	print(JSON.stringify(report));FileAccess.open("res://artifacts/deep-empty-geometry-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if report.passed else 1)
