extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
var checks: Array = []
func check(ok: bool, title: String):
	checks.append({"name": title, "passed": ok})
	if not ok: printerr("FAIL: ", title)
func _initialize(): call_deferred("execute")
func execute():
	var db = DB.new()
	var gun = db.named("Core_Gun_Gatling").id
	var body = Body.new(db)
	body.configure_character("spider")
	check(body.module_cap() == 32 and body.body_poses.size() == 33 and body.parts.size() == 1, "Eight bare legs expose 32 possible articulated mounts without phantom modules")
	check(body.spider_mount(7, 3) == 32 and body.spider_mount(8, 0) == -1 and body.spider_leg_for_mount(0) == -1 and body.spider_depth_for_mount(33) == -1, "Mount encoding validates its bounds")
	check(not body.install_module(gun, 17) and body.parts.size() == 1, "An empty leg rejects depth gaps")
	for depth in 4:
		check(body.install_module(gun, body.spider_mount(0, depth)), "Leg accepts module depth %d" % depth)
	var identities: Array = body.parts.map(func(p): return p.feedback_uid)
	check(not body.install_module(gun, 1) and body.parts.map(func(p): return p.feedback_uid) == identities, "Full-leg insertion rejects without overwriting any module")
	check(body.install_module(gun, 2), "Another leg remains available")
	var moved_uid = body.parts[5].feedback_uid
	check(not body.move_to_mount(5, 1) and body.parts[5].feedback_uid == moved_uid and body.parts[5].segment == 2, "Cross-leg move to a full leg rejects atomically")
	var tip_uid = body.parts[4].feedback_uid
	check(body.move_to_mount(4, 1) and body.parts[4].feedback_uid == tip_uid and body.parts[4].segment == 1 and body.parts[1].segment == 9, "Same-leg insertion keeps array indices and identities stable")
	check(body.move_to_mount(4, 2) and body.parts[4].segment == 2 and body.parts[5].segment == 10 and body.spider_leg_count(0) == 3, "Cross-leg insertion shifts target outward and closes source gap")
	var count = body.parts.size()
	check(body.install_module(gun, 1) and body.parts.size() == count + 1 and body.parts[1].segment == 9, "Insertion into occupied non-full leg preserves all existing modules")
	var root_a = body.part_at(1)
	var root_b = body.part_at(2)
	check(body.adjacent_part_indices(root_a).has(0) and body.adjacent_part_indices(root_a).has(body.part_at(9)) and not body.adjacent_part_indices(root_a).has(root_b), "Support adjacency follows same-leg order and roots connect to HQ")
	check(body.adjacent_part_indices(0).size() == 2 and not body.adjacent_part_indices(body.part_at(17)).has(0), "HQ has no phantom adjacency to deeper leg modules")
	var battle = Battle.new(db, body)
	var dead_index = body.part_at(9)
	# Anchored-mine cleanup uses real mine cores and ring slots, as production does.
	var mine_core = db.named("Core_MinesField")
	body.replace_module(dead_index, mine_core.id)
	body.replace_module(body.part_at(17), mine_core.id)
	body.parts[dead_index].cooldown = 100.0
	body.parts[body.part_at(17)].cooldown = 100.0
	var survivor: Dictionary = body.parts[body.part_at(17)]
	var survivor_uid = survivor.feedback_uid
	var survivor_hp = survivor.hp
	var other_leg_mounts = body.spider_leg_indices(1).map(func(i): return body.parts[i].segment)
	var drone = db.kind("MainCoreDroneReward")[0]
	battle.add_drone(body.parts.find(survivor), db.asset(drone.drone))
	var drone_uid = battle.drones[-1].uid
	battle.special.mines = [
		{"owner": dead_index, "anchored": true, "slot": 0, "data": db.asset(mine_core.coreMine), "chips": {}, "offset": Vector2.ZERO, "position": body.parts[dead_index].position, "life": 10.0},
		{"owner": body.parts.find(survivor), "anchored": true, "slot": 0, "data": db.asset(mine_core.coreMine), "chips": {}, "offset": Vector2.ZERO, "position": survivor.position, "life": 10.0}
	]
	battle.hurt_player(dead_index, 100000, 100000)
	battle.step(0.01, Vector2.RIGHT * 700, false)
	check(body.parts.size() == count and body.spider_leg_count(0) == 3 and survivor.feedback_uid == survivor_uid and survivor.hp == survivor_hp and survivor.segment == 9, "Destroying one middle module shortens only that leg and keeps outer survivors intact")
	check(body.spider_leg_indices(1).map(func(i): return body.parts[i].segment) == other_leg_mounts, "Destruction leaves every other leg unchanged")
	var owned = battle.drones.filter(func(d): return d.uid == drone_uid)
	check(owned.size() == 1 and body.parts[owned[0].owner].feedback_uid == survivor_uid, "Combat cleanup remaps surviving drone ownership by array index")
	check(battle.special.mines.size() == 1 and body.parts[battle.special.mines[0].owner].feedback_uid == survivor_uid, "Cleanup removes destroyed anchored mine and remaps surviving mine owner")
	var synchronized = true
	for frame in 120:
		body.step(1.0 / 60, Vector2.RIGHT if frame < 60 else Vector2.DOWN, false)
		for i in range(1, body.parts.size()):
			var pose = body.spider_rig.mount_pose(body.parts[i].segment)
			synchronized = synchronized and body.parts[i].position.distance_to(pose.point) < 0.001 and body.weapon_origin(i).distance_to(pose.point) < 0.001
	check(synchronized, "Firing origins and collision centers follow authoritative rig mount positions")
	while body.parts.size() - 1 < 32: body.append_segment(gun)
	check(not body.append_segment(gun) and body.parts.size() == 33 and body.spider_leg_count(7) == 4, "Balanced append fills all eight legs to four modules and enforces total cap")
	var replacement_index = body.part_at(9)
	var replacement_uid = body.parts[replacement_index].feedback_uid
	check(battle.replace_character_module(replacement_index, db.named("Core_Gun_Cannon").id) and body.parts[replacement_index].segment == 9 and body.parts[replacement_index].feedback_uid != replacement_uid and body.spider_leg_count(0) == 4, "Explicit replacement retains leg depth and count while giving the new module fresh identity")
	body.configure_character("spider")
	body.install_module(gun, 1)
	body.install_module(gun, 2)
	body.install_module(db.named("Core_Chip_Mammoth").id, 9)
	check(body.chips(1).get(5, 0) == 1 and body.chips(2).is_empty() and body.chips(0).is_empty(), "Actual chip effects reach the same-leg neighbor only and preserve HQ exclusion")
	body.replace_module(3, db.named("Core_Repair").id)
	battle = Battle.new(db, body)
	for part in body.parts: part.hp -= 20.0
	var health_before = body.parts.map(func(p): return p.hp)
	battle.step(0.25, Vector2.RIGHT * 700, false)
	check(body.parts[1].hp > health_before[1] and body.parts[3].hp > health_before[3] and body.parts[2].hp == health_before[2] and body.parts[0].hp == health_before[0], "Actual repair heals self and same-leg neighbor without cross-leg or remote HQ repair")
	body.configure_character("beetle")
	check(body.character_id == "centipede" and body.module_cap() == 60 and not body.compact_body() and body.append_segment(gun) and body.parts[1].segment == 1, "Legacy Beetle configuration safely uses active centipede chain semantics")
	body.configure_character("centipede")
	check(body.module_cap() == 60 and body.append_segment(gun) and body.append_segment(gun) and body.segment_count() == 2, "Centipede chain growth remains unchanged")
	var report = {"checks": checks, "passed": checks.all(func(c): return c.passed)}
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
