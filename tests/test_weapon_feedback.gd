extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/grid_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Feedback = preload("res://scripts/weapon_feedback.gd")
var checks: Array = []
func check(ok: bool, title: String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func _initialize():call_deferred("execute")
func execute():
	var db=DB.new()
	var families: Dictionary={}
	var cores=0
	for core in db.catalog.values():
		if not core.has("coreProjectile"):continue
		cores+=1
		var data=db.asset(core.coreProjectile)
		var key=Feedback.family(data)
		families[key]=true
		check(Feedback.PROFILES.has(key) and key==Feedback.family(core),core.name+" has a consistent weapon-specific feedback profile")
		var body=Body.new(db)
		var battle=Battle.new(db,body)
		var enemy=battle.spawn(db.pool["250"],Vector2(120,0))
		enemy.hp=10000;enemy.max_hp=10000;enemy.guns=[];enemy.mission_controlled=true
		var rng_state=battle.rng.state
		if data.get("class")=="ContinuousProjectile":battle.special.continuous(core,Vector2.ZERO,Vector2.RIGHT,true,{},0,0.1,"test-flame")
		else:battle.fire(core,Vector2.ZERO,Vector2.RIGHT,true)
		check(battle.effects.any(func(e):return e.get("fx_family")==key),core.name+" emits its own effect through actual combat")
		check(battle.rng.state==rng_state,core.name+" visual/audio identity does not consume gameplay randomness")
		if key in ["rail","tesla"]:
			check(battle.effects.any(func(e):return e.kind=="chain" and e.fx_family==key),core.name+" uses the correct rail/arc beam identity")
	check(families.size()==15,"All twelve original and three added gun families are covered")
	for hz in [30,60,120]:
		var held=0.014
		var elapsed=0.0
		for frame in range(hz):
			elapsed+=Feedback.combat_delta(1.0/hz,held)
			held=maxf(0,held-1.0/hz)
		check(absf(elapsed-(1.0-0.014*0.82))<0.00001,"Short impact holds retain the same duration at %dHz"%hz)
	var body=Body.new(db)
	var battle=Battle.new(db,body)
	var enemy=battle.spawn(db.pool["250"],Vector2(120,0))
	enemy.hp=1000;enemy.max_hp=1000;enemy.guns=[]
	var shot={"data":db.asset(db.named("Core_Gun_Gatling").coreProjectile),"damage":6.0,"shield_damage":4.0,"chips":{},"velocity":Vector2.RIGHT,"position":Vector2(100,0),"pierce":1,"friendly":true}
	var position=enemy.position
	for i in range(12):battle.hit_enemy(enemy,shot)
	check(enemy.hp==928,"Grouping rapid hit embellishments never drops damage")
	check(battle.effects.filter(func(e):return e.kind=="hit").size()==1,"A rapid volley groups hit flashes, particles and sound per target")
	check(enemy.position==position and float(enemy.feedback_left)>0,"Hit recoil is visual; the collision anchor stays fixed")
	check(battle.audio_events.size()==1 and battle.audio_events[0].feedback=="gatling","Grouped hits emit one family-specific impact sound")
	for name in ["Core_MinesField","Core_MineSpawner"]:
		body=Body.new(db);body.velocity=Vector2.RIGHT*100
		body.install_module(db.named(name).id,1,4)
		battle=Battle.new(db,body);battle.step(0.01,Vector2.RIGHT,false)
		check(battle.effects.any(func(e):return e.kind=="mine_arm" and e.fx_family=="mine"),name+" has an arming effect")
		var mine=battle.special.mines[0]
		enemy=battle.spawn(db.pool["250"],mine.position);enemy.mission_controlled=true;enemy.guns=[]
		battle.step(0.01,Vector2.RIGHT,false)
		check(battle.effects.any(func(e):return e.kind=="explosion" and e.fx_family=="mine"),name+" has its own detonation feedback")
	var drone=db.named("Drones_Core_Attack")
	battle=Battle.new(db,Body.new(db))
	battle.fire({"coreProjectile":drone.droneProjectile},Vector2.ZERO,Vector2.RIGHT,true)
	check(battle.bullets[0].fx_family=="drone","Attack drone shots use their own mint-colored feedback")
	var fx=load("res://scripts/weapon_fx.gd").new()
	check(fx.halo_texture.gradient.get_color(3).a==0,"All procedural halos have a transparent outer edge")
	var store=load("res://scripts/save_store.gd").new(db);store.fresh()
	var audio=load("res://scripts/audio_system.gd").new();root.add_child(audio);audio.setup(db,store)
	var finite_audio=true
	var wave_hashes: Dictionary={}
	for key in Feedback.PROFILES:
		var stream=audio.make_impact(key)
		var bytes=stream.data
		var peak=0
		for i in range(0,bytes.size(),2):peak=maxi(peak,absi(bytes.decode_s16(i)))
		finite_audio=finite_audio and peak>1000 and peak<32767 and stream.get_length()>0.1 and stream.get_length()<0.3
		wave_hashes[hash(bytes)]=true
	check(finite_audio and wave_hashes.size()==Feedback.PROFILES.size(),"Each weapon has a distinct finite, unclipped impact layer")
	var bus=AudioServer.get_bus_index(audio.combat_bus)
	check(bus>=0 and AudioServer.get_bus_effect_count(bus)==1 and audio.impact_voices.size()==8,"Combat mix has a limiter and a bounded impact voice pool")
	for i in range(30):audio.impact("cannon",Vector2.ZERO,1.0)
	check(audio.impact_voices.filter(func(v):return v.playing).size()==1,"Simultaneous cannon impacts are sound-rate limited")
	# The audio mixer uses wall time even when rendering with --fixed-fps.
	for i in range(12):
		OS.delay_msec(10)
		await process_frame
	audio.shutdown()
	for i in range(12):
		OS.delay_msec(10)
		await process_frame
	audio.queue_free()
	await process_frame
	check(AudioServer.get_bus_index("Centipede Combat")<0,"Audio shutdown releases the owned combat bus")
	var report={"checks":checks,"gun_cores":cores,"gun_families":families.keys(),"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/weapon-feedback-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
