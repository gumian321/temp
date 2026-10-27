extends SceneTree
## Export original GDScript answers for an isolated native math differential.
const World=preload("res://scripts/cave_world.gd")
var groups:Array=[]
var cases=0
var hits=0
func _initialize():call_deferred("execute")
func pack_edges(edges:Array)->PackedFloat64Array:
	var packed=PackedFloat64Array()
	for edge in edges:
		packed.append_array(PackedFloat64Array([edge.a.x,edge.a.y,edge.b.x,edge.b.y,edge.delta.x,edge.delta.y,edge.normal.x,edge.normal.y,edge.length_squared,edge.bounds.position.x,edge.bounds.position.y,edge.bounds.size.x,edge.bounds.size.y]))
	return packed
func group(world,edges:Array,queries:Array):
	var packed_queries:Array=[];var expected:Array=[]
	for item in queries:
		var start:Vector2=item[0];var finish:Vector2=item[1];var radius:float=item[2]
		var delta=finish-start
		var query=Rect2(start,Vector2.ZERO).expand(finish).grow(radius+.8)
		var earliest:float=INF;var index=-1
		for i in edges.size():
			var edge=edges[i]
			if not edge.bounds.intersects(query):continue
			var time:float=world.contour_time(edge,start,delta,delta.length_squared(),radius)
			if time<earliest:earliest=time;index=i
		packed_queries.append(PackedFloat64Array([start.x,start.y,delta.x,delta.y,radius,query.position.x,query.position.y,query.size.x,query.size.y]))
		expected.append(PackedFloat64Array([index,earliest]));cases+=1
		if index>=0:hits+=1
	groups.append({"edges":pack_edges(edges),"queries":packed_queries,"expected":expected})
func line(a:Vector2,b:Vector2):
	var edge=World.ContourEdge.new(a,Vector2i.ZERO)
	edge.b=b;edge.delta=b-a;edge.length_squared=edge.delta.length_squared();edge.normal=Vector2(edge.delta.y,-edge.delta.x).normalized()
	edge.bounds=Rect2(a,Vector2.ZERO).expand(b).grow(.01)
	return edge
func execute():
	var path="res://artifacts/deep50-candidate1-live-20261026/stop-states/0915-battle-state.bin"
	var source=FileAccess.open(path,FileAccess.READ)
	if source==null:push_error("Captured late terrain missing");quit(2);return
	var snapshot=source.get_var(false);source.close()
	var world=World.new();world.reset_cave(snapshot.terrain.enabled,snapshot.terrain.seed_value)
	for key in snapshot.terrain:world.set(key,snapshot.terrain[key])
	var rng=RandomNumberGenerator.new();rng.seed=2026102609
	var actors:Array=snapshot.states.combat["values"].enemies
	for actor in actors:
		if actor.get("hp",0)<=0 or actor.get("parent",0)!=0:continue
		var at:Vector2=actor.position
		var radius:float=actor.get("ground_radius",actor.radius)
		if radius>512:continue
		var edges:Array=world.local_sweep_edges(at,radius,32)
		var queries:Array=[]
		for i in 24:
			var start=at+Vector2(rng.randf_range(-.001,.001),rng.randf_range(-.001,.001))
			var length:float=[.000001,.5,1.0,2.0,4.0,8.0,16.0,32.0][i%8]
			queries.append([start,start+Vector2.from_angle(rng.randf_range(-PI,PI))*length,radius])
		group(world,edges,queries)
	# Explicit face, circular corner, tangent, inside-start, negative coordinate,
	# near-zero sweep, fractional radius and first-edge exact-tie fixtures.
	for at in [Vector2.ZERO,Vector2(-8400,-3113),Vector2(40000,30000)]:
		var edges:Array=[line(at+Vector2(0,-10),at+Vector2(0,10)),line(at+Vector2(0,10),at+Vector2(20,10))]
		edges.append(edges[0])
		var queries:Array=[]
		for radius in [0.0,1.0,15.0,15.000000001,64.0,287.963623046875,512.0]:
			for start in [Vector2(20,0),Vector2(0,0),Vector2(20,10)+Vector2.RIGHT*radius,Vector2(20,-10-radius),Vector2(0,10+radius)]:
				for delta in [Vector2(-32,0),Vector2(0,32),Vector2(-.000001,0),Vector2(1,1),Vector2.ZERO]:queries.append([at+start,at+start+delta,radius])
		group(world,edges,queries)
	var destination="res://artifacts/native-sweep-fixture.bin"
	FileAccess.open(destination,FileAccess.WRITE).store_var({"format":1,"groups":groups,"cases":cases,"hits":hits})
	var report={"passed":cases>1000 and hits>0,"groups":groups.size(),"cases":cases,"hits":hits,"fixture":destination,"scope":"Original contour_time and Rect2 answers from actual 915-second terrain plus synthetic tangent/corner/tie fixtures. Math correctness only; not FPS acceptance."}
	FileAccess.open("res://artifacts/native-sweep-fixture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
