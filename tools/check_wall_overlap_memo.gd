extends SceneTree
const World=preload("res://scripts/cave_world.gd")
var comparisons=0
var differences=0
var first_difference:Dictionary={}

func _initialize():call_deferred("execute")

func compare(legacy,candidate,point:Vector2,radius:float,stage:String):
	var expected=legacy.wall_blocked(point,radius)
	var actual=candidate.wall_blocked(point,radius)
	comparisons+=1
	if expected!=actual:
		differences+=1
		if first_difference.is_empty():first_difference={"stage":stage,"point":point,"radius":radius,"expected":expected,"actual":actual}

func execute():
	var rows:Array=[]
	var rng=RandomNumberGenerator.new();rng.seed=20261027
	for world_seed in [20261020,1,-2147483649]:
		var legacy=World.new();var candidate=World.new()
		legacy.use_wall_overlap_memo=false;candidate.use_wall_overlap_memo=true
		legacy.reset_cave(true,world_seed);candidate.reset_cave(true,world_seed)
		var probes:Array=[]
		for point in [Vector2.ZERO,Vector2(384,384),Vector2(-384,-384),Vector2(383.999,384.001),Vector2(-384.001,-383.999),Vector2(432,0),Vector2(1500,-750)]:
			for radius in [0.0,63.999,64.0,64.000001,96.0,128.25,512.0,512.001]:probes.append([point,radius])
		for i in 180:
			probes.append([Vector2(rng.randf_range(-1600,1600),rng.randf_range(-1600,1600)),[64.0,96.0,128.25,256.0,512.0][i%5]])
		for pass_index in 2:
			for probe in probes:compare(legacy,candidate,probe[0],probe[1],"initial_%d"%pass_index)
		var memo_hits=candidate.wall_overlap_hits
		# Exercise real dig invalidation and its full state side effects. These
		# points span original rock, chamber boundaries and negative chunk seams.
		for point in [Vector2(440,0),Vector2(1150,0),Vector2(-400,-400),Vector2(1550,-900)]:
			for bite in 7:
				legacy.dig(point,Vector2.RIGHT,Vector2.RIGHT,40.0,.17,true)
				candidate.dig(point,Vector2.RIGHT,Vector2.RIGHT,40.0,.17,true)
			for probe in probes:compare(legacy,candidate,probe[0],probe[1],"excavation")
		var state_equal=legacy.chunks==candidate.chunks and legacy.revision==candidate.revision and legacy.removed_count==candidate.removed_count and legacy.ore_total==candidate.ore_total and legacy.events==candidate.events and legacy.loot_events==candidate.loot_events
		if not state_equal:differences+=1
		# A revision jump cannot trust local invalidation history.
		legacy.revision+=2;candidate.revision+=2
		for probe in probes:compare(legacy,candidate,probe[0],probe[1],"revision_jump")
		# Distinct full-precision radii at one point overflow the ring cheaply,
		# checking eviction and key separation without generating distant terrain.
		for i in range(World.WALL_OVERLAP_MEMO_LIMIT+17):compare(legacy,candidate,Vector2(500,0),64.0+float(i)*.00001,"ring_wrap")
		var bounded=candidate.wall_overlap_ring.size()<=World.WALL_OVERLAP_MEMO_LIMIT
		if not bounded or memo_hits==0:differences+=1
		rows.append({"seed":world_seed,"hits":candidate.wall_overlap_hits,"misses":candidate.wall_overlap_misses,"invalidations":candidate.wall_overlap_invalidations,"entries":candidate.wall_overlap_ring.size(),"state_equal":state_equal,"bounded":bounded,"revision":candidate.revision})
		legacy.reset_cave(false,world_seed+1);candidate.reset_cave(false,world_seed+1)
		var reset_empty=candidate.wall_overlap_ring.is_empty() and candidate.wall_overlap_memo.is_empty() and candidate.wall_overlap_hits==0
		if not reset_empty:differences+=1
		compare(legacy,candidate,Vector2(500,0),96,"disabled_reset")
		await process_frame
	var report={"scope":"Strict bool differential for complete wall overlap decisions; deterministic seeds, full precision radii, chunk seams, real excavation state, revision jumps, bounded ring wrap and disabled reset. Isolated worlds do not load or write player saves.","comparisons":comparisons,"differences":differences,"first_difference":first_difference,"worlds":rows}
	FileAccess.open("res://artifacts/wall-overlap-memo-check-20261027.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if differences==0 else 1)
