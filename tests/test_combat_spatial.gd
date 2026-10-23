extends SceneTree
const Index = preload("res://scripts/combat_spatial_index.gd")
class FakeDB:
	func asset(id): return {"class":"ShieldCore" if id == "shield" else "GunCore"}
var checks = 0
var failures: Array = []
func check(ok, message):
	checks += 1
	if not ok: failures.append(message)
func brute_nearest(actors, at, reach):
	var result = {}; var best = reach*reach
	for e in actors:
		if e.hp <= 0 or not e.damageable or e.role == "friendly": continue
		var distance = at.distance_squared_to(e.position)
		if distance < best: best = distance; result = e
	return result.get("uid", -1)
func ids(actors): return actors.map(func(e): return e.uid)
func _initialize():
	var rng = RandomNumberGenerator.new(); rng.seed = 426503
	var actors: Array = []
	for i in 700:
		actors.append({"uid":i+1,"position":Vector2(rng.randf_range(-9000,9000),rng.randf_range(-9000,9000)),"hp":0 if i%13==0 else 100,"damageable":i%17!=0,"role":"friendly" if i%7==0 else "","radius":900 if i%101==0 else 20,"guns":[{"id":"shield"}] if i%19==0 else []})
	var index = Index.new(); index.rebuild(actors,FakeDB.new())
	for iteration in 700:
		var at = Vector2(rng.randf_range(-12000,12000),rng.randf_range(-12000,12000))
		var reach = INF if iteration%3==0 else rng.randf_range(0,6000)
		check(index.nearest(at,reach).get("uid",-1)==brute_nearest(actors,at,reach),"nearest oracle %d"%iteration)
		var radius = rng.randf_range(0,2000)
		var expected = actors.filter(func(e): return at.distance_to(e.position)<radius)
		var actual = index.query(at-Vector2.ONE*radius,at+Vector2.ONE*radius).filter(func(e): return at.distance_to(e.position)<radius)
		check(ids(expected)==ids(actual),"area oracle/dead actors/order %d"%iteration)
		var end = at+Vector2(rng.randf_range(-1000,1000),rng.randf_range(-1000,1000))
		var bullet_radius = 300.0 if iteration%10==0 else 4.0
		var margin = Vector2.ONE*(bullet_radius+index.max_radius)
		expected = actors.filter(func(e): return Geometry2D.get_closest_point_to_segment(e.position,at,end).distance_to(e.position)<e.radius+bullet_radius)
		actual = index.query(at.min(end)-margin,at.max(end)+margin).filter(func(e): return Geometry2D.get_closest_point_to_segment(e.position,at,end).distance_to(e.position)<e.radius+bullet_radius)
		check(ids(expected)==ids(actual),"swept collision/large hull oracle %d"%iteration)
		var moved = actors[iteration%actors.size()]
		moved.position = at
		moved.hp = 0 if iteration%9==0 else 100
		# Target filtering reads live factions, including conversion after rebuilding.
		moved.role = "friendly" if iteration%4==0 else ""
		index.moved(moved)
	var ties = [{"uid":1,"position":Vector2(256,0),"hp":1,"damageable":true,"role":"","radius":20,"guns":[]},{"uid":2,"position":Vector2(-256,0),"hp":1,"damageable":true,"role":"","radius":20,"guns":[]}]
	index.rebuild(ties,FakeDB.new())
	check(index.nearest(Vector2.ZERO,INF).uid==1,"equal-distance cell boundary preserves first actor")
	check(index.nearest(Vector2.ZERO,256).is_empty(),"strict reach boundary")
	ties[0].position=Vector2(3000000,1000000); index.moved(ties[0]); ties[1].hp=0
	check(index.nearest(Vector2.ZERO,INF).uid==1,"unlimited reach remains unlimited after far teleport")
	index.rebuild([],FakeDB.new()); check(index.nearest(Vector2.ZERO,INF).is_empty(),"empty index")
	var db=preload("res://scripts/source_db.gd").new()
	var player=preload("res://scripts/centipede.gd").new(db)
	var battle=preload("res://scripts/combat.gd").new(db,player)
	var e=battle.spawn(db.pool["250"],Vector2(20,0))
	battle.refresh_spatial(); check(battle.entity(e.uid)==e,"UID map")
	var summoned=battle.spawn(db.pool["250"],Vector2(5,0))
	check(battle.nearest(Vector2.ZERO).uid==summoned.uid,"spawn updates active index")
	# Outside step there is deliberately no persistent index to outlive external array edits.
	battle.spatial_active=false; battle.enemies.clear()
	check(battle.nearest(Vector2.ZERO).is_empty() and battle.entity(e.uid).is_empty(),"external clear is immediately visible outside tick")
	battle.enemies=[e]; e.position=Vector2(-40,0)
	check(battle.nearest(Vector2.ZERO).uid==e.uid,"external replacement and movement outside tick")
	check(battle.entity(e.uid)==e and battle.entity(summoned.uid).is_empty(),"UID hints reject removed slots after external replacement")
	battle.enemies=[summoned,e];battle.refresh_spatial();battle.spatial_active=false
	battle.enemies.reverse()
	check(battle.entity(e.uid)==e and battle.entity(summoned.uid)==summoned,"UID hints validate identity after same-size external reorder")
	var variants: Array = []
	for optimized in [false,true]:
		var body=preload("res://scripts/centipede.gd").new(db)
		var combat=preload("res://scripts/combat.gd").new(db,body)
		for i in 12:
			var actor=combat.spawn(db.pool["250"],Vector2(-300+i*55,0),"friendly" if i>=8 else "")
			actor.guns=[]; actor.hp=100.0; actor.max_hp=100.0
			actor.kind="Asteroid"; actor.unit={}; actor.radius=40.0
		combat.enemies[2].hp=0.0
		combat.enemies[5].guns=[{"id":db.named("Core_Shield").id,"shield":2.0}]
		combat.enemies[9].guns=[{"id":db.named("Core_Shield").id,"shield":2.0}]
		if optimized: combat.refresh_spatial()
		var shot={"data":{"class":"BasicProjectile","projectileEffectArea":2.0},"damage":3.0,"shield_damage":3.0,"friendly":true,"chips":{},"velocity":Vector2.RIGHT*500,"position":Vector2(-300,0),"previous":Vector2(-350,0),"radius":4.0,"pierce":1,"hit":[]}
		# First hit exhausts the first eligible same-team shield. The second splashes dead actors too.
		combat.hit_enemy(combat.enemies[1],shot.duplicate(true))
		combat.hit_enemy(combat.enemies[1],shot.duplicate(true))
		shot.friendly=false; combat.hit_enemy(combat.enemies[8],shot.duplicate(true))
		shot.data={"class":"SonicBasicProjectile","pushBackForce":9.0,"projectileEffectArea":1.5}
		shot.friendly=true; combat.hit_enemy(combat.enemies[3],shot.duplicate(true))
		var homing=combat.nearest(Vector2(200,0)).get("uid",-1)
		combat.special.black_holes=[{"position":Vector2(30,0),"life":2.0,"radius":400.0,"damage":2.0,"shield_damage":1.0,"friendly":true,"force":1000.0},{"position":Vector2(-100,0),"life":2.0,"radius":100.0,"damage":2.0,"shield_damage":1.0,"friendly":true,"force":1000.0}]
		shot.data=db.kind("BlackHoleProjectile")[0]
		shot.position=Vector2(100,0)
		combat.hit_enemy(combat.enemies[3],shot.duplicate(true))
		check(combat.special.black_holes.size()==3,"black-hole projectile spawns sustained field, not immediate pull")
		combat.special.step(.1)
		variants.append({"actors":combat.enemies.map(func(a):return [a.uid,a.position,a.hp,a.guns]),"effects":combat.effects.map(func(effect):return [effect.kind,effect.position,effect.get("normal",Vector2.ZERO)]),"nearest":homing,"hits":combat.hit_count,"rng":str(combat.rng.state)})
	check(variants[0]==variants[1],"combat brute-force oracle: same-team shield order/break, dead splash, Sonic push, successive black holes, hit positions")
	var report={"checks":checks,"passed":checks-failures.size(),"failures":failures}
	print(JSON.stringify(report)); FileAccess.open("res://artifacts/combat-spatial-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit(0 if failures.is_empty() else 1)
