extends SceneTree
const World=preload("res://scripts/cave_world.gd")
var checks=[]
func _initialize():call_deferred("execute")
func check(value:bool,message:String):
	checks.append({"name":message,"passed":value})
	if not value:push_error(message)
func execute():
	var cached=World.new();var raw=World.new();cached.reset_cave(true);raw.reset_cave(true);raw.use_sweep_result_cache=false
	var start=Vector2.ZERO;var finish=Vector2(12,0);var radius=80.0
	var empty=cached.movement_wall_hit(start,finish,radius);empty.injected=true
	check(cached.movement_wall_hit(start,finish,radius)==raw.wall_hit(start,finish,radius),"Cached empty contacts are fresh dictionaries owned by each caller")
	var contact={}
	for y in range(-16,17):
		for edge in raw.collision_row(y,-24,60):
			var midpoint=(edge.a+edge.b)*.5
			var a=midpoint+edge.normal*81;var b=a-edge.normal*12
			var result=raw.wall_hit(a,b,radius)
			if not result.is_empty():start=a;finish=b;contact=result;break
		if not contact.is_empty():break
	check(not contact.is_empty(),"The query fixture contains a real circular rock contact")
	var first=cached.movement_wall_hit(start,finish,radius);first.time=-7;first.normal=Vector2(99,99)
	check(cached.movement_wall_hit(start,finish,radius)==contact,"Changing a returned contact cannot corrupt a later cache hit")
	var equal=true
	for shift in [Vector2.ZERO,Vector2(.0001,0),Vector2(0,.0001),Vector2(-.003,.002)]:
		for r in [64.0,80.0,80.0001,108.723,202.79785,288.0,512.0,513.0]:
			for delta in [Vector2(7,0),Vector2(12,0),Vector2(16,0),Vector2(17,0),Vector2(0,-12)]:
				var a=start+shift;var b=a+delta
				equal=equal and cached.movement_wall_hit(a,b,r)==raw.wall_hit(a,b,r)
	check(equal,"Nearby coordinates, distinct radii, reverse movement and uncached long sweeps retain exact contacts")
	for i in 1300:
		var a=Vector2(i%65*2,i/65*2);cached.movement_wall_hit(a,a+Vector2(12,0),radius)
	check(cached.sweep_result_ring.size()==World.SWEEP_RESULT_LIMIT,"A constant-time ring bounds retained queries at 1024 entries")
	# Opening rock and advancing its public revision invalidates prior answers.
	for world in [cached,raw]:
		for y in range(-16,17):
			for x in range(-16,33):
				var cell=Vector2i(x,y);world.chunk_at(world.chunk_id(cell)).solid[world.cell_index(cell)]=0
		world.geometry.clear();world.collision_rows.clear();world.clear_points.clear();world.clear_point_count=0
		world.sweep_neighborhoods.clear();world.sweep_neighborhood_order.clear();world.revision+=1
	check(cached.movement_wall_hit(start,finish,radius)==raw.wall_hit(start,finish,radius) and cached.sweep_result_ring.size()==1,"Terrain revisions discard stale answers before serving a query")
	cached.reset_cave(true,20261021);raw.reset_cave(true,20261021)
	check(cached.sweep_result_ring.is_empty() and cached.sweep_result_hits==0 and cached.movement_wall_hit(start,finish,radius)==raw.wall_hit(start,finish,radius),"New worlds clear query history even when the revision resets to zero")
	cached.use_sweep_clipping=false
	check(cached.movement_wall_hit(start,finish,radius)==raw.wall_hit(start,finish,radius) and cached.sweep_result_ring.size()==1,"Diagnostic solver mode changes cannot reuse another mode's results")
	var result={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/cave-sweep-results-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result));quit(0 if result.passed else 1)
