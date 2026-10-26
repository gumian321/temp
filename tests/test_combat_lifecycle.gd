extends SceneTree
## Exercise damage through the real enemy tick and death cleanup phases.
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
var db
var checks: Array = []

func _initialize(): call_deferred("execute")

func check(ok: bool, title: String):
	checks.append({"name": title, "passed": ok})
	if not ok: printerr("FAIL: ", title)

func fixture():
	var body = Body.new(db)
	var battle = Battle.new(db, body)
	battle.drones.clear()
	return battle

func kamikaze(battle, at: Vector2, radius: float = 0.25) -> Dictionary:
	var enemy = battle.spawn(db.pool["250"], at)
	enemy.guns = []
	enemy.movement = {"enginePower": 0.0, "rotEngineModifier": 0.0}
	enemy.components = [{"class": "KamikazeTrigger", "explosionArea": radius,
		"explosionDamage": {"hullDamage": 10.0, "shieldDamage": 2.0}}]
	return enemy

func tick(battle): battle.step(1.0 / 60.0, Vector2.RIGHT * 1000, false, false)

func execute():
	db = DB.new()
	var battle = fixture()
	var enemy = kamikaze(battle, battle.player.head)
	var hp = float(battle.player.parts[0].hp)
	tick(battle)
	check(is_equal_approx(hp - float(battle.player.parts[0].hp), 10.0), "A contact explosion applies its configured damage exactly once")
	check(battle.kills == 1 and battle.enemies.is_empty(), "A contact explosion removes and counts the attacker once")
	tick(battle)
	check(is_equal_approx(hp - float(battle.player.parts[0].hp), 10.0) and battle.kills == 1, "The resolved explosion cannot damage or count again on the next tick")

	battle = fixture()
	enemy = kamikaze(battle, battle.player.head + Vector2(20, 0))
	hp = float(battle.player.parts[0].hp)
	tick(battle)
	check(is_equal_approx(hp - float(battle.player.parts[0].hp), 10.0), "Touching a hull still detonates even when its center is outside the small blast radius")

	battle = fixture()
	battle.player.append_segment(str(db.named("Core_Gun_Gatling").id))
	var head = battle.player.parts[0]
	var neighbor = battle.player.parts[1]
	head.hp = 100.0; neighbor.hp = 100.0
	enemy = kamikaze(battle, battle.player.head, 4.0)
	tick(battle)
	check(is_equal_approx(float(head.hp), 90.0) and is_equal_approx(float(neighbor.hp), 90.0), "Contact and neighboring hulls each receive one explosion hit")

	battle = fixture()
	battle.player.append_segment(str(db.named("Core_Shield").id))
	var shield = battle.player.parts[1]
	shield.shield = 50.0; shield.shield_delay = 100.0
	hp = float(battle.player.parts[0].hp)
	enemy = kamikaze(battle, battle.player.head)
	tick(battle)
	check(is_equal_approx(float(shield.shield), 48.0) and is_equal_approx(float(battle.player.parts[0].hp), hp), "A protecting shield absorbs contact blast damage once")

	battle = fixture()
	enemy = kamikaze(battle, battle.player.head + Vector2(30, 0), 1.0)
	enemy.hp = 0.0
	hp = float(battle.player.parts[0].hp)
	tick(battle)
	check(is_equal_approx(hp - float(battle.player.parts[0].hp), 10.0), "Shooting a kamikaze still triggers its nearby death explosion")

	battle = fixture()
	enemy = kamikaze(battle, battle.player.head + Vector2(200, 0), 1.0)
	enemy.hp = 0.0
	hp = float(battle.player.parts[0].hp)
	tick(battle)
	check(is_equal_approx(float(battle.player.parts[0].hp), hp), "A distant death explosion cannot damage the player")

	battle = fixture()
	enemy = kamikaze(battle, battle.player.head)
	enemy.unit = enemy.unit.duplicate(true)
	enemy.unit.UseActionDistance = false
	enemy.guns = [{"id": db.named("Core_Gun_Gatling").id, "cooldown": 0.0, "angle": 0.0, "offset": Vector2.ZERO}]
	tick(battle)
	check(battle.shot_serial == 0, "An enemy cannot fire after detonating in the same tick")
	var report = {"checks": checks, "passed": checks.all(func(item): return item.passed)}
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
