extends SceneTree
## Replay inputs recorded by test_central_survival_profile (RBPEW_RECORD_MOVES=1).
## No rendering: measures collision queries, not gameplay FPS.
const World=preload("res://scripts/cave_world.gd")
func _initialize():call_deferred("execute")
func execute():
	var source=FileAccess.open("res://artifacts/central-movement-queries.bin",FileAccess.READ)
	if source==null:printerr("Run central_survival_profile with RBPEW_RECORD_MOVES=1 first");quit(1);return
	var queries:Array=source.get_var()
	var old=World.new();var current=World.new()
	old.reset_cave(true);current.reset_cave(true);old.use_sweep_neighborhoods=false
	var differences:Array=[];var old_times:Dictionary={};var new_times:Dictionary={};var counts:Dictionary={}
	for repeat in 3:
		for q in queries:
			var before:Vector2;var after:Vector2
			for order in 2:
				var optimized=(repeat+order)%2==0
				var world=current if optimized else old
				var began=Time.get_ticks_usec();var result=world.move(q[0],q[1],q[2]);var elapsed=Time.get_ticks_usec()-began
				var key=str(q[2])
				if optimized:after=result;new_times[key]=int(new_times.get(key,0))+elapsed
				else:before=result;old_times[key]=int(old_times.get(key,0))+elapsed
			if repeat==0:counts[str(q[2])]=int(counts.get(str(q[2]),0))+1
			if (before!=after or before!=q[3]) and differences.size()<10:differences.append({"query":q,"old":before,"new":after})
	var report={"passed":differences.is_empty(),"queries":queries.size(),"repeats":3,"differences":differences,"before_us":old_times,"after_us":new_times,"counts":counts,"scope":"Recorded central-chamber movement queries against identical rock, interleaved old/new exact-contact replay. Collision CPU only, not FPS."}
	FileAccess.open("res://artifacts/central-movement-replay.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
