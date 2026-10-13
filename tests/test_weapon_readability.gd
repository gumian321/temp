extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const FX=preload("res://scripts/weapon_fx.gd")
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func execute():
	var db=DB.new()
	var core=db.named("Core_Gun_Gatling")
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
		for friendly in [true,false]:
			var body=Body.new(db)
			var battle=Battle.new(db,body)
			var at=Vector2(300,200)
			battle.fire(core,at,direction,friendly)
			var b=battle.bullets[0]
			check(b.friendly==friendly and b.velocity.normalized().dot(direction)>0.99,"Gatling ownership and outward velocity %s %s"%[direction,friendly])
			check(b.position.distance_to(at)<100,"Gatling starts at the firing weapon")
			b.position+=b.velocity*0.025
			for zoom in [0.5,1.0,1.5]:
				var geometry=FX.gatling_geometry(b,zoom)
				check(geometry.tail.dot(b.velocity)<0 and geometry.tip.dot(b.velocity)>0,"Gatling bright nose leads and tail trails at zoom %s"%zoom)
	# Use the real simulation collision loop, with all autonomous guns disabled.
	for friendly in [true,false]:
		var body=Body.new(db)
		body.hq_weapon=db.named("Core_Gun_Gatling").id
		var battle=Battle.new(db,body)
		var enemy=battle.spawn(db.pool["250"],body.head+Vector2(100,0))
		enemy.guns=[];enemy.mission_controlled=true;enemy.warp=0;enemy.hp=100;enemy.max_hp=100
		var hp=float(body.parts[0].hp)
		battle.fire(core,body.head if friendly else enemy.position,Vector2.RIGHT if friendly else Vector2.LEFT,friendly)
		# shooting=false now means HQ auto fire. Suppress autonomous player
		# weapons explicitly so this fixture isolates the one injected round.
		var shots_before=int(battle.statistics.get("stat_BulletsFired",0))
		for frame in range(12):battle.step(1.0/120.0,body.head+Vector2.RIGHT,false,false)
		check(int(battle.statistics.get("stat_BulletsFired",0))==shots_before,"Collision fixture emits no autonomous player rounds: "+str(friendly))
		check((body.parts[0].hp==hp and enemy.hp<100) if friendly else (body.parts[0].hp<hp and enemy.hp==100),"Actual Gatling collision damages only opposing side: "+str(friendly))
	var body=Body.new(db)
	var battle=Battle.new(db,body)
	var enemy=battle.spawn(db.pool["250"],body.head+Vector2(120,0))
	enemy.guns=[];enemy.mission_controlled=true;enemy.warp=0;enemy.hp=1000
	enemy.guns=[{"id":db.named("Core_AI_Gun_Gatling").id,"angle":PI,"cooldown":0.0,"offset":Vector2.ZERO}]
	battle.step(0.01,body.head+Vector2.RIGHT,false)
	check(battle.bullets.any(func(b):return not b.friendly and b.fx_family=="gatling" and b.velocity.x<0 and b.origin.distance_to(enemy.position)<100),"Real enemy AI Gatling fires hostile rounds from its own weapon toward player")
	enemy.guns=[];battle.bullets.clear();battle.effects.clear()
	var tesla=db.named("Core_Gun_Tesla")
	var rng=battle.rng.state
	battle.fire(tesla,body.head,Vector2.RIGHT,true)
	var beam=battle.effects.filter(func(e):return e.kind=="chain")[0]
	check(beam.life==0.32 and beam.fx_duration==0.32 and absf(beam.end.distance_to(enemy.position)-enemy.radius)<0.001,"Tesla readable 320ms beam connects actual emitter and target surface")
	check(enemy.hp==980 and battle.bullets.is_empty(),"Tesla remains one instantaneous 20 damage hit, no persistent damage")
	check(battle.rng.state==rng,"Readability changes do not consume gameplay randomness")
	battle.effects.clear()
	battle.fire(tesla,enemy.position,Vector2.LEFT,false)
	check(battle.effects.any(func(e):return e.kind=="chain" and not e.friendly and absf(e.end.distance_to(body.head)-body.collision_radius(0))<0.001),"Hostile instantaneous Tesla has a visible source-to-player-surface beam")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/weapon-readability-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
