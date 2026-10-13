extends SceneTree

const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/centipede.gd")
var errors: Array = []
var checks = 0

func check(value: bool, description: String):
	checks += 1
	if not value:
		errors.append(description)
		printerr("FAIL: ", description)

func _initialize():
	var db = DB.new()
	var player = Body.new(db)
	var gun: String = db.named("Core_Gun_Gatling").id
	check(player.parts.size() == 1 and player.segment_count() == 6, "fresh centipede has six visible bare segments without free equipment")
	check(player.segment_pose(6).point == Vector2(-348, 0), "bare tail exists before the first tower")
	check(player.append_segment(gun) and player.append_segment(gun), "towers can be mounted one segment at a time")
	check(player.parts[1].cell.y == player.parts[2].cell.y, "fixture covers two legacy grid cells in the same row")
	check(player.parts[1].position.distance_to(player.parts[2].position) == player.body_spacing, "same-row towers occupy distinct consecutive body segments")
	check(player.parts[1].position.y == 0 and player.parts[2].position.y == 0, "towers sit on the spine without sideways grid offsets")
	check(player.segment_index(1) == 1 and player.segment_index(2) == 2, "construction exposes the exact tower segment number")
	check(player.append_segment(gun), "third tower appends successfully")
	var cells = player.parts.map(func(part): return part.cell)
	player.actions.move = 1
	check(not player.move_piece_to_segment(1, 0) and not player.move_piece_to_segment(1, 99) and player.actions.move == 1, "invalid segment targets preserve the move action")
	check(player.move_piece_to_segment(1, 3), "move operation relocates a tower along the body")
	check(player.segment_index(1) == 3 and player.actions.move == 0, "moving consumes one action and updates its segment")
	check(player.connected() and player.parts.all(func(part): return part.cell in cells), "moving preserves blueprint connectivity and support cells")
	player.actions.swap = 1
	check(player.swap_piece(1, 2) and player.segment_index(1) == 1, "swap exchanges the visible body slots")
	player.actions.duplicate = 1
	check(player.duplicate_piece(1, player.next_segment_cell()) and player.segment_index(4) == 4, "duplicate attaches its new tower to the next segment")
	while player.parts.size() <= int(db.stores.PlayerDataStore.maxBuiltCores):
		if not player.append_segment(gun):
			check(false, "sequential construction reaches every allowed tower")
			break
	check(player.parts.size() == 61 and player.segment_count() == 60, "full construction exposes all sixty separate tower segments")
	check(not player.append_segment(gun), "sequential construction honors the existing sixty-tower limit")
	var poses_unique = true
	var ordered = player.body_part_indices()
	for i in range(ordered.size()):
		poses_unique = poses_unique and player.parts[ordered[i]].position == Vector2(-(i + 1) * player.body_spacing, 0)
	check(poses_unique, "each full-capacity tower has exactly one ordered spine position")
	var finite = true
	var minimum_gap = INF
	var maximum_step = 0.0
	for frame in range(1200):
		var previous = player.parts.map(func(part): return part.position)
		var direction = Vector2.from_angle(floorf(frame / 150.0) * PI * 0.75)
		player.step(1.0 / 60.0, direction, false)
		var previous_point: Vector2 = player.head
		for index in ordered:
			var point: Vector2 = player.parts[index].position
			finite = finite and point.is_finite() and point.distance_to(player.head) <= player.segment_count() * player.body_spacing + 1
			minimum_gap = minf(minimum_gap, previous_point.distance_to(point))
			maximum_step = maxf(maximum_step, previous[index].distance_to(point))
			previous_point = point
	check(finite, "long bodies remain finite and bounded by their actual chain length")
	check(minimum_gap > 42.0, "hard steering keeps neighboring segments visibly separated")
	check(maximum_step < 6.0, "turning advances the long tail smoothly without teleporting")
	var tail: Vector2 = player.segment_pose(60).point
	for frame in range(120):
		player.step(1.0 / 60.0, Vector2.ZERO, false)
	check(player.segment_pose(60).point.distance_to(tail) < 60, "stopping settles the existing body path")
	var survivor_cell: Vector2i = player.parts[player.body_part_indices()[1]].cell
	player.parts.remove_at(player.body_part_indices()[0])
	player.refresh_positions()
	check(player.append_segment(gun), "a lost segment can be replaced")
	check(player.parts[player.body_part_indices()[0]].cell == survivor_cell, "reusing a freed blueprint cell leaves surviving towers in order")
	check(player.segment_index(player.parts.size() - 1) == 60, "replacement tower attaches to the tail instead of filling a visual hole")
	var report = {"checks": checks, "passed": checks - errors.size(), "failures": errors, "minimum_neighbor_gap": minimum_gap, "maximum_tower_step": maximum_step}
	print(JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
