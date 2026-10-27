extends SceneTree
const World=preload("res://scripts/cave_world.gd")
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func execute():
	var cached=World.new();cached.reset_cave(true)
	var legacy=World.new();legacy.reset_cave(true);legacy.use_sweep_local_invalidation=false
	var raw=World.new();raw.reset_cave(true);raw.use_sweep_result_cache=false
	var contact=raw.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
	var head:Vector2=contact.position+contact.normal*.4
	var near_a=head;var near_b=head+Vector2.RIGHT*12
	var far_a=Vector2(3000,3000);var far_b=far_a+Vector2(8,0)
	for world in [cached,legacy]:
		world.movement_wall_hit(near_a,near_b,80)
		world.movement_wall_hit(far_a,far_b,80)
		world.movement_wall_hit(Vector2.ZERO,Vector2(12,0),80)
	for tick in 120:
		for world in [cached,legacy,raw]:world.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
	var hits=cached.sweep_result_hits
	var far=cached.movement_wall_hit(far_a,far_b,80)
	check(cached.removed_count>0 and cached.sweep_result_hits==hits+1 and far==raw.wall_hit(far_a,far_b,80),"A nearby bite retains a distant exact sweep result")
	hits=cached.sweep_result_hits
	var empty=cached.movement_wall_hit(Vector2.ZERO,Vector2(12,0),80)
	check(empty.is_empty() and cached.sweep_result_hits==hits+1,"Unchanged empty results remain memoized across excavation")
	var slots=cached.sweep_result_ring.size();var misses=cached.sweep_result_misses
	var near=cached.movement_wall_hit(near_a,near_b,80)
	check(cached.sweep_result_misses==misses+1 and cached.sweep_result_invalidations>0 and near==raw.wall_hit(near_a,near_b,80) and cached.sweep_result_ring.size()==slots,"An intersecting bite refreshes its slot without adding a duplicate ring key")
	near.injected=true
	check(cached.movement_wall_hit(near_a,near_b,80)==raw.wall_hit(near_a,near_b,80),"Refreshing an invalid contact still preserves caller-owned dictionaries")
	for repeat in 12:
		cached.revision+=1
		var box=Rect2i(Vector2i((head/24).floor())-Vector2i(5,5),Vector2i(11,11))
		cached.invalidate_sweep_results(box)
		cached.movement_wall_hit(near_a,near_b,80)
	check(cached.sweep_result_ring.size()==slots,"Repeated local invalidation never duplicates ring slots")
	misses=cached.sweep_result_misses;cached.revision+=1
	check(cached.movement_wall_hit(far_a,far_b,80)==raw.wall_hit(far_a,far_b,80) and cached.sweep_result_ring.size()==1 and cached.sweep_result_misses==misses+1,"Unknown revision jumps still discard all prior memoized sweeps")
	legacy.movement_wall_hit(far_a,far_b,80)
	check(legacy.sweep_result_ring.size()==1,"The diagnostic legacy switch retains full-revision invalidation")
	for i in World.SWEEP_RESULT_LIMIT+101:
		var a=Vector2(i*2,0);cached.movement_wall_hit(a,a+Vector2(12,0),80)
	check(cached.sweep_result_ring.size()==World.SWEEP_RESULT_LIMIT,"Local invalidation retains the 1024-entry memory bound")
	cached.reset_cave(true,37)
	check(cached.sweep_result_ring.is_empty() and cached.sweep_result_invalidations==0,"Seed changes clear memoized geometry and counters")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	print(JSON.stringify(report));FileAccess.open("res://artifacts/deep-sweep-invalidation-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if report.passed else 1)
