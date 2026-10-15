extends "res://tests/test_insect_controls.gd"
const Tether=preload("res://scripts/tether_motion.gd")
const FX=preload("res://scripts/insect_attack_fx.gd")
func sag(points:PackedVector2Array)->float:
	var peak=0.0
	for p in points:peak=maxf(peak,absf(p.y))
	return peak
func execute():
	db=DB.new()
	for hz in [30,60,120]:
		var state=Tether.create(Vector2.ZERO,Vector2(250,0),1)
		var slack=sag(Tether.points(state))
		for frame in hz/4:Tether.step(state,Vector2.ZERO,Vector2(250,0),1,0,1.0/hz)
		check(sag(Tether.points(state))<slack*.2,"Slack progressively tightens at %d Hz"%hz)
		var bends={};var pinned=true
		for frame in hz:
			Tether.step(state,Vector2.ZERO,Vector2(250,0),1,sin(float(frame)/hz*15),1.0/hz)
			var points=Tether.points(state)
			pinned=pinned and points[0]==Vector2.ZERO and points[-1]==Vector2(250,0)
			bends[signf(float(state.bend))]=true
		check(pinned and bends.has(-1.0) and bends.has(1.0),"Victim struggle travels along a tether pinned at both ends at %d Hz"%hz)
		var released=Tether.release(state,"tendril")
		check(Tether.points(released)==Tether.points(state),"Detaching preserves the last attached curve exactly at %d Hz"%hz)
		var items=[released];var frozen=released.duplicate(true)
		Tether.advance_released(items,0)
		check(released==frozen,"Release animation pauses with simulation at %d Hz"%hz)
		var sides={};var retracts=false
		for frame in hz:
			Tether.advance_released(items,1.0/hz)
			if items.is_empty():break
			var points=Tether.points(released)
			sides[signf(points[-1].y)]=true
			retracts=retracts or points[-1].x<150
		check(sides.has(-1.0) and sides.has(1.0) and retracts and items.is_empty(),"Free tip whips both ways, retracts and expires at %d Hz"%hz)
	var battle=fixture();var e=actor(battle)
	battle.insect_control_system.attach(e,shot("tendril"))
	for frame in 22:battle.insect_control_system.advance(1.0/60,battle)
	check(battle.insect_controls.is_empty() and battle.insect_control_system.released.size()==1,"Actual weapon releases gameplay control but keeps its recoil curve")
	var snapshot:Dictionary=battle.insect_control_system.released[0]
	var tip:Vector2=snapshot.end;e.position=Vector2(9000,9000)
	check(snapshot.end==tip and not snapshot.has("target"),"Detached effect does not follow or retain the old victim")
	for frame in 50:battle.insect_control_system.advance(1.0/60,battle)
	check(battle.insect_control_system.released.is_empty(),"Weapon recoil geometry is removed when finished")
	var body=preload("res://scripts/chain_centipede.gd").new(db);body.configure_character("spider")
	battle=Battle.new(db,body);e=actor(battle,body.head+Vector2(250,0))
	battle.request_skill(e.position)
	for frame in 15:battle.character_abilities.update(1.0/60)
	var attached:Dictionary=battle.character_abilities.threads[0].tether
	var curve=Tether.points(attached)
	e.hp=0;battle.character_abilities.update(1.0/60)
	check(battle.character_abilities.threads.is_empty() and battle.character_abilities.released_threads.size()==1,"Killed spider victim releases a cosmetic recoil curve")
	check(Tether.points(battle.character_abilities.released_threads[0])==curve,"Target loss releases from the last valid point without jumping")
	battle.character_abilities.reset()
	check(battle.character_abilities.released_threads.is_empty(),"Run reset clears recoil geometry")
	var many=[]
	var moving=Tether.release(Tether.create(Vector2.ZERO,Vector2(250,0)),"silk")
	moving.release_age=.15;moving.release_origin=Vector2(20,30)
	check(Tether.points(moving)[0]==Vector2(20,30),"Retracting root follows its moving emitter while the free tip retains lag")
	for i in 100:Tether.append_release(many,Tether.create(Vector2.ZERO,Vector2(250,0),i),"silk")
	check(many.size()==Tether.MAX_RELEASED,"Released curves have a hard memory and drawing cap")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/tether-motion-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
