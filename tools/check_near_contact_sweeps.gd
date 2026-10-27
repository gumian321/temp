extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Candidate=preload("res://tools/cave_near_contact_world.gd")
var comparisons=0
var differences=0
var first_difference:Dictionary={}
func make_reference_world():return World.new()
func make_candidate_world():return Candidate.new()
func candidate_stats(candidate)->Dictionary:return {}
func candidate_valid(candidate)->bool:return true
func report_path()->String:return "res://artifacts/near-contact-sweep-check-20261027.json"
func test_radii()->Array:return [1.0,15.0,31.5,64.0]
func extra_starts()->Array:return []
func _initialize():call_deferred("execute")
func compare(reference,candidate,start:Vector2,finish:Vector2,radius:float,stage:String):
	var expected=reference.wall_hit(start,finish,radius)
	var actual=candidate.wall_hit(start,finish,radius)
	comparisons+=1
	if expected!=actual:
		differences+=1
		if first_difference.is_empty():first_difference={"stage":stage,"start":start,"finish":finish,"radius":radius,"expected":expected,"actual":actual}
func execute():
	var rows:Array=[]
	var rng=RandomNumberGenerator.new();rng.seed=20261027
	for seed_value in [20261020,1]:
		var reference=make_reference_world();var candidate=make_candidate_world()
		reference.use_near_contact_probe=false
		reference.reset_cave(true,seed_value);candidate.reset_cave(true,seed_value)
		var starts:Array[Vector2]=[Vector2(370,0),Vector2(-370,0),Vector2(0,270),Vector2(0,-270),Vector2(384,384),Vector2(-384,-384),Vector2(1536,-768),Vector2(-1536,768)]
		starts.append_array(extra_starts())
		for i in 40:starts.append(Vector2(rng.randf_range(-1800,1800),rng.randf_range(-1800,1800)))
		for start in starts:
			for radius in test_radii():
				for direction_index in 12:
					var direction=Vector2.from_angle(float(direction_index)*TAU/12.0)
					for distance in [32.0001,128.0,1024.0,4096.0]:compare(reference,candidate,start,start+direction*distance,radius,"long")
		# Explicit guard fallbacks and finite large coordinates.
		for start in [Vector2(32767,0),Vector2(-32768,0),Vector2(0,32768),Vector2.ZERO]:
			for radius in [0.0,.5,64.001,96.0]:compare(reference,candidate,start,start+Vector2(33,0),radius,"guard")
		# Real excavation must invalidate local edge neighborhoods identically.
		for bite in 7:
			reference.dig(Vector2(370,0),Vector2.RIGHT,Vector2.RIGHT,40,.17,true)
			candidate.dig(Vector2(370,0),Vector2.RIGHT,Vector2.RIGHT,40,.17,true)
		for i in 60:
			var start=Vector2(370,0)+Vector2(rng.randf_range(-30,30),rng.randf_range(-80,80))
			compare(reference,candidate,start,start+Vector2.from_angle(rng.randf_range(-PI,PI))*rng.randf_range(33,2048),15,"excavated")
		# Probing may materialize additional deterministic, untouched chunks.
		# Compare the physical cells over their union, including those chunks.
		var loaded_before=[reference.chunks.size(),candidate.chunks.size()]
		var union_chunks=reference.chunks.keys()
		for key in candidate.chunks:
			if key not in union_chunks:union_chunks.append(key)
		for key in union_chunks:reference.chunk_at(key);candidate.chunk_at(key)
		rows.append({"seed":seed_value,"probes":candidate.near_contact_probes,"hits":candidate.near_contact_hits,"fallbacks":candidate.near_contact_fallbacks,"loaded_chunks_before_union":loaded_before,"excavation_state_equal":reference.chunks==candidate.chunks and reference.events==candidate.events and reference.loot_events==candidate.loot_events})
		rows[-1].merge(candidate_stats(candidate))
		if not rows[-1].excavation_state_equal:differences+=1
		if not candidate_valid(candidate):differences+=1
		await process_frame
	var report={"scope":"Strict original Dictionary equality for long sweeps with unchanged parameterization, positive/negative coordinates, radius boundaries, direction/length matrix and real excavation. Experimental near-contact helper only; no player saves are loaded or written.","comparisons":comparisons,"differences":differences,"first_difference":first_difference,"worlds":rows}
	FileAccess.open(report_path(),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if differences==0 else 1)
