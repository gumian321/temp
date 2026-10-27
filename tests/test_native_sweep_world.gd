extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Native=preload("res://tools/native_sweep_world.gd")
func _initialize():call_deferred("execute")
func execute():
	var old=World.new();var current=Native.new();old.reset_cave(true);current.reset_cave(true)
	if current.native_kernel==null:push_error("Native prototype was not loaded");quit(2);return
	var rng=RandomNumberGenerator.new();rng.seed=2026102610
	var differences:Array=[];var comparisons=0
	for i in 600:
		var origin=Vector2(-8400,-3113) if i%3==0 else Vector2(480,80)
		var start=origin+Vector2(rng.randf_range(-140,140),rng.randf_range(-140,140))
		var radius:float=[0.0,1.0,15.000000001,28.0,64.0,128.0,287.963623046875,512.0][i%8]
		var length:float=[.000001,.5,1.0,2.0,8.0,16.0,32.0][i%7]
		var finish=start+Vector2.from_angle(rng.randf_range(-PI,PI))*length
		for repeat in 2:
			var expected=old.wall_hit(start,finish,radius);var actual=current.wall_hit(start,finish,radius);comparisons+=1
			if expected!=actual and differences.size()<8:differences.append({"case":comparisons,"start":start,"finish":finish,"radius":radius,"expected":expected,"actual":actual})
	var head=Vector2(440,20)
	for tick in 240:
		for world in [old,current]:world.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
		var desired=head+Vector2(2.2,.1)
		var expected=old.move(head,desired,28);var actual=current.move(head,desired,28);comparisons+=1
		if expected!=actual and differences.size()<8:differences.append({"mining_tick":tick,"expected":expected,"actual":actual})
		head=expected
	var stats=current.native_stats()
	var report={"passed":differences.is_empty() and stats.loaded and stats.queries>0,"comparisons":comparisons,"differences":differences,"native":stats,"scope":"Exact first-contact dictionaries and normal repeated excavation movement; isolated native local-sweep prototype only."}
	FileAccess.open("res://artifacts/native-sweep-world.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
