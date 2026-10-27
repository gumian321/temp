extends SceneTree
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
const Fixture=preload("res://tests/visual_settling_fixture.gd")
const Snapshot=preload("res://scripts/battle_snapshot.gd")
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/centipede.gd")
const Battle=preload("res://scripts/combat.gd")
var checks:Array=[]

func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)

func physical(battle,body)->Dictionary:
	var data={"combat":Snapshot.state(battle,["phase_times","diagnostic_times"]),"player":Snapshot.state(body),"controls":Snapshot.state(battle.insect_control_system),"special":Snapshot.state(battle.special),"mutations":Snapshot.state(battle.mutation_weapons),"abilities":Snapshot.state(battle.character_abilities),"momentum":Snapshot.state(battle.momentum)}.duplicate(true)
	return Fixture.without_visuals(data)

func execute():
	var previous=Soft.use_visual_settling;var previous_exact=Soft.use_exact_rest_certificate
	Soft.use_exact_rest_certificate=false
	var entity=Fixture.actor("grub");var original=entity.duplicate(true)
	check(Soft.settle_visual_rest(entity.soft_body) and not entity.soft_body.lattice_active,"Only vanishing visual energy enters the dormant lattice path")
	check(Fixture.without_visuals(entity.duplicate(true))==Fixture.without_visuals(original),"Settling preserves physical fields, clocks, peak, cue identity/age/strength, contact and event counters exactly")
	check(Soft.exact_rest_certificate(entity.soft_body),"A settled body has exact zero spring and feedback energy")
	for key in ["hold","flash","cue_cooldown"]:
		entity=Fixture.actor("grub");entity.soft_body[key]=1e-300;var before=entity.duplicate(true)
		check(not Soft.settle_visual_rest(entity.soft_body) and entity==before,"Even subnormal %s timer remains active and unchanged"%key)
	for key in ["push_strain","pull_strain"]:
		entity=Fixture.actor("grub");entity.soft_body[key]=0.0;var before=entity.duplicate(true)
		check(not Soft.settle_visual_rest(entity.soft_body) and entity==before,"An existing %s lease can never be shortened"%key)
	for key in ["offset","velocity"]:
		entity=Fixture.actor("grub");entity.soft_body[key][14]=Vector2(Soft.VISUAL_SETTLING_THRESHOLD*1.01,0);var before=entity.duplicate(true)
		check(not Soft.settle_visual_rest(entity.soft_body) and entity==before,"The last %s component rejects the whole certificate without partially zeroing earlier bones"%key)
	for key in ["shock","recoil","recoil_velocity","lean","lean_velocity"]:
		entity=Fixture.actor("grub")
		entity.soft_body[key]=Vector2(Soft.VISUAL_SETTLING_THRESHOLD*2,0) if key in ["recoil","recoil_velocity"] else Soft.VISUAL_SETTLING_THRESHOLD*2
		var before=entity.duplicate(true)
		check(not Soft.settle_visual_rest(entity.soft_body) and entity==before,"Real %s feedback remains fully active"%key)
	entity=Fixture.actor("grub");entity.soft_body.rest=entity.soft_body.rest.duplicate();entity.soft_body.rest[3].y=entity.soft_body.rest[0].y
	check(not Soft.settle_visual_rest(entity.soft_body),"Invalid rest ordering never bypasses the lattice constraints")
	entity=Fixture.actor("grub");entity.soft_body.constraint_margin_squared=NAN
	check(not Soft.settle_visual_rest(entity.soft_body),"An invalid constraint certificate cannot settle")
	var worst=0.0;var comparisons=0
	for species in Brood.SPECIES:
		var baseline=Fixture.actor(species);var candidate=baseline.duplicate(true)
		var nonvisual_exact=true
		for tick in 360:
			if tick in [1,85,140,200]:
				Soft.impact(baseline,baseline.position+Vector2(7,4),Vector2.LEFT,17,"cannon")
				Soft.impact(candidate,candidate.position+Vector2(7,4),Vector2.LEFT,17,"cannon")
				check(candidate.soft_body.lattice_active and candidate.soft_body.shock>.1,"A fresh %s hit wakes the full lattice in the same frame %d"%[species,tick])
			if tick==35:
				baseline.knockback_velocity=Vector2.RIGHT*100;candidate.knockback_velocity=Vector2.RIGHT*100
				Soft.begin_push(baseline);Soft.begin_push(candidate)
			if tick==55:
				Soft.pull(baseline,Vector2.LEFT,120,.033);Soft.pull(candidate,Vector2.LEFT,120,.033)
			var dt:float=[1.0/120,1.0/60,1.0/30,.001,.15,0.0,-.1][tick%7]
			Soft.use_visual_settling=false;Soft.step(baseline,dt)
			Soft.use_visual_settling=true;Soft.step(candidate,dt)
			worst=maxf(worst,Fixture.visual_difference(baseline.soft_body,candidate.soft_body));comparisons+=1
			nonvisual_exact=nonvisual_exact and Fixture.without_visuals(baseline.duplicate(true))==Fixture.without_visuals(candidate.duplicate(true))
		check(nonvisual_exact,"Every nonvisual %s field remains exact through 360 variable-delta ticks"%species)
	for action in ["push","pull"]:
		entity=Fixture.actor("grub");Soft.settle_visual_rest(entity.soft_body)
		if action=="push":entity.knockback_velocity=Vector2.RIGHT*100;Soft.begin_push(entity)
		else:Soft.pull(entity,Vector2.LEFT,120,.033)
		Soft.step(entity,1.0/30)
		check(float(entity.soft_body.get(action+"_age",0))>0 and absf(float(entity.soft_body.get(action+"_strain",0)))>0,"A new %s advances normal deformation immediately after settling"%action)
	check(worst<=Fixture.NUMERICAL_ERROR,"All post-hit/push/pull visual numeric differences remain <=1e-12")
	var db=DB.new();var reference:Array=[];var combat_equal=true
	for optimized in [false,true]:
		Soft.use_visual_settling=optimized;preload("res://scripts/projectile_trails.gd").next_visual_id=0
		var body=Body.new(db);var battle=Battle.new(db,body)
		for name in ["Core_Gun_Tesla","Core_Gun_EMP","Core_Gun_SonicWave"]:body.append_segment(db.named(name).id)
		for part in body.parts:part.hp=100000;part.max_hp=100000
		for i in 12:
			var e=battle.spawn(db.pool["250"],Vector2(220+i*17,70*sin(i)))
			e.components=[];e.hp=100000;e.max_hp=100000;e.warp=0;e.brood_species=Brood.SPECIES[i%6]
			Soft.prepare(e);Fixture.ghost(e.soft_body)
		var parent:Dictionary=battle.enemies[0];var child:Dictionary=battle.enemies[1]
		child.parent=parent.uid;child.offset=Vector2(0,25);parent.parts.append(child.uid)
		battle.terrain=preload("res://scripts/chasm_world.gd").new()
		for tick in 240:
			if tick in [20,100,180]:battle.insect_control_system.attach(parent,{"insect_attack":"tendril","friendly":true,"origin":Vector2.ZERO})
			if tick==55:battle.special.black_holes.append({"position":Vector2(200,40),"life":.5,"radius":250.0,"damage":.25,"shield_damage":.25,"friendly":true,"force":80.0})
			battle.step([1.0/120,1.0/60,1.0/30,.017][tick%4],Vector2(400,0),true)
			var state=physical(battle,body)
			if not optimized:reference.append(state)
			else:combat_equal=combat_equal and state==reference[tick]
	check(combat_equal,"Full combat physical/tether/weapon/reward/event state and every system RNG are exactly identical for 240 ticks")
	Soft.use_visual_settling=previous;Soft.use_exact_rest_certificate=previous_exact
	var passed=checks.all(func(item):return item.passed)
	var report={"passed":passed,"checks":checks,"settle_threshold":Soft.VISUAL_SETTLING_THRESHOLD,"visual_numeric_error_budget":Fixture.NUMERICAL_ERROR,"worst_visual_numeric_difference":worst,"visual_state_comparisons":comparisons,"physical_combat_comparisons":240,"scope":"Opt-in visual energy settling only. Only the seven numeric cosmetic fields and lattice-active bookkeeping may differ; all other simulation state is exact. Native pixel test is separate."}
	FileAccess.open("res://artifacts/deep50-soft-visual-settling.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if passed else 1)
