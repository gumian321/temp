extends SceneTree
const Feedback=preload("res://scripts/weapon_feedback.gd")
var checks:Array=[]
func check(value:bool,title:String):
	checks.append({"name":title,"passed":value})
	if not value:printerr("FAIL: ",title)
func _initialize():
	var shot={"previous":Vector2(0,12),"position":Vector2(300,12),"velocity":Vector2(3000,0),"radius":0.0}
	var c=Feedback.surface_contact(Vector2(100,0),20,shot)
	check(c.position.distance_to(Vector2(84,12))<0.001,"Fast swept shot lands at first off-center surface contact, not overshot endpoint")
	check(c.direction==Vector2.RIGHT and c.normal.x<0 and c.normal.y>0,"Incoming direction and surface normal retained")
	shot.radius=4.0;c=Feedback.surface_contact(Vector2(100,0),20,shot)
	check(absf(c.position.distance_to(Vector2(100,0))-20)<0.001 and c.position.y>0,"Finite bullet radius projects contact onto target surface")
	var last=0.0
	for damage in [0.0,1.0,4.0,16.0,64.0,256.0,1000000.0]:
		var size=Feedback.impact_size(damage)
		check(size>=last and size<=24.0,"Damage %s has monotonic bounded hit size"%damage);last=size
	check(Feedback.impact_size(2)*2<Feedback.impact_size(100),"Weak and heavy shots are visibly distinct")
	shot.origin=Vector2(-200,12);shot.previous=Vector2(90,12)
	c=Feedback.shield_contact(Vector2(100,0),80,shot)
	check(c.position.x<30 and absf(c.position.distance_to(Vector2(100,0))-80)<0.001,"Shield contact reconstructs earlier shield edge from shot origin")
	var db=load("res://scripts/source_db.gd").new()
	var body=load("res://scripts/grid_centipede.gd").new(db)
	var battle=load("res://scripts/combat.gd").new(db,body)
	var target=battle.spawn(db.pool["250"],Vector2(100,0));target.guns=[];target.hp=10000;target.max_hp=10000
	shot={"previous":Vector2(0,12),"position":Vector2(300,12),"velocity":Vector2(3000,0),"radius":0.0,"data":db.asset(db.named("Core_Gun_Gatling").coreProjectile),"damage":2.0,"shield_damage":2.0,"chips":{},"pierce":1,"friendly":true}
	var rng_state=battle.rng.state
	for i in range(20):battle.hit_enemy(target,shot)
	var hit=battle.effects.filter(func(e):return e.kind=="hit")
	check(target.hp==9960 and hit.size()==1,"Twenty rapid shots apply every damage point but coalesce visual events")
	check(hit[0].position==Feedback.surface_contact(target.position,target.radius,shot).position and hit[0].particle_type==0,"Actual combat event preserves precise contact and disables legacy particle flower")
	var weak=hit[0].radius;shot.damage=100;battle.hit_enemy(target,shot)
	check(battle.effects.back().radius>weak,"Heavy hit remains visible during weak-shot cooldown")
	check(battle.rng.state==rng_state,"Contact and visual throttling consume no gameplay RNG")
	for i in range(80):
		target.fx_cooldown=0;battle.impact_feedback(target,shot)
	check(battle.effects.filter(func(e):return e.kind in ["hit","shield_hit"]).size()<=48,"Simultaneous contact events have a global presentation-only cap")
	for name in ["Core_Gun_Tesla","Core_Gun_Sniper"]:
		battle.effects.clear();target.fx_cooldown=0;battle.fire(db.named(name),Vector2.ZERO,Vector2.RIGHT,true)
		var beams=battle.effects.filter(func(e):return e.kind=="chain")
		if not beams.is_empty():check(absf(beams[0].end.distance_to(target.position)-target.radius)<0.001,name+" beam terminates on target surface")
	# Incoming bullets use the player's real collision radius (no projectile expansion).
	battle.effects.clear();body.parts[0].fx_cooldown=0
	shot.friendly=false;shot.damage=1.0;shot.shield_damage=3.0
	shot.previous=body.head+Vector2(-100,7);shot.position=body.head+Vector2(100,7);shot.origin=shot.previous;shot.velocity=Vector2.RIGHT*3000;shot.radius=4.0
	battle.hit_player(0,shot)
	var player_hit=battle.effects.back()
	var precise=shot.duplicate();precise.radius=0.0
	check(player_hit.position.distance_to(Feedback.surface_contact(body.head,body.collision_radius(0),precise).position)<0.001 and not player_hit.friendly,"Hostile bullet contact follows player collision geometry and retains enemy ownership")
	body.append_segment(db.named("Core_Shield").id);body.refresh_positions()
	battle.effects.clear();body.parts[0].fx_cooldown=0
	shot.origin=body.head+Vector2(-500,7);shot.previous=body.head+Vector2(-10,7)
	var hull_before=body.parts[0].hp
	battle.hit_player(0,shot)
	var shield_hit=battle.effects.back()
	check(shield_hit.kind=="shield_hit" and body.parts[0].hp==hull_before and absf(shield_hit.position.distance_to(body.parts[1].position)-battle.shield_range(1))<0.001,"Actual player shield absorbs damage and renders on shield edge")
	check(shield_hit.radius==Feedback.impact_size(shot.shield_damage),"Shield cue scales from shield damage rather than hull damage")
	var report={"checks":checks,"passed":checks.all(func(item):return item.passed)}
	FileAccess.open("res://artifacts/contact-impacts-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
