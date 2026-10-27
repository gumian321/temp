extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/centipede.gd")
const Battle=preload("res://scripts/combat.gd")
class NoObstacles extends "res://scripts/chasm_world.gd":
	func nearby(_area:Rect2)->Array:return []
	func move(_start:Vector2,desired:Vector2,_radius:float)->Vector2:return desired
	func direction(origin:Vector2,target:Vector2,_radius:float,_memory:Dictionary)->Vector2:return origin.direction_to(target)
func _initialize():call_deferred("execute")
func signature(battle)->Array:
	var result:Array=[]
	for e in battle.enemies:
		var soft:Dictionary=e.get("soft_body",{})
		result.append([e.uid,e.position,e.angle,e.hp,e.age,soft.get("clock",0),soft.get("pose_clock",0),soft.get("cue_age",0)])
	return result
func execute():
	var db=DB.new();var prefab=""
	for id in db.entities:
		if db.entities[id].filter(func(b):return b.unit.get("class")=="AIBossPartController").size()==6:
			prefab=id;break
	if prefab.is_empty():push_error("Missing six-part boss fixture");quit(2);return
	var reference:Array=[];var timings:Array=[];var equal=true;var comparisons=0
	for optimized in [false,true,true,false]:
		var body=Body.new(db);var battle=Battle.new(db,body);battle.terrain=NoObstacles.new();battle.use_parent_pose_fastpath=optimized;battle.profile_enabled=true
		body.parts[0].hp=10000000;body.parts[0].max_hp=10000000
		for i in 28:battle.spawn(prefab,Vector2(1700+(i%7)*190,-800+(i/7)*210))
		var parts:Array=battle.enemies.filter(func(e):return e.kind=="AIBossPartController")
		for i in range(165,parts.size()):battle.enemies.erase(parts[i])
		var parents=battle.enemies.filter(func(e):return e.kind=="AIBossUnit")
		for e in battle.enemies:
			e.guns=[];e.warp=0;e.stun=0;e.movement={"enginePower":0.0,"rotEngineModifier":0.0};e.boost_left=-100;e.boost_cooldown=100000;e.heat_speed=false
			if e.kind=="AIBossUnit":e.parts=e.parts.filter(func(uid):return battle.enemies.any(func(child):return child.uid==uid))
		var first=reference.is_empty();var costs:Array=[]
		for frame in 300:
			for parent in parents:parent.angle=sin(frame*.017+float(parent.uid)*.11)*PI
			if frame==60:battle.phase_times.clear()
			var started=Time.get_ticks_usec();battle.step(1.0/30,Vector2.RIGHT*300,false,false)
			if frame>=60:costs.append(float(Time.get_ticks_usec()-started)/1000)
			var state=signature(battle)
			if first:reference.append(state)
			else:equal=equal and state==reference[frame];comparisons+=state.size()
		var total=0.0
		for cost in costs:total+=cost
		costs.sort();var phases={}
		for key in battle.phase_times:phases[key]=float(battle.phase_times[key])/240000
		timings.append({"optimized":optimized,"mean_ms":total/costs.size(),"p95_ms":costs[int(costs.size()*.95)],"max_ms":costs[-1],"phases_mean_ms":phases,"actors":battle.enemies.size(),"attached_parts":battle.enemies.filter(func(e):return e.kind=="AIBossPartController").size()})
	var passed=equal and timings.all(func(t):return t.attached_parts==165 and t.phases_mean_ms.get("enemy_navigation",0)==0)
	var report={"passed":passed,"comparisons":comparisons,"timings":timings,"scope":"Isolated 28 parents / 165 real-prefab attached parts, no guns or obstacles, no navigation. Same parent angles each frame, first 60 warmup ticks excluded. Exact pose/HP/age/clock comparisons. CPU pipeline diagnostic, not game FPS."}
	FileAccess.open("res://artifacts/deep50-parent-dense.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if passed else 1)
