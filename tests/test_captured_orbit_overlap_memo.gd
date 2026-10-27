extends SceneTree
## Captured late-battle orbit differential. This is a bounded correctness test,
## not a frame-rate benchmark or real-clock acceptance run.
const World=preload("res://scripts/cave_world.gd")
const Map=preload("res://scripts/map_director.gd")
const Battle=preload("res://scripts/combat.gd")
const Body=preload("res://scripts/centipede.gd")
const DB=preload("res://scripts/source_db.gd")
const Snapshot=preload("res://scripts/battle_snapshot.gd")
var checks:Array=[]
var differences:Array=[]
var comparisons=0

class OrbitSession extends RefCounted:
	var db
	var combat
	var player
	var configuration:Dictionary={}

func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func same(expected,actual,label:String):
	comparisons+=1
	if expected!=actual and differences.size()<12:differences.append({"label":label,"expected":str(expected),"actual":str(actual)})
func make_fixture(db,snapshot:Dictionary,memo:bool)->Dictionary:
	var world=World.new();world.use_wall_overlap_memo=memo
	world.use_near_contact_probe=false
	world.reset_cave(bool(snapshot.terrain.enabled),int(snapshot.terrain.seed_value))
	for key in snapshot.terrain:world.set(key,snapshot.terrain[key].duplicate(true) if snapshot.terrain[key] is Dictionary or snapshot.terrain[key] is Array else snapshot.terrain[key])
	var body=Body.new(db);Snapshot.apply_state(body,snapshot.states.player)
	var battle=Battle.new(db,body);battle.terrain=world
	Snapshot.apply_state(battle,snapshot.states.combat)
	# apply_state assigns dictionaries by reference. Each fixture owns its own
	# deserialized actor graph so one lane cannot change the other lane's input.
	battle.enemies=snapshot.states.combat["values"].enemies.duplicate(true)
	battle.bullets=snapshot.states.combat["values"].bullets.duplicate(true)
	battle.drones=snapshot.states.combat["values"].drones.duplicate(true)
	body.parts=snapshot.states.player["values"].parts.duplicate(true)
	if snapshot.states.get("special") is Dictionary:Snapshot.apply_state(battle.special,snapshot.states.special.duplicate(true))
	battle.spatial_active=false;battle.reindex_entity_hints()
	var session=OrbitSession.new();session.db=db;session.combat=battle;session.player=body
	# Map construction normally populates a grid; suppress those startup jobs.
	session.configuration={"mapEventsList":[],"emptyFirstLayerMapNodes":true}
	var map=Map.new(session,true)
	Snapshot.apply_state(map,snapshot.states.map.duplicate(true))
	# Keep the captured cadence/view configuration exactly; only the memo flag
	# differs. Disable instrumentation so clocks never enter state comparisons.
	map.use_remote_orbits=bool(snapshot.states.map["values"].get("use_remote_orbits",true))
	battle.profile_enabled=false;battle.diagnostic_profile=false
	return {"world":world,"body":body,"battle":battle,"map":map,"session":session}
func actor_state(fixture:Dictionary)->Dictionary:
	return {"actors":fixture.battle.enemies.duplicate(true),"rng":fixture.battle.rng.state,"loot_rng":fixture.battle.loot_rng.state,"moves":fixture.map.orbit_moves,"remote_skips":fixture.map.remote_orbit_skips}
func memo_counts(world)->Dictionary:
	var positive=0;var negative=0;var valid=0
	for entry in world.wall_overlap_ring:
		if entry.blocked:positive+=1
		else:negative+=1
		if entry.valid:valid+=1
	var clears=0
	for bucket in world.clear_points.values():clears+=bucket.size()
	return {"entries":world.wall_overlap_ring.size(),"positive":positive,"negative":negative,"valid":valid,"hits":world.wall_overlap_hits,"misses":world.wall_overlap_misses,"invalidations":world.wall_overlap_invalidations,"original_clear_points":clears}
func execute():
	var path=OS.get_environment("RBPEW_BATTLE_SNAPSHOT")
	if path.is_empty():path="res://artifacts/deep50-candidate1-live-20261026/stop-states/0915-battle-state.bin"
	var input=FileAccess.open(path,FileAccess.READ)
	if input==null:printerr("Missing captured format2 battle snapshot: ",path);quit(2);return
	var snapshot=input.get_var(false);input.close()
	if not snapshot is Dictionary or snapshot.get("format")!=2:printerr("Expected format2 battle snapshot");quit(2);return
	var db=DB.new();var raw=make_fixture(db,snapshot.duplicate(true),false);var cached=make_fixture(db,snapshot.duplicate(true),true)
	var orbits=raw.battle.enemies.filter(func(actor):return float(actor.get("orbit_speed",0))!=0)
	check(not orbits.is_empty(),"Captured battle contains production map orbit actors")
	var radii:Array=[];var eligible_orbits=0;var initial_rng=raw.battle.rng.state
	for actor in orbits:
		var radius=float(actor.get("ground_radius",actor.radius))
		if radius not in radii:radii.append(radius)
		if radius>=64 and radius<=512:eligible_orbits+=1
	# Freeze external inputs, then advance production step_orbits in both lanes.
	# Full actor dictionaries include positions, ground_previous and checked
	# radii, orbital phase, angle, and remote cadence bookkeeping.
	for frame in 120:
		var dt=float([1.0/60,1.0/30,.008,.023][frame%4])
		raw.map.step_orbits(dt);cached.map.step_orbits(dt)
		same(actor_state(raw),actor_state(cached),"production orbit actor state frame %d"%frame)
		if frame%20==0:
			for actor in raw.battle.enemies:
				if float(actor.get("orbit_speed",0))==0:continue
				var radius=float(actor.get("ground_radius",actor.radius));var at:Vector2=actor.position
				for shift in [Vector2.ZERO,Vector2(.0001,-.0001)]:
					var point=at+shift
					same(raw.world.wall_blocked(point,radius),cached.world.wall_blocked(point,radius),"captured exact overlap")
					var desired=point+Vector2(7,-3)
					same(raw.world.wall_hit(point,desired,radius),cached.world.wall_hit(point,desired,radius),"captured first contact dictionary")
					same(raw.world.move(point,desired,radius),cached.world.move(point,desired,radius),"captured exact movement")
		if frame%20==19:await process_frame
	check(differences.is_empty(),"All production orbit actors and exact collision queries match on every captured tick")
	check(raw.battle.rng.state==initial_rng and cached.battle.rng.state==initial_rng,"Production orbit replay consumes no additional combat RNG")
	if eligible_orbits==0:
		check(cached.world.wall_overlap_ring.is_empty() and cached.world.wall_overlap_hits==0 and cached.world.wall_overlap_misses==0,"Captured orbit radii lie outside 64..512: unchanged bypass creates no memo entries or queries")
	else:
		check(cached.world.wall_overlap_hits>0,"Captured eligible orbit movement exercises memo hits")
	var report={"passed":checks.all(func(item):return item.passed),"checks":checks,"comparisons":comparisons,"differences":differences,"snapshot":path,"snapshot_elapsed":snapshot.run_elapsed,"ticks":120,"orbit_actors":orbits.size(),"radii":radii,"memo_eligible_orbit_actors":eligible_orbits,"memo":memo_counts(cached.world),"reference_clear_points":raw.world.clear_point_count,"scope":"Two independent format2 captured terrain/actor graphs; production map.step_orbits at variable dt with identical captured player/view/projectile/drone/black-hole inputs; complete actor dictionaries and combat/loot RNG, overlap decisions, first-contact dictionaries and movement positions compared exactly. Memo coverage is conditional on actual captured orbit radii; the late-915 capture has radius-15 orbits and verifies unchanged bypass, not a map CPU improvement. Positive memo behavior is covered by the standalone memo unit test. No fabricated radii, full battle advance, rendered pixels, timing or FPS claim."}
	FileAccess.open("res://artifacts/captured-orbit-overlap-memo-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
