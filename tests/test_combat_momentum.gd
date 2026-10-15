extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
var checks: Array = []
var db

func check(value: bool, title: String):
	checks.append({"name": title, "passed": value})
	if not value: printerr("FAIL: ", title)

func actor(battle, at: Vector2 = Vector2(500, 0)) -> Dictionary:
	var e = battle.spawn(db.pool["250"], at)
	e.components = []; e.guns = []; e.movement = {"enginePower": 0.0}
	e.unit = e.unit.duplicate(true); e.unit.scrapsCount = 0
	return e

func shot(damage: float) -> Dictionary:
	return {"data": {"class": "BasicProjectile"}, "damage": damage, "shield_damage": damage, "friendly": true, "chips": {}, "velocity": Vector2.RIGHT, "position": Vector2.ZERO, "pierce": 1}

func _initialize():
	db = DB.new()
	var player = Body.new(db)
	var battle = Battle.new(db, player)
	battle.drones.clear(); battle.momentum.enabled = true
	var m = battle.momentum
	var stats = player.stats.duplicate(true)
	battle.character_abilities.cooldown = 10
	for i in range(18):
		var e = actor(battle)
		battle.hit_enemy(e, shot(10000))
		if i in [4, 9]:
			battle.step(0, Vector2.RIGHT, false, false)
			check(is_equal_approx(battle.character_abilities.cooldown, 9 if i == 4 else 7.5), "5/10 real kills refund skill cooldown")
	battle.step(0, Vector2.RIGHT, false, false)
	check(m.chain == 18 and m.bursts == 1 and m.burst_left == 6, "Same-frame multikill crosses 18 and activates exactly one six-second burst")
	check(is_equal_approx(battle.character_abilities.cooldown, 5.5), "Burst adds a bounded two-second skill refund")
	battle.step(0, Vector2.RIGHT, false, false)
	check(m.chain == 18 and m.bursts == 1, "A processed death is never counted twice")
	var core = db.named("Core_Gun_Gatling")
	m.burst_left = 0
	battle.fire(core, Vector2.ZERO, Vector2.RIGHT, true)
	var base_damage: float = battle.bullets.back().damage
	m.burst_left = 6
	battle.fire(core, Vector2.ZERO, Vector2.RIGHT, true)
	check(is_equal_approx(battle.bullets.back().damage, base_damage * 1.25), "Player projectiles gain exactly 25 percent damage")
	battle.fire(core, Vector2.ZERO, Vector2.RIGHT, false)
	check(is_equal_approx(battle.bullets.back().damage, base_damage), "Hostile projectiles never receive player burst buffs")
	battle.fire(core, Vector2.ZERO, Vector2.RIGHT, true, {}, 0, true, 0, 1, "enemy:7:0")
	check(is_equal_approx(battle.bullets.back().damage, base_damage), "Mission allies retain their own damage")
	battle.bullets.clear()
	var target = actor(battle, Vector2(50, 0)); target.hp = 10000; target.max_hp = 10000
	var flame = db.named("Core_Gun_Flame Thrower")
	m.burst_left = 0
	battle.special.continuous(flame, Vector2.ZERO, Vector2.RIGHT, true, {}, 0, .1, "player:0")
	var base_continuous: float = 10000 - target.hp
	target.hp = 10000; m.burst_left = 6
	battle.special.continuous(flame, Vector2.ZERO, Vector2.RIGHT, true, {}, 0, .1, "player:0")
	check(base_continuous > 0 and is_equal_approx(10000 - target.hp, base_continuous * 1.25 * 1.35), "Continuous weapons receive equivalent damage and throughput bonuses")
	battle.enemies.clear(); player.parts[0].cooldown = 10
	battle.step(.1, Vector2.RIGHT, false, false)
	check(is_equal_approx(player.parts[0].cooldown, 9.865), "Real weapon reload progresses 35 percent faster during burst")
	m.step(6)
	check(m.damage_multiplier() == 1 and m.rate_multiplier() == 1 and player.stats == stats, "Burst expires without changing permanent stats")
	check(m.chain == 0 and m.best == 18, "Missing the chain window resets the streak but retains personal best")
	var valid = {"kind": "AISwarmingUnit", "role": "", "damageable": true, "last_friendly": true}
	for override in [{"kind": "Asteroid"}, {"kind": "ContainerObject"}, {"role": "friendly"}, {"last_friendly": false}, {"despawn": true}, {"self_destructed": true}, {"damageable": false}]:
		var invalid = valid.duplicate(); invalid.merge(override, true)
		m.on_kill(invalid, battle)
	check(m.chain == 0, "Props, allies, suicide, despawn and unattributed deaths cannot farm streaks")
	for i in range(36): m.on_kill(valid, battle)
	check(m.bursts == 1, "More kills cannot retrigger or extend burst during recovery")
	m.step(18)
	battle.character_abilities.cooldown = .2
	for i in range(18): m.on_kill(valid, battle)
	check(m.bursts == 2 and battle.character_abilities.cooldown == 0, "A fresh streak can burst after recovery; refunds never make negative cooldown")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks}
	FileAccess.open("res://artifacts/combat-momentum-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
