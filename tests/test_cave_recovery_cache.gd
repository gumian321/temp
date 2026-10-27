extends SceneTree
const World=preload("res://scripts/cave_world.gd")
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(passed:bool,label:String):
	checks.append({"passed":passed,"label":label})
	if not passed:push_error(label)

# Frozen pre-cache movement algorithm: the oracle does not call the refactored
# recovery function, so a shared refactoring error cannot pass the comparison.
func reference_move(world,start:Vector2,desired:Vector2,radius:float)->Vector2:
	var legacy_area=Rect2(start,Vector2.ZERO).expand(desired).grow(radius*2)
	var legacy=preload("res://scripts/chasm_world.gd").new()
	# Cave mode omits the protected opening pits; use the world's original
	# ordered pit set with the same legacy sweep/recovery functions.
	var destination=desired
	if legacy_area.position.abs().max(legacy_area.end.abs()).length_squared()>=1000*1000:
		var pits=world.nearby(legacy_area)
		var point=legacy.safe_among(start,radius,pits)
		var delta=desired-start
		for slide in 4:
			if delta.length_squared()<.000001:break
			var hit=legacy.first_hit(point,point+delta,radius,pits)
			if hit.is_empty():point+=delta;break
			var travel=maxf(0,float(hit.time)-.4/maxf(delta.length(),.4))
			point+=delta*travel;delta*=1.0-travel
			var normal:Vector2=hit.normal;delta-=normal*minf(0,delta.dot(normal))
		destination=point
	var point=start
	var remaining=destination-start
	if world.wall_blocked(point,radius):
		var lip=world.separate_lip(point,radius)
		if lip!=Vector2.INF:point=lip
		else:
			var shapes:Array=[]
			var low=Vector2i(((point-Vector2.ONE*(radius+World.CELL))/World.CELL).floor())
			var high=Vector2i(((point+Vector2.ONE*(radius+World.CELL))/World.CELL).floor())
			for y in range(low.y,high.y+1):
				for x in range(low.x,high.x+1):shapes.append_array(world.cell_shape(Vector2i(x,y)).pieces)
			var clear=world.safe_among(point,radius,shapes)
			if point.distance_squared_to(clear)<World.CELL*World.CELL:point=clear
	for iteration in 3:
		if remaining.length_squared()<.0000001:break
		var hit=world.wall_hit(point,point+remaining,radius)
		if hit.is_empty():point+=remaining;break
		var travel=maxf(0,float(hit.time)-.35/maxf(.35,remaining.length()))
		point+=remaining*travel;remaining*=1.0-travel
		var normal:Vector2=hit.normal;remaining-=normal*minf(0,remaining.dot(normal))
	return point

func execute():
	var cached=World.new();var raw=World.new();cached.reset_cave(true);raw.reset_cave(true)
	raw.use_recovery_cache=false;raw.use_sweep_result_cache=false
	var rng=RandomNumberGenerator.new();rng.seed=20261026
	var starts:Array[Vector2]=[Vector2.ZERO,Vector2(760,0),Vector2(480,30),Vector2(1500,600),Vector2(-3000,1000)]
	for i in 24:starts.append(Vector2(rng.randf_range(-1400,2400),rng.randf_range(-800,1300)))
	var comparisons=0;var max_error=0.0
	for at:Vector2 in starts:
		for radius in [28.0,64.0,80.0001,108.723,202.79785,288.0,512.0,513.0]:
			for delta in [Vector2.ZERO,Vector2(.001,-.002),Vector2(2.2,1.1),Vector2(-8,3),Vector2(12,-5),Vector2(25,15)]:
				var expected=reference_move(raw,at,at+delta,radius)
				for repeat in 2:
					max_error=maxf(max_error,expected.distance_to(cached.move_contour(at,at+delta,radius)));comparisons+=1
	check(max_error==0,"Variable steps and repeated exact footprints match the frozen original movement solver")
	check(cached.recovery_hits>0,"Repeated footprint recovery is reused independently of requested displacement")
	var edited=World.new();var edit_reference=World.new();edited.reset_cave(true);edit_reference.reset_cave(true);edit_reference.use_recovery_cache=false
	var far=Vector2(3000,1000);var entry=edited.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
	var head:Vector2=entry.position+entry.normal*.4
	edited.movement_recovery(far,108.723)
	edited.movement_recovery(head,108.723)
	# This opening can contain six-health ore; run enough normal bites to
	# actually remove material before checking revision-based invalidation.
	for tick in 120:
		edited.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
		edit_reference.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
	var misses=edited.recovery_misses
	var far_result=edited.movement_recovery(far,108.723)
	check(edited.removed_count>0 and edited.recovery_misses==misses,"A distant excavation keeps an unrelated exact recovery footprint cached")
	check(far_result==edit_reference.recover_penetration(far,108.723) if edit_reference.wall_blocked(far,108.723) else far_result==far,"Retained distant recovery still matches the full current terrain query")
	var expected=edit_reference.recover_penetration(head,108.723) if edit_reference.wall_blocked(head,108.723) else head
	check(edited.movement_recovery(head,108.723)==expected and edited.recovery_misses==misses+1 and edited.recovery_invalidations>0,"An intersecting excavation recomputes its exact footprint without keeping stale geometry")
	# Warm an embedded footprint, excavate it, and verify that its former
	# penetration response cannot survive the topology revision.
	var at=Vector2(480,0);var radius=108.723
	cached.movement_recovery(at,radius)
	for world in [cached,raw]:
		for y in range(-12,13):
			for x in range(5,36):
				var cell=Vector2i(x,y);world.chunk_at(world.chunk_id(cell)).solid[world.cell_index(cell)]=0
		world.geometry.clear();world.collision_rows.clear();world.sweep_neighborhoods.clear();world.sweep_neighborhood_order.clear();world.clear_points.clear();world.clear_point_count=0;world.revision+=1
	check(cached.move_contour(at,at+Vector2(3,-1),radius)==reference_move(raw,at,at+Vector2(3,-1),radius),"Excavation invalidates blocked and clear recovery results")
	for i in World.RECOVERY_RESULT_LIMIT+17:cached.movement_recovery(Vector2(float(i%100)*.01,float(i/100)*.01),64)
	check(cached.recovery_ring.size()==World.RECOVERY_RESULT_LIMIT,"Recovery storage is bounded by a constant-time 512-slot ring")
	cached.reset_cave(true,42);raw.reset_cave(true,42)
	check(cached.recovery_ring.is_empty() and cached.recovery_hits==0,"Changing the world clears recovery keys and counters")
	check(cached.move_contour(at,at+Vector2(3,-1),radius)==reference_move(raw,at,at+Vector2(3,-1),radius),"A new seed cannot reuse a previous world's response")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"comparisons":comparisons,"max_position_error":max_error,"excavation_probe":{"removed_cells":edited.removed_count,"revision":edited.revision,"cache_revision":edited.recovery_revision,"invalidations":edited.recovery_invalidations}}
	FileAccess.open("res://artifacts/cave-recovery-cache-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
