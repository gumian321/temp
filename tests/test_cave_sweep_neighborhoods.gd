extends SceneTree
const World=preload("res://scripts/cave_world.gd")
var comparisons=0
var differences:Array=[]
func _initialize():call_deferred("execute")
func compare(old,current,a:Vector2,b:Vector2,r:float):
	var expected=old.wall_hit(a,b,r);var actual=current.wall_hit(a,b,r);comparisons+=1
	if expected!=actual and differences.size()<8:differences.append({"from":a,"to":b,"radius":r,"expected":expected,"actual":actual})
func execute():
	var old=World.new();var current=World.new();old.reset_cave(true);current.reset_cave(true);old.use_sweep_neighborhoods=false
	var rng=RandomNumberGenerator.new();rng.seed=20261022
	var radii=[0.0,1.0,15.0,15.000000001,15.000000002,27.0,45.0,64.0,128.0,287.963623046875,512.0,513.0]
	var queries:Array=[]
	for i in 240:
		var center=Vector2(-8400,-3113) if i%3==0 else Vector2(480,80)
		var a=(center+Vector2(rng.randf_range(-140,140),rng.randf_range(-140,140))).snapped(Vector2.ONE*8)
		a+=Vector2.ONE*[-.0001,0.0,.0001][i%3]
		for r in radii:
			var length:float=[.000001,.5,1.0,2.0,4.0,8.0,8.001,12.0,16.0,16.001,24.0,32.0,32.001][i%13]
			var direction=Vector2.from_angle(rng.randf_range(-PI,PI)) if i%4>1 else (Vector2.RIGHT if i%4==0 else Vector2.DOWN)
			queries.append([a,a+direction*length,r])
	for repeat in 2:
		for q in queries:compare(old,current,q[0],q[1],q[2])
	# Grow, then reuse the conservative superset for shorter corner contacts.
	for length in [32.0,16.0,8.0,2.0,.5,24.0,4.0]:
		for radius in [64.0,128.0,287.963623046875,512.0]:
			for i in 16:
				var a=Vector2(480,80)+Vector2.ONE*.001
				compare(old,current,a,a+Vector2.from_angle(TAU*i/16)*length,radius)
	var entry=old.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
	var head:Vector2=entry.position+entry.normal*.4
	for tick in 300:
		for r in [0.0,15.0,28.0,64.0,288.0]:compare(old,current,head,head+Vector2.RIGHT*2.2,r)
		old.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60);current.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
		var desired=head+Vector2.RIGHT*2.2
		var expected=old.move(head,desired,28);var actual=current.move(head,desired,28);comparisons+=1
		if expected!=actual and differences.size()<8:differences.append({"mining_tick":tick,"expected":expected,"actual":actual})
		head=expected
	for i in 620:current.wall_hit(Vector2(i*8,0),Vector2(i*8+1,0),15)
	var entries=0
	for bucket in current.sweep_neighborhoods.values():entries+=bucket.size()
	var bounded=entries<=World.SWEEP_NEIGHBORHOOD_LIMIT and entries==current.sweep_neighborhood_order.size()
	var mined=current.removed_count>0 and current.removed_count==old.removed_count
	current.reset_cave(true,111)
	var reset=current.sweep_neighborhoods.is_empty() and current.sweep_neighborhood_order.is_empty()
	var report={"passed":differences.is_empty() and bounded and reset and mined,"comparisons":comparisons,"differences":differences,"bounded":bounded,"reset":reset,"mining":mined,"scope":"Exact first contacts through 32px, growing/superset reuse, negative/cell boundary coordinates, inside starts, full-precision radii through 513px, repeated excavation and bounded cache lifetime."}
	FileAccess.open("res://artifacts/cave-sweep-neighborhoods-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
