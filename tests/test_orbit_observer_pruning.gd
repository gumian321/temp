extends "res://tests/test_captured_orbit_overlap_memo.gd"

func visible(at:Vector2,head:Vector2,radius:float,observers:Array)->bool:
	if at.distance_squared_to(head)<=radius*radius:return true
	for observer:Vector3 in observers:
		if at.distance_squared_to(Vector2(observer.x,observer.y))<=observer.z*observer.z:return true
	return false

func execute():
	var path=OS.get_environment("RBPEW_BATTLE_SNAPSHOT")
	if path.is_empty():path="res://artifacts/cpu-depth-live-20261027/stop-states/1800-battle-state.bin"
	var input=FileAccess.open(path,FileAccess.READ)
	if input==null:printerr("Missing captured snapshot");quit(2);return
	var snapshot=input.get_var(false);input.close()
	var db=DB.new();var raw=make_fixture(db,snapshot.duplicate(true),false);var candidate=make_fixture(db,snapshot.duplicate(true),false)
	raw.map.use_orbit_observer_pruning=false;candidate.map.use_orbit_observer_pruning=true
	var total=0;var kept=0;var raw_us=0;var candidate_us=0
	for frame in 120:
		for lane in [raw,candidate]:
			if not lane.battle.drones.is_empty() and frame in [30,60]:lane.battle.drones[0].position=lane.body.head+Vector2(2000 if frame==30 else 100,0)
			if frame==45:lane.battle.bullets.append({"position":lane.body.head+Vector2(2400,0)})
			if frame==75:lane.battle.bullets.clear()
		var dt=float([1.0/60,1.0/30,.008,.023][frame%4])
		for lane in ([raw,candidate] if frame%2==0 else [candidate,raw]):
			var began=Time.get_ticks_usec();lane.map.step_orbits(dt)
			if is_same(lane,raw):raw_us+=Time.get_ticks_usec()-began
			else:candidate_us+=Time.get_ticks_usec()-began
		same(actor_state(raw),actor_state(candidate),"Complete captured actor and RNG state %d"%frame)
		total+=candidate.map.orbit_observers_total;kept+=candidate.map.orbit_observers_kept
		if frame%20==19:await process_frame
	check(total>kept,"Captured drones actually exercise strict observer containment")
	check(kept>0,"Distant observers remain active after moving out of the head disk")
	# Explicit head/observer tangent boundaries, including negative radii and
	# coordinates outside the optimized range, use the original disk oracle.
	var geometry_cases=0
	for head in [Vector2.ZERO,Vector2(-8192,6144),Vector2(32768,0)]:
		candidate.body.head=head
		var observers:Array=[]
		for x in [0.0,695.0,696.0,699.99,700.0,700.01,1200.0]:observers.append(Vector3(head.x+x,head.y,1800))
		observers.append(Vector3(head.x,head.y,-1800))
		var pruned:Array=[]
		for observer in observers:candidate.map.append_orbit_observer(pruned,observer,2500)
		for heading in 32:
			for distance in [2499.99,2500.0,2500.001,2500.01,2504.0,2700.0,4000.0]:
				var at=head+Vector2.from_angle(float(heading)*TAU/32)*distance
				same(visible(at,head,2500,observers),visible(at,head,2500,pruned),"Observer disk boundary")
				geometry_cases+=1
	check(differences.is_empty(),"Observer pruning preserves every actor update and disk decision exactly")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"differences":differences,"comparisons":comparisons,"geometry_cases":geometry_cases,"observers_total":total,"observers_kept":kept,"snapshot":path,"component_timing":{"reference_us":raw_us,"candidate_us":candidate_us,"scope":"Interleaved map component including cold caches; no full-game FPS claim"}}
	FileAccess.open("res://artifacts/orbit-observer-pruning-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
