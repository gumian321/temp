extends SceneTree
const Index=preload("res://scripts/combat_spatial_index.gd")
class FakeDB extends RefCounted:
	var catalog:Dictionary={"gun":{"class":"GunCore"},"shield":{"class":"ShieldCore"},"other":{"class":"GunCore"}}
	var calls=0
	func asset(id)->Dictionary:
		calls+=1
		return catalog.get(id,{})
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func state(index)->Dictionary:
	return {"cells":index.cells,"locations":index.locations,"by_uid":index.by_uid,"shields":index.shield_actors.map(func(e):return e.uid),"allies":index.allies.map(func(e):return e.uid),"max_radius":index.max_radius,"low":index.extent_low,"high":index.extent_high,"actor_refs":index.actor_refs,"uid_sequence":index.uid_sequence,"validated_count":index.validated_count,"query_cache":index.query_cache}.duplicate(true)
func execute():
	var db=FakeDB.new();var baseline=Index.new();var candidate=Index.new()
	baseline.use_spatial_build=false;candidate.use_spatial_build=true
	baseline.use_cell_reuse=false;candidate.use_cell_reuse=false
	var actors:Array=[]
	for i in 180:
		actors.append({"uid":i+1,"kind":"AISwarmingUnit","position":Vector2((i%17)*131-900,(i/17)*97-500),"radius":14.0+i%7,"hp":0.0 if i%13==0 else 100.0,"damageable":i%11!=0,"role":"friendly" if i%9==0 else "","guns":[{"id":"gun"},{"id":"other"}]+([{"id":"shield"}] if i%5==0 else [])})
	var comparisons=0;var failures:Array=[];var avoided_lookups=0
	for frame in 100:
		# Prime the prior coherent index before externally changing its actors.
		baseline.query(Vector2(-1000,-1000),Vector2(1000,1000));candidate.query(Vector2(-1000,-1000),Vector2(1000,1000))
		if frame==5:actors.reverse()
		if frame==10:actors[0].guns[0].id="shield"
		if frame==15:db.catalog.shield={"class":"GunCore"}
		if frame==20:db.catalog.other={"class":"ShieldCore"}
		if frame==25:actors[2].guns=[]
		if frame==30:db.catalog.other["class"]="GunCore"
		if frame==35:actors[3].role="friendly";actors[3].hp=0.0
		if frame==40:actors[4].guns.append({"id":"shield"})
		if frame==45:actors.remove_at(8)
		if frame==50:actors[0].position=Vector2(3000000,1000000)
		if frame==60:db.catalog.gun={"class":"ShieldCore"}
		if frame==70:actors[1].guns=[{"id":"missing"}]
		if frame==80:actors.clear()
		if frame==85:actors.append({"uid":900,"kind":"AISwarmingUnit","position":Vector2(-256,-256),"radius":123.0,"hp":1.0,"damageable":true,"role":"friendly","guns":[{"id":"gun"}]})
		# Rebuild must discard the cached membership after every external edit.
		db.calls=0;baseline.rebuild(actors,db);var before_calls=db.calls
		db.calls=0;candidate.rebuild(actors,db);avoided_lookups+=before_calls-db.calls
		comparisons+=1
		if state(baseline)!=state(candidate):failures.append({"frame":frame,"scope":"rebuild state"})
		for query in [Rect2(-1024,-1024,2048,2048),Rect2(-256,-256,512,512),Rect2(2999900,999900,200,200)]:
			comparisons+=1
			if baseline.query(query.position,query.end)!=candidate.query(query.position,query.end):failures.append({"frame":frame,"scope":"query"})
		comparisons+=1
		if baseline.nearest(Vector2.ZERO,INF)!=candidate.nearest(Vector2.ZERO,INF):failures.append({"frame":frame,"scope":"nearest"})
		if not actors.is_empty():
			actors[0].position+=Vector2(257,-257)
			baseline.moved(actors[0]);candidate.moved(actors[0]);comparisons+=1
			if state(baseline)!=state(candidate):failures.append({"frame":frame,"scope":"incremental move"})
	check(failures.is_empty(),"Inline rebuild preserves complete metadata, ordered buckets, extents, queries and incremental movement")
	check(avoided_lookups>1000,"Both cached false and cached true shield classifications avoid repeated DB lookups")
	var passed=checks.all(func(c):return c.passed)
	var report={"passed":passed,"checks":checks,"exact_comparisons":comparisons,"avoided_lookups":avoided_lookups,"failures":failures,"scope":"100 full rebuilds with live catalog class mutation/replacement, changed gun IDs, dead actors, allies, reordered/removed/empty arrays, far positions and subsequent spatial movement. No FPS assertion."}
	FileAccess.open("res://artifacts/deep50-spatial-build.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if passed else 1)
