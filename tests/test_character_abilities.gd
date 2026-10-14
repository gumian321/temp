extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
var checks: Array = []
var db
func check(ok: bool, title: String):
	checks.append({"name":title,"passed":ok})
	if not ok: printerr("FAIL: ",title)
func _initialize(): call_deferred("execute")
func actor(battle, at: Vector2, kind = "AISwarmingUnit") -> Dictionary:
	var e = battle.spawn(db.pool["250"], at)
	e.hp = 10000; e.max_hp = 10000; e.guns = []; e.components = []
	e.kind = kind; e.unit = {"canBeStunned":true}; e.movement = {}; e.parent = 0
	return e
func execute():
	db = DB.new()
	var body = Body.new(db)
	var gun = str(db.named("Core_Gun_Gatling").id)
	for i in 20: body.append_segment(gun)
	var battle = Battle.new(db, body)
	var before = Vector2(body.parts[-1].position).distance_to(body.head)
	check(battle.request_skill(Vector2(100,0)) and body.coil_active, "Centipede coil activates")
	check(Vector2(body.parts[-1].position).distance_to(body.head) < before / 2, "Coil physically concentrates long body weapon origins")
	var foe = actor(battle,Vector2(100,0))
	var other = actor(battle,Vector2(-100,0))
	check(battle.character_abilities.focus_target(Vector2.ZERO, 300, other) == foe, "Coil concentrates fire toward chosen target")
	check(not battle.request_skill(Vector2.ZERO), "Cooldown rejects skill spam")
	for i in 30: battle.character_abilities.update(0.1)
	check(not body.coil_active and battle.character_abilities.cooldown > 0, "Coil expires before cooldown")
	body.configure_character("spider"); battle = Battle.new(db, body)
	for i in 32: check(body.append_segment(gun), "Spider accepts mount %d" % (i + 1))
	check(not body.append_segment(gun) and body.segment_count() == 32, "Spider caps four modules on each of eight legs")
	# Four 54-unit links grow at 105 units/second; allow the complete expansion.
	for frame in 180: body.step(1.0 / 60, Vector2.ZERO, false)
	check(body.spider_rig.legs.all(func(leg): return is_equal_approx(leg.length, body.spider_rig.BASE_LENGTH + body.spider_rig.MODULE_LENGTH * 4)), "Fully equipped spider grows all eight articulated legs")
	foe = actor(battle, Vector2(250, 0))
	var boss = actor(battle, Vector2(250, 40), "AIBossPartController")
	for i in 5: actor(battle, Vector2(260 + i, -20))
	check(battle.request_skill(Vector2(250,0)) and battle.character_abilities.threads.size() == 4, "Silk target count is bounded at four")
	var boss_position: Vector2 = boss.position
	battle.character_abilities.update(0.1)
	check(foe.position.x < 250 and foe.stun > 0, "Silk pulls and binds actual enemies")
	check(boss.position == boss_position and boss.stun == 0, "Boss resists silk displacement and binding")
	var timer = battle.character_abilities.cooldown
	body.step(0.1, Vector2.ZERO, false)
	check(battle.character_abilities.cooldown == timer, "Body/render updates cannot tick skill cooldown during pause")
	body.reset(); battle.character_abilities.update(0)
	check(battle.character_abilities.threads.is_empty() and battle.character_abilities.cooldown == 0, "Run reset clears old active skill and cooldown")
	body.configure_character("beetle"); battle = Battle.new(db, body)
	var hp = float(body.parts[0].hp)
	battle.hurt_player(0, 20, 20, {"velocity":Vector2.LEFT,"position":Vector2(100,0),"data":{},"damage":20,"radius":0})
	check(is_equal_approx(body.parts[0].hp, hp - 8) and battle.character_abilities.armor == 88, "Forward armor absorbs sixty percent and spends finite armor")
	hp = float(body.parts[0].hp)
	battle.hurt_player(0,20,20)
	check(body.parts[0].hp == hp - 20, "Unknown damage direction cannot claim armor protection")
	hp = float(body.parts[0].hp)
	battle.hurt_player(0,20,20,{"velocity":Vector2.RIGHT,"position":Vector2(-100,0),"data":{},"damage":20,"radius":0})
	check(body.parts[0].hp == hp - 20, "Rear damage bypasses forward armor")
	body.reset(); battle = Battle.new(db,body)
	foe = actor(battle, Vector2(100,0))
	check(battle.request_skill(Vector2(500,0)) and battle.character_abilities.armor == 65, "Rush spends armor on activation")
	for i in 10: battle.character_abilities.update(0.1)
	check(foe.hp == 9915 and not body.rush_active, "Swept rush hits each foe exactly once and expires")
	check(body.head.x > 250, "Rush moves actual hull")
	body.reset(); battle = Battle.new(db,body)
	boss = actor(battle, Vector2(130,0), "AIBossPartController")
	battle.request_skill(Vector2(500,0))
	for i in 10: battle.character_abilities.update(0.1)
	check(body.head.x < 130 and not body.rush_active, "Rush stops before boss instead of tunneling")
	check(not battle.request_skill(Vector2.ZERO), "Expired rush retains its cooldown")
	body.reset(); battle = Battle.new(db, body)
	body.parts[0].stun = 1
	check(not battle.request_skill(Vector2.RIGHT), "Stunned head cannot activate a skill")
	body.parts[0].stun = 0
	battle.character_abilities.armor = 34
	check(not battle.request_skill(Vector2.RIGHT), "Insufficient armor prevents rush")
	body.parts[0].hp -= 10
	var injured = float(body.parts[0].hp)
	body.refresh_upgrades(); body.refresh_upgrades()
	check(is_equal_approx(body.parts[0].hp, injured), "Repeated refresh does not heal or compound character health")
	var original = float(db.asset(db.stores.PlayerDataStore.HQCore).CoreHealth)
	check(is_equal_approx(body.parts[0].max_hp, original * 1.2), "Beetle health modifier changes real hull health")
	body.configure_character("centipede")
	check(is_equal_approx(body.parts[0].max_hp, original), "Switching character never mutates shared catalog health")
	var report = {"checks":checks,"passed":checks.all(func(c):return c.passed)}
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
