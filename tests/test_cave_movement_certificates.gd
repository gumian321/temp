extends SceneTree
const World=preload("res://scripts/cave_world.gd")
func _initialize():call_deferred("execute")
func execute():
	var reference=World.new();reference.reset_cave(true);reference.move_certificate_step=32
	var rng=RandomNumberGenerator.new();rng.seed=20261021
	var queries=[]
	for actor in 160:
		var radius:float=[15.0,28.0,48.0][actor%3]
		var at=reference.safe_position(Vector2(rng.randf_range(-1200,1200),rng.randf_range(-900,900)),radius)
		var angle=rng.randf_range(-PI,PI)
		for tick in 40:
			var desired=at+Vector2.from_angle(angle+tick*.035)*rng.randf_range(.4,2.8)
			queries.append([at,desired,radius]);at=reference.move(at,desired,radius)
	var results=[];var worst=0.0
	for step_size in [32.0,16.0,8.0]:
		var world=World.new();world.reset_cave(true);world.move_certificate_step=step_size
		# Warm geometry separately; time the actual moving query stream afterward.
		for query in queries:world.move(query[0],query[1],query[2])
		var total=0
		for repeat in 3:
			var began=Time.get_ticks_usec()
			for query in queries:world.move(query[0],query[1],query[2])
			total+=Time.get_ticks_usec()-began
		for query in queries:worst=maxf(worst,world.move(query[0],query[1],query[2]).distance_to(reference.move_contour(query[0],query[1],query[2])))
		results.append({"step":step_size,"usec":total,"cache_entries":world.free_regions.size()})
	# Exercise real cache eviction with thousands of distinct, tiny footprints
	# along one already valid wall contact. No synthesized cache bookkeeping.
	var bounded=World.new();bounded.reset_cave(true);bounded.move_certificate_step=.0001
	var entry=bounded.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
	var contact:Vector2=entry.position+entry.normal*.4
	for i in 10000:
		var at=contact+Vector2(i%100,i/100)*.0001
		bounded.move(at,at+Vector2(entry.normal)*.00002,28)
	var indexed=0;var consistent=true
	for tile in bounded.blocked_free_regions:
		for radius in bounded.blocked_free_regions[tile]:
			var key=Vector3i(tile.x,tile.y,radius);indexed+=1
			consistent=consistent and bounded.free_regions.has(key) and not bounded.free_regions[key]
	var cache_entries=bounded.free_regions.size()
	consistent=consistent and indexed==bounded.free_regions.values().count(false) and cache_entries<=8192 and indexed>7000
	bounded.reset_cave(true);bounded.move_certificate_step=16
	var cleared=bounded.blocked_free_regions.is_empty() and bounded.free_regions.is_empty()
	entry=bounded.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
	var head:Vector2=entry.position+entry.normal*.4
	var mining_error=0.0
	for tick in 240:
		bounded.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
		var desired=head+Vector2.RIGHT*2.2
		var exact=bounded.move_contour(head,desired,28);var cached=bounded.move(head,desired,28)
		mining_error=maxf(mining_error,exact.distance_to(cached));head=exact
	var report={"passed":worst<.002 and consistent and cleared and mining_error<.002 and bounded.removed_count>0,"moving_queries":queries.size(),"maximum_position_error":worst,"results":results,"eviction_entries":cache_entries,"negative_entries":indexed,"index_consistent":consistent,"reset_cleared":cleared,"post_bite_position_error":mining_error,"scope":"Same moving footprints against the full solver. Query timing only, not FPS."}
	FileAccess.open("res://artifacts/cave-movement-certificates-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
