extends "res://tests/test_insect_controls.gd"
const Tether=preload("res://scripts/tether_motion.gd")
const SpiderArt=preload("res://scripts/spider_art.gd")
const Organs=preload("res://scripts/soft_organ_art.gd")
func execute():
	db=DB.new()
	for hz in [30,60,120]:
		var motion=Tether.create(Vector2.ZERO,Vector2(250,0))
		for frame in hz/4:Tether.step(motion,Vector2.ZERO,Vector2(250,0),1,sin(float(frame)/hz*15),1.0/hz)
		var pose=Tether.emitter_reaction(motion);motion.emitter_offset=pose.offset
		check(pose.offset.x>12 and pose.offset.length()<=17,"Emitter visibly leans toward loaded tether at %d Hz"%hz)
		var stretched=Organs.traction_point(Vector2(20,0),pose.axis,pose.stretch)
		check(stretched.x>25 and Organs.traction_point(Vector2.ZERO,pose.axis,pose.stretch)==Vector2.ZERO,"Source organ stretches internally while its emission center stays fixed")
		check(Tether.points(motion)[0]==pose.offset,"Attached rope root moves exactly with the organ at %d Hz"%hz)
		var released=Tether.release(motion,"tendril")
		check(Tether.points(released)==Tether.points(motion),"Emitter detachment preserves the complete curve at %d Hz"%hz)
		var minimum=0.0
		var squash=false
		for frame in int(ceil(float(released.release_duration)*hz))+1:
			released.release_age=float(frame+1)/hz
			pose=Tether.emitter_reaction(released);released.emitter_offset=pose.offset
			minimum=minf(minimum,pose.offset.x)
			squash=squash or Organs.traction_point(Vector2(20,0),pose.axis,pose.stretch).x<18
			check(Tether.points(released)[0].distance_to(pose.offset)<.001,"Released rope remains attached to recoiling organ")
		check(minimum<-6 and squash and pose.offset.length()<.05,"Emitter visibly recoils, squashes and settles at %d Hz"%hz)
	var battle=fixture()
	battle.player.install_module(db.named("Core_Gun_Tesla").id,1,4)
	battle.player.install_module(db.named("Core_Gun_Gatling").id,2,4)
	var e=actor(battle,Vector2(140,0))
	battle.fire(db.named("Core_Gun_Tesla"),battle.player.weapon_origin(1),Vector2.RIGHT,true,{},0,false,0,1,"player:1")
	for frame in 8:battle.insect_control_system.advance(1.0/60,battle)
	var controls=battle.insect_control_system
	var token=int(battle.player.parts[1].insect_source_token)
	check(not controls.emitter_pose("player:1",token).is_empty(),"Real mounted tendril loads its own source organ")
	check(controls.emitter_pose("player:2",0).is_empty(),"Unfired neighboring organ never inherits another token's reaction")
	var source=battle.player.parts[1];battle.player.parts[1]=battle.player.parts[2];battle.player.parts[2]=source
	controls.advance(1.0/60,battle)
	check(not controls.emitter_pose("player:2",token).is_empty(),"Organ reaction follows stable identity through rearrangement")
	var frozen=controls.emitter_poses.duplicate(true);controls.advance(0,battle)
	check(controls.emitter_poses==frozen,"Pause freezes emitter reaction")
	for frame in 90:controls.advance(1.0/60,battle)
	check(controls.emitter_poses.is_empty(),"Expired reaction leaves no stale organ offsets")
	var body=preload("res://scripts/chain_centipede.gd").new(db);body.configure_character("spider")
	battle=Battle.new(db,body);e=actor(battle,body.head+Vector2(250,0))
	battle.request_skill(e.position)
	for frame in 15:battle.character_abilities.update(1.0/60)
	check(battle.character_abilities.emitter_pose.offset.x>6,"Spider silk loads its emitting forebody")
	var head=body.head;var health=body.parts[0].hp
	battle.character_abilities.finish()
	for frame in 12:battle.character_abilities.update(1.0/60)
	check(battle.character_abilities.emitter_pose.offset.x<-1,"Spider forebody recoils when silk releases")
	check(body.head==head and body.parts[0].hp==health,"Emitter animation cannot move the collision body or alter health")
	check(SpiderArt.tension_point(Vector2(-65,0),Vector2(7,2),.1)==Vector2(-65,0),"Spider abdomen stays anchored")
	check(SpiderArt.tension_point(Vector2.ZERO,Vector2(7,2),.1)==Vector2(7,2),"Spider emission point follows the forebody deformation exactly")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/emitter-reaction-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
