extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Push=preload("res://scripts/knockback.gd")
var db
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func actor(battle):
	var enemy=battle.spawn(db.pool["250"],Vector2(400,0))
	enemy.hp=10000.0;enemy.max_hp=10000.0;enemy.guns=[];enemy.components=[]
	enemy.kind="AISwarmingUnit";enemy.unit={};enemy.movement={"enginePower":0.0}
	enemy.warp=0.0;enemy.stun=0.0;enemy.angle=PI
	return enemy
func shot(at:Vector2,friendly:bool=true):
	return {"data":db.asset(db.named("Core_Gun_SonicWave").coreProjectile),"damage":2.0,"shield_damage":2.0,"friendly":friendly,"chips":{},"velocity":Vector2.RIGHT*480,"position":at,"previous":at-Vector2(30,0),"origin":at-Vector2(300,0),"radius":4.0,"pierce":1,"hit":[]}
func execute():
	db=DB.new()
	var totals:Array=[]
	for hz in [30,60,120]:
		var body=Body.new(db);var battle=Battle.new(db,body);var enemy=actor(battle)
		var start=Vector2(enemy.position);var rng_state=battle.rng.state
		battle.hit_enemy(enemy,shot(start))
		check(enemy.position==start and enemy.hp==9998,"Sonic hit applies damage without teleporting at %d Hz"%hz)
		check(battle.rng.state==rng_state,"Queuing a shove consumes no gameplay RNG")
		battle.step(0,body.head,false,false)
		check(enemy.position==start,"Zero combat delta freezes the push")
		var first_step=0.0;var previous_step=INF;var smooth=true
		for tick in hz:
			var previous=Vector2(enemy.position)
			battle.step(1.0/hz,body.head,false,false)
			var distance=previous.distance_to(enemy.position)
			if tick==0:first_step=distance
			smooth=smooth and distance<=Push.MAX_SPEED/hz+0.01 and distance<=previous_step+0.01
			previous_step=distance
			if tick==hz/4:check(enemy.position.x>start.x+40,"First quarter-second visibly carries the enemy backward")
		check(smooth and first_step>2,"Every physics step is bounded and decelerates smoothly at %d Hz"%hz)
		check(not enemy.has("knockback_velocity"),"Push settles completely without leaving residual drift")
		var travel=enemy.position.x-start.x
		check(travel>70 and travel<110,"A normal wave visibly pushes without launching the enemy far away")
		totals.append(travel)
	check(absf(totals.max()-totals.min())<0.02,"Total push distance is consistent at 30/60/120 Hz")
	var body=Body.new(db);var battle=Battle.new(db,body);var enemy=actor(battle)
	var start=Vector2(enemy.position)
	for i in 100:battle.hit_enemy(enemy,shot(start))
	check(enemy.position==start and Vector2(enemy.knockback_velocity).length()<=Push.MAX_SPEED+0.01 and enemy.hp==9800,"Overlapping waves apply all damage but cap combined launch speed")
	battle.step(0.8,body.head,false,false)
	check(enemy.position.distance_to(start)<45,"A stalled frame cannot replay an entire shove as a teleport")
	enemy.stun=1.0;start=enemy.position;battle.step(1.0/60,body.head,false,false)
	check(enemy.position.x>start.x,"A stunned insect still slides under the external push")
	enemy.mission_controlled=true;start=enemy.position;battle.step(1.0/60,body.head,false,false)
	check(enemy.position==start and not enemy.has("knockback_velocity"),"Mission ownership cancels an old displacement impulse")
	for kind in ["AIBossUnit","AIBossPartController","AIStation","Asteroid"]:
		enemy=actor(battle);enemy.kind=kind;start=enemy.position
		battle.hit_enemy(enemy,shot(start))
		check(enemy.position==start and not enemy.has("knockback_velocity"),kind+" cannot be detached or teleported by a wave")
	enemy=actor(battle);enemy.parent=999;battle.push_enemy(enemy,Vector2.RIGHT,5)
	check(not enemy.has("knockback_velocity"),"An attached child cannot separate from its parent")
	# AoE must remain centered on the actual impact, not on a displaced endpoint.
	battle=Battle.new(db,body);enemy=actor(battle)
	var adjacent=actor(battle);adjacent.position+=Vector2(20,0)
	var area_shot=shot(enemy.position);area_shot.data=area_shot.data.duplicate();area_shot.data.projectileEffectArea=1.0
	battle.hit_enemy(enemy,area_shot)
	check(adjacent.hp==9998,"Splash resolves beside the impact before any later knockback travel")
	battle.refresh_spatial();battle.step(0.1,body.head,false,false);battle.refresh_spatial()
	check(battle.area_candidates(enemy.position,5).has(enemy),"Spatial targeting tracks the actual moving actor")
	# Hostile waves share the same continuous motion for both playable characters.
	for character in ["centipede","spider"]:
		body=Body.new(db);body.configure_character(character);battle=Battle.new(db,body)
		var head=body.head
		battle.hit_player(0,shot(head,false))
		check(body.head==head and body.parts[0].hp==body.parts[0].max_hp-2,"Hostile wave damages "+character+" without teleporting its head")
		for tick in 60:
			var previous=body.head
			body.step(1.0/60,Vector2.ZERO,false);battle.step(1.0/60,body.head,false,false)
			check(body.head.distance_to(previous)<=Push.MAX_SPEED/60+0.01,"Player displacement stays bounded per tick")
		check(body.head.x>head.x+70 and body.parts[0].position==body.head,"Player collision and visible head follow the same continuous displacement")
		body.reset()
		check(not body.parts[0].has("knockback_velocity"),"Restart clears the old push")
	body=Body.new(db);body.append_segment(db.named("Core_Shield").id);battle=Battle.new(db,body)
	battle.hit_player(0,shot(body.head,false))
	check(not body.parts[0].has("knockback_velocity") and body.parts[0].hp==body.parts[0].max_hp,"An absorbed wave does not shove the shielded player hull")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed),"travel_by_hz":totals}
	FileAccess.open("res://artifacts/knockback-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
