extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Reference=preload("res://tests/cave_clearance_reference.gd")
func _initialize():call_deferred("execute")
func execute():
	var old=Reference.new();var current=World.new();old.reset_cave(true);current.reset_cave(true)
	var rng=RandomNumberGenerator.new();rng.seed=20261021
	var queries=[]
	for i in 2400:
		var at=Vector2(rng.randf_range(-450,1100),rng.randf_range(-400,450))
		queries.append([at,[0.0,15.0,27.0,48.0,15.000000001,15.000000002][i%6]])
	var differences=0;var compared=0
	for stage in 2:
		for repeat in 2:
			for q in queries:
				compared+=1
				if old.wall_blocked(q[0],q[1])!=current.wall_blocked(q[0],q[1]):differences+=1
		var entry=old.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
		var head:Vector2=entry.position+entry.normal*.4
		for tick in 240:
			old.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60);current.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
			head=old.move(head,head+Vector2.RIGHT*2.2,28)
	var before_us=0;var after_us=0
	for batch in 6:
		for order in 2:
			var optimized=(batch+order)%2==0
			var world=current if optimized else old
			var began=Time.get_ticks_usec()
			for q in queries:world.wall_blocked(q[0],q[1])
			var elapsed=Time.get_ticks_usec()-began
			if optimized:after_us+=elapsed
			else:before_us+=elapsed
	for i in 9000:current.wall_blocked(Vector2(-40+float(i%100)*.0001,float(i/100)*.0001),0)
	var bounded=current.clear_point_count<=8192
	current.reset_cave(true,111)
	var reset=current.clear_points.is_empty() and current.clear_point_count==0
	var report={"passed":differences==0 and bounded and reset,"exact_queries":compared,"differences":differences,"paired_queries":14400,"before_us":before_us,"after_us":after_us,"bounded":bounded,"reset_cleared":reset,"scope":"Exact full-precision circle/point clearance before and after mining; no blocked answer is cached. Query timing only, not FPS."}
	FileAccess.open("res://artifacts/cave-clearance-cache-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
