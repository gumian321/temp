extends SceneTree
const World=preload("res://scripts/cave_world.gd")
class Reference extends "res://scripts/chasm_world.gd":
	func nearby(area:Rect2)->Array:
		if area.position.abs().max(area.end.abs()).length_squared()<1000*1000:return []
		return super.nearby(area).filter(func(pit):return Vector2(pit.at).length()>1700)
func _initialize():call_deferred("execute")
func execute():
	var original=Reference.new();var candidate=World.new()
	candidate.reset_cave(true)
	var rng=RandomNumberGenerator.new();rng.seed=20261021
	var areas:Array[Rect2]=[]
	for i in 4000:
		var at=Vector2(rng.randf_range(-15000,15000),rng.randf_range(-15000,15000))
		var size=Vector2(rng.randf_range(0,2000),rng.randf_range(0,2000)) if i%7==0 else Vector2.ONE*rng.randf_range(0,240)
		areas.append(Rect2(at,size))
	for x in range(-4,5):
		for y in range(-4,5):
			for offset in [-.01,0,.01]:areas.append(Rect2(Vector2(x,y)*1450+Vector2(430,270)+Vector2.ONE*(620+offset),Vector2.ZERO))
	var differences=0
	for area in areas:
		if original.nearby(area)!=candidate.nearby(area):differences+=1
	var source_us=0;var candidate_us=0
	# Moving footprints in several map columns, paired with opposite order.
	for batch in 8:
		var queries:Array[Rect2]=[]
		for tick in 60:
			for actor in 64:
				queries.append(Rect2(Vector2((actor%8)*900-3500,(actor/8)*1100-3000)+Vector2.from_angle(tick*.003+actor)*170,Vector2.ZERO).grow(32))
		for pass_index in 2:
			var is_candidate=(batch+pass_index)%2==1
			var world=candidate if is_candidate else original
			var began=Time.get_ticks_usec()
			for area in queries:world.nearby(area)
			var elapsed=Time.get_ticks_usec()-began
			if is_candidate:candidate_us+=elapsed
			else:source_us+=elapsed
	var bounded=candidate.legacy_regions.size()<=256
	candidate.reset_cave(true,111)
	var cleared=candidate.legacy_regions.is_empty()
	candidate.reset_cave(false)
	var disabled_same=preload("res://scripts/chasm_world.gd").new().nearby(Rect2(-1300,-1000,2600,2000))==candidate.nearby(Rect2(-1300,-1000,2600,2000))
	var report={"passed":differences==0 and bounded and cleared and disabled_same,"areas":areas.size(),"ordered_geometry_differences":differences,"bounded":bounded,"reset_cleared":cleared,"disabled_same":disabled_same,"paired_moving_queries":8*60*64,"source_us":source_us,"candidate_us":candidate_us}
	FileAccess.open("res://artifacts/cave-nearby-regions-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
