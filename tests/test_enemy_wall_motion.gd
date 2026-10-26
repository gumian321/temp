extends SceneTree

const World = preload("res://scripts/cave_world.gd")
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Encounters = preload("res://scripts/encounter_director.gd")
const Knockback = preload("res://scripts/knockback.gd")
var checks: Array = []
var measurements: Array = []

class SealedWall extends World:
	func original_solid(cell: Vector2i) -> bool: return cell.x >= 0
	func nearby(_area: Rect2) -> Array: return []

class DetourWall extends SealedWall:
	func original_solid(cell: Vector2i) -> bool: return cell.x >= 0 and cell.x <= 2 and absi(cell.y) < 7

class PendingWall extends SealedWall:
	func prepare_navigation(_data: Dictionary, _origin: Vector2, _target: Vector2, _margin: int) -> bool: return false

class EncounterSession extends RefCounted:
	var combat
	var player
	var db

func _initialize(): call_deferred("execute")

func check(ok: bool, label: String):
	checks.append({"name": label, "passed": ok})
	if not ok: printerr("FAIL: ", label)

func fixture(db, world, kind: String, start: Vector2, target: Vector2) -> Dictionary:
	var body = Body.new(db); body.terrain = world; body.head = target; body.refresh_positions()
	body.parts[0].hp = 1e9
	var battle = Battle.new(db, body)
	var e = battle.spawn(db.pool["250"], start)
	e.kind = kind; e.position = start; e.ground_previous = start; e.radius = 22.0; e.ground_radius = 22.0
	e.angle = PI / 2; e.warp = 0; e.guns = []; e.components = []; e.stop_distance = 0
	e.unit = e.unit.duplicate(true); e.unit.isDisableIfFar = false
	e.movement = {"enginePower": 3.0, "rotEngineModifier": 120.0}
	return {"body": body, "battle": battle, "actor": e}

func hold_route(setup: Dictionary, world):
	var e: Dictionary = setup.actor
	e.cave_path = PackedVector2Array(); e.cave_visible = false; e.cave_no_route = true
	e.cave_revision = world.revision; e.cave_radius = e.radius; e.cave_target = setup.body.head; e.cave_until = 100000

func execute():
	var db = DB.new()
	for fps in [30, 60, 120]:
		for kind in ["AISwarmingUnit", "AIFollowingUnit", "AIPatrolUnit"]:
			var world = SealedWall.new(); world.reset_cave(true)
			var setup = fixture(db, world, kind, Vector2(-30, 12), Vector2(180, 12))
			var e: Dictionary = setup.actor
			hold_route(setup, world)
			e.guns = [{"id": db.named("Core_Gun_Gatling").id, "cooldown": 10.0, "angle": 0.0}]
			var start: Vector2 = e.position; var heading: float = e.angle
			var max_drift = 0.0; var max_turn = 0.0
			for frame in fps * 2:
				setup.battle.step(1.0 / fps, setup.body.head, false, false)
				max_drift = maxf(max_drift, start.distance_to(e.position))
				max_turn = maxf(max_turn, absf(angle_difference(heading, e.angle)))
			check(max_drift < .001 and max_turn < .001, "%s waits at a sealed wall without drifting or turning to zero at %d FPS" % [kind, fps])
			check(absf(e.guns[0].cooldown - 8.0) < .001 and absf(e.age - 2.0) < .001, "%s keeps combat timers running while waiting at %d FPS" % [kind, fps])
			measurements.append({"kind": kind, "fps": fps, "sealed_drift": max_drift, "sealed_turn": max_turn})
			Knockback.add_impulse(e, Vector2.LEFT, 2.0)
			setup.battle.step(1.0 / fps, setup.body.head, false, false)
			check(e.position.x < start.x - .5 and not world.blocked(e.position, e.radius) and e.angle == heading, "%s still accepts physical knockback while waiting at %d FPS" % [kind, fps])

			world = DetourWall.new(); world.reset_cave(true)
			setup = fixture(db, world, kind, Vector2(-100, 12), Vector2(220, 12)); e = setup.actor
			var safe = true; var waiting_still = true; var max_step = 0.0; var reached = false
			for frame in fps * 18:
				var before: Vector2 = e.position; var before_angle: float = e.angle
				setup.battle.step(1.0 / fps, setup.body.head, false, false)
				var moved = before.distance_to(e.position); max_step = maxf(max_step, moved)
				safe = safe and not world.blocked(e.position, e.radius)
				if not e.get("cave_visible", false) and e.get("cave_path", PackedVector2Array()).is_empty():
					waiting_still = waiting_still and moved < .001 and absf(angle_difference(before_angle, e.angle)) < .001
				if Vector2(e.position).distance_to(setup.body.head) < 30: reached = true; break
			check(waiting_still, "%s preserves position and heading while its first wall detour is being prepared at %d FPS" % [kind, fps])
			check(safe and reached and max_step <= 144.0 / fps + .01, "%s resumes and follows a clear wall detour without collision jumps at %d FPS" % [kind, fps])
			measurements.append({"kind": kind, "fps": fps, "detour_clear": safe, "reached": reached, "max_step": max_step, "remaining": Vector2(e.position).distance_to(setup.body.head)})

		for kind in ["charger", "broodmother", "hatchling", "treasure"]:
			var world = PendingWall.new(); world.reset_cave(true)
			var setup = fixture(db, world, "AISwarmingUnit", Vector2(-30, 12), Vector2(180, 12))
			var owner = EncounterSession.new(); owner.combat = setup.battle; owner.player = setup.body; owner.db = db
			setup.battle.encounters = Encounters.new(owner)
			var e: Dictionary = setup.actor
			e.encounter_type = kind; e.encounter_phase = "approach"; e.contact_left = 0.0; e.shot_left = 100.0
			hold_route(setup, world)
			var start: Vector2 = e.position; var heading: float = e.angle
			var stable = true
			for frame in fps:
				setup.battle.step(1.0 / fps, setup.body.head, false, false)
				stable = stable and start.distance_to(e.position) < .001 and absf(angle_difference(heading, e.angle)) < .001
			check(stable and e.encounter_phase == "approach", "%s special preserves its pose and phase while wall navigation is pending at %d FPS" % [kind, fps])
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "measurements": measurements}
	FileAccess.open("res://artifacts/enemy-wall-motion-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
