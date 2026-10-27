extends SceneTree
const World=preload("res://scripts/cave_world.gd")
var comparisons=0
var failures:Array=[]
var rows:Array=[]
var raw_us=0
var candidate_us=0
func _initialize():call_deferred("execute")
func probe(raw,candidate,point:Vector2,radius:float,label:String,witness:bool=false):
	var expected:bool;var actual:bool;var began=0
	if comparisons%2==0:
		began=Time.get_ticks_usec();expected=raw.wall_blocked(point,radius);raw_us+=Time.get_ticks_usec()-began
		began=Time.get_ticks_usec();actual=candidate.wall_blocked(point,radius);candidate_us+=Time.get_ticks_usec()-began
	else:
		began=Time.get_ticks_usec();actual=candidate.wall_blocked(point,radius);candidate_us+=Time.get_ticks_usec()-began
		began=Time.get_ticks_usec();expected=raw.wall_blocked(point,radius);raw_us+=Time.get_ticks_usec()-began
	comparisons+=1
	if expected!=actual and failures.size()<12:failures.append({"label":label,"point":point,"radius":radius,"expected":expected,"actual":actual})
	if witness and raw.material_certificates!=candidate.material_certificates and failures.size()<12:failures.append({"label":label,"scope":"material witness"})
func normalize_chunks(raw,candidate):
	var keys=raw.chunks.keys()
	for key in candidate.chunks:
		if key not in keys:keys.append(key)
	for key in keys:raw.chunk_at(key);candidate.chunk_at(key)
func execute():
	var rng=RandomNumberGenerator.new();rng.seed=20261027
	var radii=[0.0,.9999999999,1.0,1.0000000001,15.0,63.9999,64.0,67.5,108.723000001,202.798,287.963623046875,512.0]
	for seed_value in [20261020,1,-2147483649]:
		var raw=World.new();var candidate=World.new()
		raw.use_native_sweep=false;raw.use_native_overlap=false
		candidate.use_native_sweep=false;candidate.use_native_overlap=true;candidate.native_available=candidate.native_accel.ready()
		if not candidate.native_available:failures.append({"scope":"native library unavailable"});break
		for world in [raw,candidate]:
			world.reset_cave(true,seed_value);world.use_material_certificates=false;world.use_clearance_cache=false
		var points:Array=[Vector2.ZERO,Vector2(370,0),Vector2(-370,0),Vector2(384,384),Vector2(-384,-384),Vector2(-8400,-3113),Vector2(31000,-31000)]
		for i in 160:points.append(Vector2(rng.randf_range(-1800,1800),rng.randf_range(-1800,1800)))
		for pass_index in 2:
			for point in points:
				for radius in radii:probe(raw,candidate,point,radius,"seed/radius/repeat")
		var edges=raw.collision_row(0,-30,30)
		for i in mini(12,edges.size()):
			var edge=edges[i]
			for radius in [1.0,15.0,67.5,200.0]:
				for sign_value in [-1,1]:
					for epsilon in [-.002,0.0,.002]:probe(raw,candidate,(edge.a+edge.b)*.5+edge.normal*(radius+epsilon)*sign_value,radius,"tangent/half-open")
		for point in [Vector2(370,0),Vector2(-400,-400),Vector2(1150,0)]:
			normalize_chunks(raw,candidate)
			for bite in 5:raw.dig(point,Vector2.RIGHT,Vector2.RIGHT,40,.17,true);candidate.dig(point,Vector2.RIGHT,Vector2.RIGHT,40,.17,true)
			for i in range(0,points.size(),4):
				for radius in radii:probe(raw,candidate,points[i],radius,"real excavation")
		normalize_chunks(raw,candidate)
		if raw.chunks!=candidate.chunks or raw.events!=candidate.events or raw.loot_events!=candidate.loot_events:failures.append({"scope":"physical excavation state"})
		for world in [raw,candidate]:world.use_material_certificates=true;world.use_clearance_cache=true;world.clear_material_certificates();world.revision+=2
		for point in points.slice(0,32):
			for radius in radii:probe(raw,candidate,point,radius,"material witness and revision jump",true)
		var stats=candidate.native_accel.stats()
		if int(stats.get("overlapQueries",0))==0:failures.append({"scope":"native overlap was never exercised","stats":stats})
		rows.append({"seed":seed_value,"native":stats,"cache_entries":candidate.native_overlap_cache.order.size(),"cache_hits":candidate.native_overlap_cache.hits,"invalidations":candidate.native_overlap_cache.invalidations})
		await process_frame
	var report={"passed":failures.is_empty(),"comparisons":comparisons,"failures":failures,"worlds":rows,"component_timing":{"reference_us":raw_us,"candidate_us":candidate_us,"scope":"Same-process alternated identical overlap queries, includes cold caches, not full-game FPS"},"scope":"Complete wall_blocked bools, tangent/half-open borders, full precision radii, real excavation, material witnesses, cache reuse, revision jumps; native boundary only, original filled-center and certificates retained."}
	FileAccess.open("res://artifacts/cave-native-overlap-check-20261027.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
