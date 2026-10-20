extends SceneTree
const World = preload("res://scripts/chasm_world.gd")
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Run = preload("res://scripts/run_state.gd")
const Save = preload("res://scripts/save_store.gd")
var checks: Array = []
func _initialize(): call_deferred("execute")
func check(ok: bool, label: String):
	checks.append({"name":label,"passed":ok})
	if not ok: printerr("FAIL: ",label)

func execute():
	var terrain = World.new()
	var pits = terrain.nearby(Rect2(-1300,-1000,2600,2000))
	check(pits.size()>=5,"All opening pits participate without a viewport")
	check(not terrain.blocked(Vector2.ZERO,40),"Default player spawn remains traversable")
	for pit in pits:
		var center = Rect2(pit.bounds).get_center()
		check(terrain.blocked(center),"Painted opening is solid: "+pit.id)
		var safe = terrain.safe_position(center,40)
		check(not terrain.blocked(safe,40),"Spawn in pit relocates to shore: "+pit.id)
		var start = center-Vector2(650,0)
		var end = center+Vector2(650,0)
		var hit = terrain.move(start,end,30)
		check(not terrain.blocked(hit,30) and not terrain.clear_segment(start,end,30) and hit.distance_to(end)>100,"Continuous sweep stops a 1300px crossing: "+pit.id)
	var distant = terrain.nearby(Rect2(10000,-13000,2000,2000))
	check(not distant.is_empty() and terrain.blocked(Rect2(distant[0].bounds).get_center()),"Generated distant pits collide off camera")
	# Reuse a production opening for the navigation and body fixtures.
	var pit=terrain.shape("opening:0",World.OPENING[0],1.0,0.0)
	var center = Rect2(pit.bounds).get_center()
	var start = Vector2(pit.bounds.position.x-90,center.y)
	var goal = Vector2(pit.bounds.end.x+90,center.y)
	for fps in [30,60,120]:
		var point = start
		var memory = {}
		var safe = true
		for frame in fps*14:
			var direction = terrain.direction(point,goal,22,memory)
			point = terrain.move(point,point+direction*150.0/fps,22)
			safe=safe and not terrain.blocked(point,22)
			if point.distance_to(goal)<3: break
		check(safe and point.distance_to(goal)<20,"AI routes around lip and reaches other shore at %d FPS (remaining %.1f)"%[fps,point.distance_to(goal)])
	var db = DB.new()
	for character in ["centipede","spider"]:
		var body = Body.new(db);body.configure_character(character);body.terrain=terrain
		body.head=start;body.facing=Vector2.RIGHT;body.refresh_positions()
		body.max_fuel=10000;body.fuel=10000
		var safe = true
		for frame in 240:
			body.step(1.0/60.0,Vector2.RIGHT,true)
			safe=safe and not terrain.blocked(body.head,body.collision_radius(0))
		check(safe and body.head.x<goal.x-100,character+" cannot walk/boost across pit")
		var battle = Battle.new(db,body)
		body.head=start;body.facing=Vector2.RIGHT;body.refresh_positions()
		battle.character_abilities.rush_direction=Vector2.RIGHT
		safe=true
		for frame in 40:
			battle.character_abilities.advance_rush(.1)
			safe=safe and not terrain.blocked(body.head,body.collision_radius(0))
		check(safe,"Rush movement respects "+character+" collision radius")
	var body = Body.new(db);body.terrain=terrain;body.head=start;body.facing=Vector2.DOWN
	for i in 8: body.append_segment(db.named("Core_Gun_Gatling").id)
	body.refresh_positions()
	var safe = true
	var memory = {}
	for frame in 900:
		body.step(1.0/60.0,terrain.direction(body.head,goal,34,memory),false)
		for i in body.parts.size():
			var outside=not terrain.blocked(body.parts[i].position,body.collision_radius(i)-.5)
			safe=safe and outside
	check(safe,"Eight following body segments stay on land around the pit")
	body.begin_coil();safe=true
	for frame in 180:
		body.step(1.0/60.0,Vector2.ZERO,false)
		for part in body.parts:safe=safe and not terrain.blocked(part.position,26.5)
	body.end_coil()
	for frame in 600:
		body.step(1.0/60.0,Vector2.ZERO,false)
		for part in body.parts:safe=safe and not terrain.blocked(part.position,26.5)
	check(safe and not body.coil_rig.engaged(),"Coil/uncoil stays on shore and completes without a stuck transition")
	for kind in ["AISwarmingUnit","AIFollowingUnit","AIPatrolUnit"]:
		body = Body.new(db);body.terrain=terrain;body.head=goal;body.refresh_positions();body.parts[0].hp=1e9
		var battle = Battle.new(db,body)
		var e = battle.spawn(db.pool["250"],center)
		check(not terrain.blocked(e.position,e.radius),kind+" spawn is relocated off pit")
		e.kind=kind;e.position=start;e.ground_previous=start;e.ground_radius=22.0;e.radius=22.0;e.angle=0.0;e.warp=0;e.components=[];e.guns=[];e.stop_distance=0
		e.unit=e.unit.duplicate(true);e.unit.isDisableIfFar=false
		e.movement={"enginePower":3.0,"rotEngineModifier":120.0}
		safe=true
		for frame in 1500:
			battle.step(1.0/60.0,goal,false,false)
			safe=safe and not terrain.blocked(e.position,e.radius)
			if Vector2(e.position).distance_to(goal)<70: break
		check(safe and Vector2(e.position).distance_to(goal)<100,kind+" production AI routes around pit (remaining %.1f)"%Vector2(e.position).distance_to(goal))
		e.position=start;e.ground_previous=start
		battle.move_actor(e,goal)
		check(not terrain.blocked(e.position,e.radius) and Vector2(e.position).distance_to(goal)>100,kind+" forced movement cannot tunnel")
	var save=Save.new(db);save.path="user://chasm-missions.json"
	var boss_prefab=""
	for prefab in db.entities:
		if db.entities[prefab].any(func(blueprint):return blueprint.unit.get("class","")=="AIBossUnit"):
			boss_prefab=prefab;break
	body=Body.new(db);body.terrain=terrain
	var boss_battle=Battle.new(db,body)
	var boss=boss_battle.spawn(boss_prefab,center)
	check(not boss.is_empty() and boss_battle.enemies.all(func(e):return not terrain.blocked(e.position,e.radius)),"Boss and attached parts spawn with the full footprint on land")
	if not boss.is_empty() and not boss.parts.is_empty():
		var child=boss_battle.entity(boss.parts[0])
		boss_battle.move_actor(child,center)
		check(not terrain.blocked(child.position,child.radius) and Vector2(child.position).is_equal_approx(Vector2(boss.position)+Vector2(child.offset).rotated(boss.angle)),"Forced movement preserves attached boss parts on the protected parent")
	for mission in db.kind("Mission"):
		body=Body.new(db);body.terrain=terrain
		var battle=Battle.new(db,body)
		var run=Run.new(db,save,body,battle,mission,0)
		var valid=not terrain.blocked(body.head,body.collision_radius(0))
		for frame in 90:
			run.director.step(1.0/30.0)
			for e in battle.enemies:valid=valid and not terrain.blocked(e.position,float(e.radius)-.5)
		check(valid,"Mission spawns and scripted movement stay on land: "+mission.name)
	body=Body.new(db);body.terrain=terrain
	var dense=Battle.new(db,body)
	for i in 120:
		var e=dense.spawn(db.pool["250"],center+Vector2.from_angle(i*TAU/120)*650)
		e.warp=0;e.guns=[];e.components=[];e.unit=e.unit.duplicate(true);e.unit.isDisableIfFar=false
	var started=Time.get_ticks_usec()
	for frame in 60:dense.step(1.0/60.0,Vector2.RIGHT,false,false)
	var dense_ms=float(Time.get_ticks_usec()-started)/60000.0
	check(dense.enemies.all(func(e):return not terrain.blocked(e.position,e.radius-.5)),"120 simultaneously pursuing enemies remain outside pits")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	report.dense_average_step_ms=dense_ms
	FileAccess.open("res://artifacts/chasm-collision-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
