extends "res://tests/test_insect_controls.gd"
const Soft=preload("res://scripts/soft_insect.gd")
func execute():
	db=DB.new()
	var peaks={}
	for species in Soft.Brood.SPECIES:
		var e={"uid":3,"kind":"AISwarmingUnit","position":Vector2.ZERO,"angle":0.0,"hp":100.0,"max_hp":100.0,"radius":30.0,"brood_species":species}
		var signs={};var peak=0.0;var bounded=true
		for frame in 120:
			Soft.pull(e,Vector2.RIGHT,200,1.0/60);Soft.step(e,1.0/60)
			var state:Dictionary=e.soft_body
			if frame>30:signs[signf(Soft.struggle(state))]=true
			var a=Vector2(.6,0);var b=Vector2(-.6,0)
			var da=Soft.pull_deform(state,a,Vector2.ZERO,1,0)
			var dbp=Soft.pull_deform(state,b,Vector2.ZERO,1,0)
			peak=maxf(peak,(da-dbp).dot(Vector2.RIGHT)-1.2)
			bounded=bounded and da.is_finite() and da.distance_to(a)<=.281
		check(peak>.15 and signs.has(-1.0) and signs.has(1.0),"Sustained axial stretch and alternating struggle: "+species)
		check(bounded and e.position==Vector2.ZERO and e.hp==100,"Visual tension is bounded and never moves collisions: "+species)
		var frozen=e.soft_body.duplicate(true)
		Soft.pull(e,Vector2.UP,200,0);Soft.step(e,0)
		check(frozen==e.soft_body,"Pause freezes traction including its direction: "+species)
		var rebound=false
		for frame in 240:
			Soft.step(e,1.0/60)
			rebound=rebound or float(e.soft_body.get("pull_strain",0))<-.01
		check(rebound and not e.soft_body.has("pull_strain"),"Release rebounds then fully settles: "+species)
		peaks[species]=peak
	check(peaks.beetle<peaks.grub*.6,"Shells resist stretching more than soft bodies")
	for hz in [30,60,120]:
		var battle=fixture();var e=actor(battle)
		battle.insect_control_system.attach(e,shot("tendril"))
		var peak=0.0
		for frame in hz:
			Soft.step(e,1.0/hz);battle.insect_control_system.advance(1.0/hz,battle)
			peak=maxf(peak,float(e.soft_body.get("pull_strain",0)))
		check(peak>.3 and absf(e.position.x-436)<.01,"Actual tendril strains body and preserves 64px budget at %d Hz"%hz)
	var body=preload("res://scripts/chain_centipede.gd").new(db)
	body.configure_character("spider")
	var battle=Battle.new(db,body);var e=actor(battle,body.head+Vector2(250,0))
	var boss=actor(battle,body.head+Vector2(250,40));boss.kind="AIBossPartController"
	battle.request_skill(e.position)
	for frame in 90:battle.character_abilities.update(1.0/60);Soft.step(e,1.0/60)
	check(e.soft_body.pull_strain>.1 and body.head.distance_to(e.position)<91,"Spider keeps visible tension while holding its victim")
	check(not boss.get("soft_body",{}).has("pull_strain"),"Immune boss never gets a false pull deformation")
	battle.character_abilities.finish()
	for frame in 240:battle.character_abilities.update(1.0/60);Soft.step(e,1.0/60)
	check(not e.soft_body.has("pull_strain"),"Ended spider threads release visual tension")
	battle=fixture();e=actor(battle,Vector2(200,0))
	var anchored=actor(battle,Vector2(200,40));anchored.mission_controlled=true
	battle.special.black_holes.append({"position":Vector2.ZERO,"radius":400.0,"life":2.0,"damage":0.0,"shield_damage":0.0,"friendly":true,"force":100.0})
	for frame in 30:battle.special.step(1.0/60);Soft.step(e,1.0/60)
	check(absf(e.position.x-150)<.01 and e.soft_body.pull_strain>.15,"Vortex actual movement drives sustained body traction")
	check(not anchored.get("soft_body",{}).has("pull_strain"),"Anchored targets are not visually pulled")
	battle.special.black_holes.clear()
	for frame in 240:Soft.step(e,1.0/60)
	check(not e.soft_body.has("pull_strain"),"Removed vortex cannot leave permanent stretching")
	var report={"checks":checks,"shape_change_by_species":peaks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/soft-pull-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
