extends "res://tests/test_captured_orbit_overlap_memo.gd"
## Optional research-world replay. Production game code remains unchanged.
const NearContactWorld=preload("res://tools/cave_near_contact_world.gd")

func make_fixture(db,snapshot:Dictionary,prototype:bool)->Dictionary:
	var fixture=super.make_fixture(db,snapshot,false)
	if not prototype:return fixture
	var world=NearContactWorld.new()
	world.use_near_contact_probe=true
	world.use_wall_overlap_memo=false
	world.reset_cave(bool(snapshot.terrain.enabled),int(snapshot.terrain.seed_value))
	for key in snapshot.terrain:world.set(key,snapshot.terrain[key].duplicate(true) if snapshot.terrain[key] is Dictionary or snapshot.terrain[key] is Array else snapshot.terrain[key])
	fixture.world=world;fixture.battle.terrain=world;fixture.body.terrain=world
	return fixture

func execute():
	var path=OS.get_environment("RBPEW_BATTLE_SNAPSHOT")
	if path.is_empty():path="res://artifacts/deep50-candidate1-live-20261026/stop-states/0915-battle-state.bin"
	var input=FileAccess.open(path,FileAccess.READ)
	if input==null:printerr("Missing captured format2 battle snapshot: ",path);quit(2);return
	var snapshot=input.get_var(false);input.close()
	if not snapshot is Dictionary or snapshot.get("format")!=2:printerr("Expected format2 battle snapshot");quit(2);return
	var db=DB.new();var raw=make_fixture(db,snapshot.duplicate(true),false);var candidate=make_fixture(db,snapshot.duplicate(true),true)
	var orbits=raw.battle.enemies.filter(func(actor):return float(actor.get("orbit_speed",0))!=0)
	check(not orbits.is_empty(),"Captured battle contains production map orbit actors")
	var radii:Array=[];var initial_rng=raw.battle.rng.state
	for actor in orbits:
		var radius=float(actor.get("ground_radius",actor.radius))
		if radius not in radii:radii.append(radius)
	var raw_us=0;var candidate_us=0;var wall_queries=0;var movement_queries=0
	# Interleave lane order to avoid an always-second warmup advantage. Timing
	# is this CPU component only and is never an FPS or acceptance measurement.
	for frame in 120:
		var dt=float([1.0/60,1.0/30,.008,.023][frame%4])
		for lane in ([raw,candidate] if frame%2==0 else [candidate,raw]):
			var began=Time.get_ticks_usec();lane.map.step_orbits(dt)
			var elapsed=Time.get_ticks_usec()-began
			if is_same(lane,raw):raw_us+=elapsed
			else:candidate_us+=elapsed
		same(actor_state(raw),actor_state(candidate),"production orbit complete actor state frame %d"%frame)
		if frame%20==0:
			for actor in raw.battle.enemies:
				if float(actor.get("orbit_speed",0))==0:continue
				var radius=float(actor.get("ground_radius",actor.radius));var at:Vector2=actor.position
				for shift in [Vector2.ZERO,Vector2(.0001,-.0001)]:
					var point=at+shift
					same(raw.world.wall_blocked(point,radius),candidate.world.wall_blocked(point,radius),"captured overlap unchanged")
					# Use the actual captured orbital destination, preserving its
					# original long displacement and full contact dictionary.
					var desired=Vector2(actor.origin)+Vector2(actor.orbit_offset)
					same(raw.world.wall_hit(point,desired,radius),candidate.world.wall_hit(point,desired,radius),"captured original-delta first contact")
					wall_queries+=1
					same(raw.world.move(point,desired,radius),candidate.world.move(point,desired,radius),"captured original-delta exact movement")
					movement_queries+=1
		if frame%20==19:await process_frame
	check(differences.is_empty(),"Production orbit actors and original-delta collision queries match exactly on every captured tick")
	check(raw.battle.rng.state==initial_rng and candidate.battle.rng.state==initial_rng,"Orbit replay consumes no additional combat RNG")
	check(candidate.world.near_contact_probes>0,"Actual captured orbit movement exercises the optional near-contact probe")
	check(candidate.world.near_contact_hits>0,"Actual captured orbit movement exercises a successful near-contact result")
	var report={"passed":checks.all(func(item):return item.passed),"checks":checks,"comparisons":comparisons,"differences":differences,"snapshot":path,"snapshot_elapsed":snapshot.run_elapsed,"ticks":120,"orbit_actors":orbits.size(),"radii":radii,"wall_queries":wall_queries,"movement_queries":movement_queries,"near_contact":{"probes":candidate.world.near_contact_probes,"hits":candidate.world.near_contact_hits,"fallbacks":candidate.world.near_contact_fallbacks},"component_timing":{"reference_orbit_total_us":raw_us,"prototype_orbit_total_us":candidate_us,"scope":"Interleaved production map.step_orbits CPU component; diagnostic only, cold caches included, no renderer/full battle/FPS claim."},"scope":"Independent format2 captured terrain and actor graphs; production map.step_orbits for 120 variable-dt ticks with identical captured player/view/projectile/drone/black-hole inputs. Complete actor dictionaries, combat/loot RNG, overlap decisions, original-delta first-contact dictionaries and movement positions compared exactly. Optional source-only research world, no fabricated radius, no production runtime edits, full battle advance, rendered pixels or real-clock acceptance claim."}
	FileAccess.open("res://artifacts/captured-orbit-near-contact-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
