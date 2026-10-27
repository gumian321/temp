extends SceneTree
const Spatial=preload("res://scripts/combat_spatial_index.gd")
class Catalog:
	var classes={"gun":"GunCore","shield":"ShieldCore","pulse":"GunCore"}
	var sprites:Dictionary={}
	func asset(id):return {"class":classes.get(id,"GunCore")}
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func actor(uid:int,at:Vector2)->Dictionary:
	return {"uid":uid,"position":at,"hp":100.0,"damageable":true,"role":"","radius":20.0,"guns":[],"kind":"Enemy","render":[]}
func same_refs(a:Array,b:Array)->bool:
	if a.size()!=b.size():return false
	for i in a.size():
		if not is_same(a[i],b[i]):return false
	return true
func membership(index)->Dictionary:
	var result:Dictionary={}
	for cell in index.cells:
		var indices=index.cells[cell].duplicate();indices.sort();result[cell]=indices
	return result
func metadata_same(a,b)->bool:
	return a.by_uid==b.by_uid and a.locations==b.locations and membership(a)==membership(b) and a.max_radius==b.max_radius and a.extent_low==b.extent_low and a.extent_high==b.extent_high and same_refs(a.shield_actors,b.shield_actors) and same_refs(a.allies,b.allies)
func brute_nearest(source:Array,at:Vector2,reach:float)->Dictionary:
	var result:Dictionary={};var best=reach*reach
	for e in source:
		if e.hp<=0 or not e.damageable or e.role=="friendly":continue
		var distance=at.distance_squared_to(e.position)
		if distance<best:best=distance;result=e
	return result
func check_queries(raw,cached,source:Array,rng)->bool:
	var same=true
	for i in 8:
		var at=Vector2(rng.randf_range(-1000,6000),rng.randf_range(-1000,4000))
		var reach=INF if i%3==0 else rng.randf_range(0,2500)
		var expected=brute_nearest(source,at,reach)
		var actual=cached.nearest(at,reach)
		same=same and (actual.is_empty() and expected.is_empty() or is_same(actual,expected))
		var radius=rng.randf_range(0,2400)
		var low=at-Vector2.ONE*radius;var high=at+Vector2.ONE*radius
		same=same and same_refs(raw.query(low,high),cached.query(low,high))
	return same
func execute():
	var db=Catalog.new();var raw=Spatial.new();raw.use_cell_reuse=false
	var cached=Spatial.new();cached.use_cell_reuse=true
	var source:Array=[]
	for i in 120:
		var e=actor(i+1,Vector2(i%16,i/16)*Spatial.CELL+Vector2.ONE*128)
		if i%7==0:e.role="friendly"
		if i%11==0:e.guns=[{"id":"shield"}]
		if i%13==0:e.hp=0
		source.append(e)
	for index in [raw,cached]:index.rebuild(source,db)
	var low=Vector2(-1000,-1000);var high=Vector2(9000,9000)
	var key=Vector4i(int(floor(low.x/256)),int(floor(low.y/256)),int(floor(high.x/256)),int(floor(high.y/256)))
	cached.query(low,high);var retained:Array=cached.query_cache[key]
	source[0].position+=Vector2(2,3);source[1].role="friendly";source[2].hp=0
	source[3].guns=[{"id":"pulse"}];source[4].radius=1800.0;db.classes.pulse="ShieldCore"
	source=source.filter(func(_e):return true)
	for index in [raw,cached]:index.rebuild(source,db)
	check(cached.full_rebuilds==1 and cached.reuse_frames==1 and metadata_same(raw,cached) and is_same(cached.query_cache[key],retained),"A fresh filter Array with the same ordered live actors retains cell/query ownership while all mutable faction/gun/catalog/radius/HP metadata refreshes")
	check(same_refs(cached.query(low,high),source) and cached.query(low,high)[2].hp==0,"Retained queries preserve source order, dead actors and current live Dictionary values")
	source[0].position+=Vector2(800,-1000)
	for index in [raw,cached]:index.rebuild(source,db)
	check(cached.query_cache.is_empty() and cached.reuse_frames==2 and metadata_same(raw,cached),"Cross-cell movement invalidates cached membership and recomputes exact current extents")
	var rng=RandomNumberGenerator.new();rng.seed=20261026
	var same=true
	for frame in 120:
		for i in source.size():
			if (i+frame)%5==0:source[i].position+=Vector2(rng.randf_range(-400,400),rng.randf_range(-400,400))
		var e:Dictionary=source[frame%source.size()]
		e.role="friendly" if frame%3==0 else "";e.hp=0.0 if frame%4==0 else 100.0
		e.damageable=frame%7!=0;e.radius=5.0+frame*7
		e.guns=[{"id":"gun"},{"id":"pulse"}] if frame%2==0 else []
		if frame%17==0:e.kind="Asteroid";e.charcoal_extent=333.0+frame
		db.classes.pulse="ShieldCore" if frame%2 else "GunCore"
		source=source.filter(func(_actor):return true)
		for index in [raw,cached]:index.rebuild(source,db)
		same=same and metadata_same(raw,cached) and check_queries(raw,cached,source,rng)
	check(same and cached.full_rebuilds==1 and cached.reuse_frames==122,"120 changing-position frames match fresh membership, mineral/ordinary radii, live metadata, query ordering and brute nearest without rebuilding cells")
	var fallback_count=0
	for mutation in ["append","remove","reverse","same_uid_new_dictionary","new_uid_dictionary","uid_mutation","bad_uid_map","missing_uid_map"]:
		cached.query(low,high)
		var before=cached.full_rebuilds
		match mutation:
			"append":source.append(actor(9999,Vector2(40,40)))
			"remove":source.remove_at(source.size()-1)
			"reverse":source.reverse()
			"same_uid_new_dictionary":source[5]=source[5].duplicate(true)
			"new_uid_dictionary":source[5]=actor(10001,source[5].position)
			"uid_mutation":source[3].uid=10002
			"bad_uid_map":cached.by_uid[source[0].uid]=1
			"missing_uid_map":cached.by_uid.erase(source[1].uid)
		for index in [raw,cached]:index.rebuild(source,db)
		var correct=cached.full_rebuilds==before+1 and cached.query_cache.is_empty() and metadata_same(raw,cached) and check_queries(raw,cached,source,rng)
		check(correct,"Full fallback validates actor count/identity/UID order/by_uid after "+mutation)
		fallback_count+=1
	# Reordering/replacing within the very same Array must be detected even
	# though actors already aliases that Array. Cached Dictionary refs do not.
	var before=cached.full_rebuilds;var replacement=source[0].duplicate(true)
	source[0]=replacement
	for index in [raw,cached]:index.rebuild(source,db)
	check(cached.full_rebuilds==before+1 and is_same(cached.query(Vector2.ONE*-1000000,Vector2.ONE*1000000).filter(func(e):return e.uid==replacement.uid)[0],replacement),"Same-container same-UID replacement discards cached old Dictionary references")
	# Duplicate UIDs remain supported by the legacy full scan (last UID wins)
	# but cannot satisfy the bijection required for safe positional reuse.
	source=[actor(7,Vector2(1,2)),actor(7,Vector2(500,2))]
	for index in [raw,cached]:index.rebuild(source,db)
	before=cached.full_rebuilds
	for index in [raw,cached]:index.rebuild(source,db)
	check(cached.full_rebuilds==before+1 and metadata_same(raw,cached) and same_refs(raw.query(low,high),cached.query(low,high)),"Duplicate UIDs conservatively keep original full-rebuild semantics")
	source=[]
	for index in [raw,cached]:index.rebuild(source,db)
	var old_low=cached.extent_low;var old_high=cached.extent_high
	cached.query(low,high);before=cached.full_rebuilds
	for index in [raw,cached]:index.rebuild(source.filter(func(_e):return true),db)
	check(cached.full_rebuilds==before and metadata_same(raw,cached) and cached.extent_low==old_low and cached.extent_high==old_high and cached.max_radius==0 and cached.nearest(Vector2.ZERO,INF).is_empty() and cached.query(low,high).is_empty(),"Repeated empty wrappers preserve the original empty extents, zero metadata and public query results")
	var full_count=cached.full_rebuilds;var reuse_count=cached.reuse_frames
	cached.use_cell_reuse=false;cached.rebuild(source,db)
	check(cached.full_rebuilds==full_count+1 and cached.reuse_frames==reuse_count and cached.validated_count==-1 and cached.actor_refs.is_empty() and cached.uid_sequence.is_empty(),"Switching the opt-in candidate off returns to the original path and releases retained validation references")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"random_frames":120,"query_pairs":960,"full_rebuilds_before_disable":full_count,"reuse_frames":reuse_count,"explicit_mutation_fallbacks":fallback_count,"scope":"Optional cell/query persistence only; all metadata/catalog scans retain original per-frame semantics. Default remains disabled; no frame-rate claim."}
	print(JSON.stringify(report));FileAccess.open("res://artifacts/spatial-cell-reuse-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if report.passed else 1)
