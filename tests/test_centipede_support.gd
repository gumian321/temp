extends SceneTree

const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/centipede.gd")
const Battle = preload("res://scripts/combat.gd")
var errors: Array = []
var checks = 0

func check(value: bool, description: String):
	checks += 1
	if not value:
		errors.append(description)
		printerr("FAIL: ", description)

# The support is visually beside tower 2, but its old grid cell is beside tower 1.
func support_fixture(db, support_name: String):
	var player = Body.new(db)
	player.add_piece(db.named("Core_Gun_Gatling").id, Vector2i(0, -1))
	player.add_piece(db.named("Core_Gun_Gatling").id, Vector2i(1, -1))
	player.add_piece(db.named(support_name).id, Vector2i(-1, 0))
	return player

func _initialize():
	var db = DB.new()
	var player = support_fixture(db, "Core_Chip_Mammoth")
	check(player.adjacent_part_indices(0) == [1], "the head is adjacent only to the first body segment")
	check(player.adjacent_part_indices(2) == [1, 3], "support neighbors follow the visible body order")
	check(player.chips(1).is_empty(), "a hidden-grid neighbor two body segments away receives no chip buff")
	check(player.chips(2).get(5, 0) == 1, "a visibly adjacent tower receives its chip despite distant legacy coordinates")
	check(player.chips(0).is_empty(), "head chip compatibility stays unchanged")
	player.begin_support_tick()
	check(player.chips(1).is_empty() and player.chips(2).get(5, 0) == 1, "cached support ticks use the same visible adjacency")
	player.end_support_tick()
	player.actions.swap = 1
	player.swap_piece(1, 2)
	check(player.chips(1).get(5, 0) == 1 and player.chips(2).is_empty(), "swapping towers immediately updates their chip buffs")
	player.append_segment(db.named("Core_Gun_Gatling").id)
	player.append_segment(db.named("Core_Chip_Mammoth").id)
	check(player.chips(4).get(5, 0) == 2, "two flanking chip segments provide two levels")
	player.parts[3].hp = 0
	check(player.chips(4).get(5, 0) == 1, "a destroyed adjacent chip stops applying its buff")

	player = support_fixture(db, "Core_Repair")
	var battle = Battle.new(db, player)
	for part in player.parts:
		part.hp -= 20.0
	var before = player.parts.map(func(part): return part.hp)
	battle.step(0.25, Vector2.RIGHT, false)
	check(player.parts[1].hp == before[1], "repair does not reach a hidden-grid neighbor beyond the adjacent segment")
	check(player.parts[2].hp > before[2], "repair heals the visually adjacent tower")
	check(player.parts[3].hp > before[3], "repair retains self-healing")
	check(player.parts[0].hp == before[0], "a distant repair segment cannot repair the head through old grid adjacency")
	player = Body.new(db)
	player.append_segment(db.named("Core_Repair").id)
	battle = Battle.new(db, player)
	player.parts[0].hp -= 20.0
	var head_before: float = player.parts[0].hp
	battle.step(0.25, Vector2.RIGHT, false)
	check(player.parts[0].hp > head_before, "a repair module on the first segment can heal the adjacent head")

	player = support_fixture(db, "Core_Clocking")
	battle = Battle.new(db, player)
	battle.special.step(0.01)
	check(not player.parts[1].cloaked and player.parts[2].cloaked, "cloaking covers the visible neighbor instead of the hidden-grid neighbor")
	player.parts[3].stun = 1.0
	battle.special.step(0.01)
	check(not player.parts[2].cloaked, "stunning the neighboring cloaking module restores visibility")
	player.parts[3].stun = 0.0
	player.parts[3].hp = 0.0
	battle.special.step(0.01)
	check(not player.parts[2].cloaked, "destroying the neighboring cloaking module restores visibility")

	player = Body.new(db)
	var gun: String = db.named("Core_Gun_Gatling").id
	for y in range(1, 4):
		player.add_piece(gun, Vector2i(0, -y))
	battle = Battle.new(db, player)
	var surviving_hp: float = player.parts[2].hp
	battle.hurt_player(1, player.parts[1].hp + 1, 0)
	check(player.parts[2].hp == surviving_hp and player.parts[3].hp > 0, "destroying a former grid bridge leaves other mounted towers alive")
	check(player.detached_indices() == [1], "cleanup identifies only the destroyed tower")
	battle.step(0.01, Vector2.RIGHT, false)
	check(player.parts.size() == 3 and player.parts[1].cell == Vector2i(0, -2), "cleanup removes only the destroyed mount and retains survivor order")
	check(player.segment_count() == 6, "the living centipede keeps its visible bare body after a mount is destroyed")
	check(player.append_segment(gun) and player.segment_index(3) == 3, "new equipment attaches behind surviving mounts after a loss")
	print(JSON.stringify({"checks": checks, "passed": checks - errors.size(), "failures": errors}))
	quit(0 if errors.is_empty() else 1)
