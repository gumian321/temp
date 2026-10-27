extends SceneTree
const World=preload("res://scripts/cave_world.gd")
func _initialize():call_deferred("execute")
func make_world(snapshot,blocked:bool):
	var world=World.new();world.use_collision_blocks=blocked
	world.reset_cave(true,int(snapshot.seed));world.chunks=snapshot.chunks.duplicate(true);world.revision=int(snapshot.revision)
	return world
func percentile(values:Array,fraction:float)->float:
	var ordered=values.duplicate();ordered.sort();return ordered[mini(ordered.size()-1,int(ordered.size()*fraction))]
func execute():
	var input=FileAccess.open(OS.get_environment("RBPEW_ORBIT_SNAPSHOT"),FileAccess.READ)
	var snapshot=input.get_var(false)
	if not snapshot is Dictionary or snapshot.get("format")!=1:printerr("Invalid native orbit snapshot");quit(2);return
	var actors:Array=snapshot.actors.filter(func(a):return float(a.get("orbit_speed",0))!=0).duplicate(true)
	if actors.is_empty():printerr("No captured orbit actors");quit(2);return
	var trace:Array=[];var reference=make_world(snapshot,false)
	for frame in 160:
		var queries:Array=[]
		for actor in actors:
			actor.orbit_offset=Vector2(actor.orbit_offset).rotated(float(actor.orbit_speed)/30)
			var start:Vector2=actor.position;var desired:Vector2=Vector2(actor.origin)+actor.orbit_offset
			var radius:float=actor.get("ground_radius",actor.radius)
			var expected=reference.move(start,desired,radius);actor.position=expected
			queries.append([start,desired,radius,expected])
		trace.append(queries)
	var tests:Array=[];var differences=0;var comparisons=0
	for mode in [false,true,true,false]:
		var world=make_world(snapshot,mode);var times:Array=[]
		for frame in trace.size():
			var began=Time.get_ticks_usec()
			for query in trace[frame]:
				var actual=world.move(query[0],query[1],query[2])
				if actual!=query[3]:differences+=1
				comparisons+=1
			if frame>=40:times.append(float(Time.get_ticks_usec()-began)/1000)
		var sum=0.0
		for value in times:sum+=value
		var result={"blocks":mode,"mean_ms":sum/times.size(),"p95_ms":percentile(times,.95),"p99_ms":percentile(times,.99),"max_ms":times.max()}
		if mode:
			result.block_entries=world.collision_blocks.size();result.block_hits=world.collision_block_hits;result.block_misses=world.collision_block_misses;result.fragment_hits=world.collision_fragment_hits;result.fragment_misses=world.collision_fragment_misses
		tests.append(result)
		await process_frame
	var report={"scope":"Frozen orbit movement queries from native positions/origins/offsets and actual excavated chunks. All captured orbit actors run at 30Hz in this isolated CPU micro-test; remote cadence/rendering/full battle are not replayed.","snapshot_elapsed":snapshot.run_elapsed,"actors":actors.size(),"tests":tests,"comparisons":comparisons,"differences":differences}
	FileAccess.open("res://artifacts/captured-orbit-block-profile-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if differences==0 else 1)
