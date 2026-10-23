extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Reference=preload("res://tests/cave_sweep_reference.gd")
func _initialize():call_deferred("execute")
func execute():
	var old=Reference.new();var current=World.new();old.reset_cave(true);current.reset_cave(true)
	var rng=RandomNumberGenerator.new();rng.seed=20261021
	var queries=[]
	for i in 2400:
		var radius:float=[0.0,15.0,27.0,30.0,48.0,64.0][i%6]
		var start=old.safe_position(Vector2(rng.randf_range(-1600,1800),rng.randf_range(-1600,1600)),radius)
		var delta=Vector2.from_angle(rng.randf_range(-PI,PI))*rng.randf_range(.1,1400)
		if i%7==0:delta=Vector2(1 if i%2==0 else -1,0)*rng.randf_range(.01,1400)
		queries.append([start,start+delta,radius])
	var differences=[];var comparisons=0
	for stage in 2:
		for q in queries:
			var a=old.wall_hit(q[0],q[1],q[2]);var b=current.wall_hit(q[0],q[1],q[2]);comparisons+=1
			if a!=b and differences.size()<12:differences.append({"query":q,"before":a,"after":b})
		var start=old.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
		var head:Vector2=start.position+start.normal*.4
		for tick in 240:
			old.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60);current.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
			head=old.move(head,head+Vector2.RIGHT*2.2,28)
	var before_us=0;var after_us=0
	for batch in 6:
		for order in 2:
			var optimized=(batch+order)%2==0
			var world=current if optimized else old
			var began=Time.get_ticks_usec()
			for q in queries:world.wall_hit(q[0],q[1],q[2])
			var elapsed=Time.get_ticks_usec()-began
			if optimized:after_us+=elapsed
			else:before_us+=elapsed
	var report={"passed":differences.is_empty(),"exact_contact_comparisons":comparisons,"differences":differences,"paired_queries":queries.size()*6,"before_us":before_us,"after_us":after_us,"scope":"Identical first contact including time, normal, cell and position; before and after mining. Query benchmark, not FPS."}
	FileAccess.open("res://artifacts/cave-sweep-clipping-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
