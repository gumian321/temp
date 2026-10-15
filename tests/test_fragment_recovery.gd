extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Run = preload("res://scripts/run_state.gd")
const Save = preload("res://scripts/save_store.gd")
var checks: Array = []
var db
var gun: String

func _initialize(): call_deferred("execute")

func check(ok: bool, label: String):
	checks.append({"name": label, "passed": ok})
	if not ok: printerr("FAIL: ", label)

func make_body(count: int):
	var body = Body.new(db)
	for i in count: body.append_segment(gun)
	for frame in 30: body.step(1.0 / 60.0, Vector2.ZERO, false)
	return body

func uids(parts: Array) -> Array:
	return parts.map(func(p): return int(p.feedback_uid))

func active_uids(body) -> Array:
	return body.body_part_indices().map(func(i): return int(body.parts[i].feedback_uid))

func fragment_uids(body) -> Array:
	return body.detached_fragments.map(func(group): return uids(group.parts))

func fragment_positions(body) -> Dictionary:
	var result: Dictionary = {}
	for group in body.detached_fragments:
		for i in group.parts.size(): result[int(group.parts[i].feedback_uid)] = Vector2(group.poses[i].point)
	return result

func unique_ownership(body) -> bool:
	var seen: Dictionary = {}
	for part in body.parts:
		if seen.has(int(part.feedback_uid)): return false
		seen[int(part.feedback_uid)] = true
	for group in body.detached_fragments:
		for part in group.parts:
			if seen.has(int(part.feedback_uid)): return false
			seen[int(part.feedback_uid)] = true
	return true

func break_segments(body, segments: Array):
	var indices: Array = []
	for segment in segments:
		var index = body.part_at(int(segment))
		body.parts[index].hp = 0.0
		indices.append(index)
	body.remove_destroyed_parts(indices)

func advance(body, seconds: float):
	for frame in ceili(seconds * 60.0): body.step(1.0 / 60.0, Vector2.ZERO, false)

func approach(body, group_index: int = 0):
	body.head = body.detached_fragments[group_index].poses[0].point
	body.refresh_positions()

func test_physical_order():
	var body = make_body(6)
	var original: Array = body.parts.slice(1)
	body.move_to_mount(6, 1)
	var expected_prefix = [original[5].feedback_uid, original[0].feedback_uid]
	var expected_tail = uids(original.slice(2, 5))
	original[2].fusion_level = 3
	body.refresh_upgrades()
	original[2].hp -= 17.0
	original[2].cooldown = 4.25
	original[2].shield = 7.0
	var saved_hp = original[2].hp
	var saved_max_hp = original[2].max_hp
	var positions: Array = original.slice(2, 5).map(func(p): return Vector2(p.position))
	break_segments(body, [3])
	check(active_uids(body) == expected_prefix and fragment_uids(body) == [expected_tail], "Severing follows physical chain order after assembly reorder, not array indices")
	check(body.detached_fragments[0].poses.map(func(p): return p.point) == positions, "Detached survivors retain their exact world positions at the break")
	original[2].test_reference_marker = 99
	var kept: Dictionary = body.detached_fragments[0].parts[0]
	check(kept.get("test_reference_marker") == 99 and kept.feedback_uid == original[2].feedback_uid and kept.fusion_level == 3 and kept.hp == saved_hp and kept.max_hp == saved_max_hp and kept.cooldown == 4.25 and kept.shield == 7.0, "Fragment holds the original dictionary, identity, damage, fusion, cooldown and shield")
	check(body.parts.size() == 3 and body.segment_count() == 2 and body.motion.centers.size() == 2 and body.body_poses.size() == 3, "Active body and solver contain only the head-connected prefix")
	check(unique_ownership(body), "No module is simultaneously active and detached")

func test_multiple_breaks():
	var body = make_body(8)
	var original: Array = body.parts.slice(1)
	break_segments(body, [7, 2, 5])
	check(active_uids(body) == [original[0].feedback_uid] and fragment_uids(body) == [uids(original.slice(2, 4)), [original[5].feedback_uid], [original[7].feedback_uid]], "Three simultaneous breaks create separate living groups in physical order")
	check(body.detached_fragments.size() == 3 and body.detached_module_count() == 4 and unique_ownership(body), "Every survivor belongs to exactly one fragment and destroyed modules are absent")
	var group_ids: Array = body.detached_fragments.map(func(group): return group.uid)
	check(group_ids[0] != group_ids[1] and group_ids[1] != group_ids[2] and group_ids[0] != group_ids[2], "Fragment groups have distinct identities")
	body.append_segment(gun)
	body.append_segment(gun)
	var later_tail = body.parts[-1].feedback_uid
	break_segments(body, [2])
	check(body.detached_fragments.size() == 4 and body.detached_fragments[-1].parts[0].feedback_uid == later_tail, "A later break preserves all earlier unrecovered groups")
	advance(body, 1.1)
	for group in body.detached_fragments:
		for pose in group.poses: pose.point = body.head + Vector2(20, 0)
	body.step(1.0 / 60, Vector2.ZERO, false)
	check(body.detached_fragments.filter(func(group): return group.state == "waking").size() == 1, "Overlapping eligible fragments start at most one recovery at a time")
	var identities: Array = []
	for group in body.detached_fragments: identities.append_array(uids(group.parts))
	var safe = true
	var continuous_joins = true
	for frame in 1200:
		if body.detached_fragments.is_empty(): break
		if not body.detached_fragments.any(func(group): return group.state == "waking"): approach(body)
		var before_count = body.parts.size()
		body.step(1.0 / 60, Vector2.ZERO, false)
		safe = safe and body.detached_fragments.filter(func(group): return group.state == "waking").size() <= 1 and unique_ownership(body)
		if body.parts.size() > before_count:
			var joined: Array = body.parts.map(func(part): return Vector2(part.position))
			body.step(1.0 / 60, Vector2.ZERO, false)
			for i in joined.size(): continuous_joins = continuous_joins and Vector2(joined[i]).distance_to(body.parts[i].position) < 13.0
	check(safe and body.detached_fragments.is_empty() and identities.all(func(uid): return uid in active_uids(body)), "Multiple groups recover serially without loss, duplicate ownership or starvation")
	check(continuous_joins, "Successive recovered groups enter normal follower motion without a next-frame snap")

func test_combat_owners():
	var body = make_body(5)
	body.move_to_mount(5, 1)
	var before: Array = body.parts.duplicate()
	var battle = Battle.new(db, body)
	var drone_data = db.asset(db.kind("MainCoreDroneReward")[0].drone)
	for owner in range(1, body.parts.size()): battle.add_drone(owner, drone_data)
	var retained_drone_uid = battle.drones[-1].uid
	var detached: Dictionary = body.parts[3]
	detached.hp -= 10.0
	var detached_drone: Dictionary = battle.drones.filter(func(d): return d.owner == 3)[0]
	var drop = {"position": detached.position, "reserved_by": detached_drone.uid, "carried": true}
	detached_drone.target = drop
	detached_drone.carrying = true
	var retained_drone: Dictionary = battle.drones.filter(func(d): return d.owner == 5)[0]
	retained_drone.target = detached
	retained_drone.mode = "repair"
	detached.repair_owner = retained_drone.uid
	battle.enemy_drones = [{"target": detached}]
	battle.special.mines = [{"owner": 3, "anchored": true}, {"owner": 5, "anchored": true}, {"owner": 4, "anchored": false}]
	battle.barrages = [{"control_source": "player:3"}, {"control_source": "player:5"}, {"control_source": "enemy:99"}]
	break_segments(body, [3])
	check(battle.drones.all(func(d): return d.owner >= 0 and d.owner < body.parts.size()) and not battle.drones.any(func(d): return d.uid == detached_drone.uid), "Detached and destroyed modules lose all owned active drones")
	var retained = battle.drones.filter(func(d): return d.uid == retained_drone_uid)
	check(retained.size() == 1 and body.parts[retained[0].owner].feedback_uid == before[5].feedback_uid, "Surviving drone owner remaps correctly when its array index shifts")
	check(not drop.has("reserved_by") and not drop.has("carried") and not detached.has("repair_owner") and retained_drone.target.is_empty(), "Removal releases loot reservations and surviving engineer targets on detached modules")
	check(battle.enemy_drones[0].target.is_empty(), "Enemy drones release detached module targets")
	check(battle.special.mines.size() == 2 and battle.special.mines[0].owner == body.parts.find(before[5]) and battle.special.mines[1].owner == -1, "Detached anchored mines disappear while surviving owners remap and free mines lose stale owners")
	check(battle.barrages.size() == 2 and battle.barrages[0].control_source == "player:" + str(body.parts.find(before[5])) and battle.barrages[1].control_source == "enemy:99", "Detached delayed volleys disappear and surviving volleys retain the correct organ")

func test_recovery_animation():
	var body = make_body(7)
	var original: Array = body.parts.slice(1)
	original[3].fusion_level = 3
	body.refresh_upgrades()
	original[3].hp -= 37.0
	original[3].cooldown = 8.0
	var hp = original[3].hp
	var maximum_hp = original[3].max_hp
	var built = body.built_count
	var score = body.built_score
	break_segments(body, [3])
	var frozen = fragment_positions(body)
	advance(body, 1.1)
	check(body.detached_fragments[0].state == "dormant" and fragment_positions(body) == frozen, "Eligible fragments remain dormant and motionless when the head is far away")
	approach(body)
	var before_zero = body.detached_fragments.duplicate(true)
	for i in 10:
		body.refresh_positions()
		body.step(0, Vector2.ZERO, false)
	check(body.detached_fragments == before_zero, "Redraws and zero-delta steps cannot wake or move fragments")
	body.step(1.0 / 60, Vector2.ZERO, false)
	check(body.detached_fragments.size() == 1 and body.detached_fragments[0].state == "waking" and body.parts.size() == 3, "Head proximity starts a visible wake-up before any module rejoins")
	var group: Dictionary = body.detached_fragments[0]
	check(group.poses[0].activation > 0 and group.poses[1].activation == 0 and group.poses[-1].activation == 0, "Wake activation begins at the fragment front and leaves later legs asleep")
	var motion_bounded = true
	var join_bounded = true
	var ordered = true
	var duplicates = false
	for frame in 1200:
		if body.detached_fragments.is_empty(): break
		var previous = fragment_positions(body)
		body.step(1.0 / 60, Vector2.ZERO, false)
		for pending_group in body.detached_fragments:
			for i in pending_group.parts.size():
				var uid = int(pending_group.parts[i].feedback_uid)
				motion_bounded = motion_bounded and Vector2(previous[uid]).distance_to(pending_group.poses[i].point) <= 12.001
				if i > 0: ordered = ordered and float(pending_group.poses[i - 1].activation) >= float(pending_group.poses[i].activation)
		for part in body.parts:
			if previous.has(int(part.feedback_uid)): join_bounded = join_bounded and Vector2(previous[int(part.feedback_uid)]).distance_to(part.position) <= 12.501
		duplicates = duplicates or not unique_ownership(body)
	check(motion_bounded and join_bounded and ordered and not duplicates and body.detached_fragments.is_empty(), "Sequential wake, movement and final attachment stay continuous and never duplicate modules")
	check(active_uids(body) == uids(original.slice(0, 2)) + uids(original.slice(3)), "Recovered groups append to the surviving tail in their original internal order")
	check(original[3].hp == hp and original[3].max_hp == maximum_hp and original[3].fusion_level == 3 and original[3].cooldown == 8.0, "Recovery preserves damage and upgrades without free healing or cooldown reset")
	check(body.built_count == built and body.built_score == score, "Recovery does not count as a newly built or newly rewarded module")
	var recovered_count = body.parts.size()
	advance(body, 3)
	check(body.parts.size() == recovered_count and unique_ownership(body), "Continuing over the recovered location cannot award the same modules again")

func test_delay_and_coil():
	var body = make_body(4)
	break_segments(body, [2])
	approach(body)
	advance(body, 0.5)
	check(body.detached_fragments[0].state == "dormant" and body.detached_fragments[0].age < 1.0, "Immediate overlap cannot bypass the one-second pickup delay")
	body.begin_coil()
	advance(body, 2)
	check(body.detached_fragments[0].state == "dormant" and body.parts.size() == 2, "Coiling blocks pickup even after the fragment is eligible and nearby")
	body.end_coil()
	advance(body, 10)
	check(body.detached_fragments.is_empty() and body.parts.size() == 4, "Recovery resumes safely after the coil exit finishes")
	body = make_body(6)
	break_segments(body, [2])
	advance(body, 1.1)
	approach(body)
	body.step(1.0 / 60, Vector2.ZERO, false)
	check(body.detached_fragments[0].state == "waking", "Mid-recovery coil fixture starts with an already waking group")
	body.begin_coil()
	var active_count = body.parts.size()
	advance(body, 2)
	check(body.parts.size() == active_count and not body.detached_fragments.is_empty(), "A new coil cannot attach a fragment already in its recovery transition")
	body.end_coil()
	advance(body, 10)
	check(body.detached_fragments.is_empty() and body.parts.size() == 6, "A paused in-progress recovery resumes after uncurling")
	body = make_body(8)
	body.begin_coil()
	advance(body, 1.5)
	var surviving: Array = body.parts.slice(4)
	break_segments(body, [3])
	var frozen = fragment_positions(body)
	advance(body, 1.1)
	check(body.detached_fragments.size() == 1 and fragment_positions(body) == frozen and body.parts.size() == 3, "Damage during a fully coiled body preserves detached world poses and pauses recovery")
	body.end_coil()
	advance(body, 1.5)
	if not body.detached_fragments.is_empty(): approach(body)
	advance(body, 10)
	check(body.detached_fragments.is_empty() and surviving.all(func(part): return part in body.parts) and unique_ownership(body), "Fragments severed during coiling recover safely after the coil solver releases")

func test_upgrades_and_moving_recovery():
	var body = make_body(5)
	var damaged: Dictionary = body.parts[4]
	damaged.fusion_level = 2
	damaged.wall = true
	body.refresh_upgrades()
	damaged.hp -= 23.0
	break_segments(body, [2])
	var old_hp = float(damaged.hp)
	var old_max = float(damaged.max_hp)
	body.stats["16"] = 0.35
	body.refresh_upgrades()
	var gain = float(db.asset(damaged.id).CoreHealth) * 0.35 * 1.6
	check(is_equal_approx(float(damaged.max_hp), old_max + gain) and is_equal_approx(float(damaged.hp), old_hp + gain), "Genuine health upgrades reach sleeping fused and reinforced modules exactly once")
	var upgraded_hp = float(damaged.hp)
	for i in 10: body.refresh_upgrades()
	approach(body)
	advance(body, 10)
	check(is_equal_approx(float(damaged.hp), upgraded_hp) and is_equal_approx(float(damaged.max_hp) - float(damaged.hp), 23.0), "Repeated refresh and pickup preserve the post-upgrade damage amount")
	for fps in [30, 60, 120]:
		for count in [2, 12, 60]:
			body = make_body(count)
			break_segments(body, [1 if count == 2 else 2])
			advance(body, 1.1)
			approach(body)
			var bounded = true
			var unique = true
			var last_frame = 0
			for frame in fps * 20:
				if body.detached_fragments.is_empty(): break
				last_frame = frame
				var positions = fragment_positions(body)
				body.step(1.0 / fps, Vector2.from_angle(float(frame) / fps * 0.8), true)
				for group in body.detached_fragments:
					for i in group.parts.size():
						var uid = int(group.parts[i].feedback_uid)
						bounded = bounded and Vector2(positions[uid]).distance_to(group.poses[i].point) <= 720.0 / fps + 0.001
				for part in body.parts:
					if positions.has(int(part.feedback_uid)):
						bounded = bounded and Vector2(positions[int(part.feedback_uid)]).distance_to(part.position) <= 720.0 / fps + 0.501
				unique = unique and unique_ownership(body)
			var normal_motion_stable = true
			if body.detached_fragments.is_empty():
				for frame in fps * 2:
					var positions: Array = body.parts.map(func(part): return Vector2(part.position))
					body.step(1.0 / fps, Vector2.from_angle(float(last_frame + frame + 1) / fps * 0.8), true)
					for i in body.parts.size():
						normal_motion_stable = normal_motion_stable and Vector2(positions[i]).distance_to(body.parts[i].position) <= 720.0 / fps + 0.501 and Vector2(body.parts[i].position).is_finite()
					for segment in range(1, body.segment_count() + 1):
						normal_motion_stable = normal_motion_stable and absf(Vector2(body.segment_pose(segment).point).distance_to(body.segment_pose(segment - 1).point) - body.body_spacing) < 0.01
			if not (bounded and unique and body.detached_fragments.is_empty() and body.parts.size() == count):
				print("MOVING_RECOVERY_DIAGNOSTIC=", JSON.stringify({"count": count, "fps": fps, "bounded": bounded, "unique": unique, "active": body.parts.size() - 1, "remaining_groups": body.detached_fragments.size(), "wake_age": body.detached_fragments[0].wake_age if not body.detached_fragments.is_empty() else 0}))
			check(bounded and unique and body.detached_fragments.is_empty() and body.parts.size() == count, "%d-module chain recovers smoothly while steering and boosting at %d FPS" % [count, fps])
			check(normal_motion_stable, "%d-module recovered chain stays continuous and exactly linked during subsequent normal motion at %d FPS" % [count, fps])

func test_inactive_and_edges():
	var body = make_body(4)
	var battle = Battle.new(db, body)
	var tail: Dictionary = body.parts[3]
	tail.cooldown = 100.0
	tail.hp -= 20.0
	var hp = tail.hp
	battle.hurt_player(body.part_at(2), 100000, 100000)
	battle.step(0.01, Vector2.RIGHT * 600, false, false)
	check(body.parts.size() == 2 and body.detached_fragments.size() == 1, "Actual combat death cleanup severs the living tail")
	var cooldown = tail.cooldown
	for i in 40: battle.step(0.05, Vector2.RIGHT * 600, false, false)
	check(tail.hp == hp and tail.cooldown == cooldown and body.detached_fragments[0].age == 0, "Combat alone cannot tick, heal, fire or recover inactive fragment modules")
	body = make_body(3)
	break_segments(body, [3])
	check(body.parts.size() == 3 and body.detached_fragments.is_empty(), "Destroying the last segment only removes that segment")
	body = make_body(3)
	break_segments(body, [1])
	check(body.parts.size() == 1 and body.detached_module_count() == 2 and body.parts[0].hp > 0, "Destroying the first body segment leaves a living head and recoverable tail")
	body.remove_destroyed_parts([0, -1, 1000])
	check(body.parts.size() == 1 and body.detached_module_count() == 2, "Invalid and head indices cannot remove the head or duplicate existing fragments")
	approach(body)
	body.parts[0].hp = 0.0
	advance(body, 2)
	check(body.detached_fragments[0].state == "dormant" and body.parts.size() == 1, "A dead head cannot trigger recovery")
	body.reset()
	check(body.parts.size() == 1 and body.detached_fragments.is_empty() and body.detached_module_count() == 0, "Reset removes all fragments and wake state")
	body = make_body(4)
	var remaining: Array = body.parts.slice(2)
	check(body.merge_parts(1, 2) and body.detached_fragments.is_empty() and active_uids(body) == uids(remaining), "Fusion keeps ordinary compaction behavior and never creates salvage")
	body = make_body(0)
	body.configure_character("spider")
	for depth in 3: body.install_module(gun, body.spider_mount(0, depth))
	body.install_module(gun, body.spider_mount(1, 0))
	var spider_tip: Dictionary = body.parts[3]
	battle = Battle.new(db, body)
	battle.hurt_player(body.part_at(9), 100000, 100000)
	battle.step(0.01, Vector2.RIGHT * 600, false, false)
	check(body.detached_fragments.is_empty() and body.parts.size() == 4 and body.parts.has(spider_tip) and spider_tip.segment == 9 and body.spider_leg_count(1) == 1, "Spider damage retains its existing same-leg compaction and never spawns centipede fragments")

func test_mixed_phase_deaths():
	for with_pack in [false, true]:
		var body = make_body(6)
		var second_core: Dictionary = db.kind("PackCore")[0] if with_pack else db.asset(gun)
		body.parts[5] = body.make_part(second_core.id, body.mount_cell(5))
		body.parts[5].segment = 5
		body.parts[5].slot = 4
		body.refresh_positions()
		var original: Array = body.parts.slice(1)
		var battle = Battle.new(db, body)
		battle.drones.clear()
		# One death predates special.step(); another is caused by a real hostile
		# projectile later inside the same Battle.step(), before final cleanup.
		battle.hurt_player(2, 100000, 100000)
		battle.fire(db.asset(gun), body.parts[5].position, Vector2.RIGHT, false, {}, 100000)
		for projectile in battle.bullets:
			projectile.position = body.parts[5].position
			projectile.previous = projectile.position
			projectile.velocity = Vector2.ZERO
		battle.step(0.01, Vector2.RIGHT * 600, false, false)
		var expected_scraps = int(db.asset(gun).get("coreScraps", 0)) + int(second_core.get("coreScraps", 0))
		var scrap_total = battle.loot.reduce(func(total, drop): return total + int(drop.get("value", 0)), 0)
		var pack_count = battle.loot.filter(func(drop): return drop.pack).size()
		var expected_packs = (pack_count >= int(second_core.minPacksCount) and pack_count <= int(second_core.maxPacksCount)) if with_pack else pack_count == 0
		check(body.parts.size() == 2 and fragment_uids(body) == [uids(original.slice(2, 4)), [original[5].feedback_uid]], "Mixed-phase simultaneous deaths preserve both surviving groups (%s)" % ("pack" if with_pack else "gun"))
		check(original[1].get("destroy_processed", false) and original[4].get("destroy_processed", false) and scrap_total == expected_scraps and expected_packs, "Every destroyed module awards its source scraps and packs exactly once before severing (%s)" % ("pack" if with_pack else "gun"))
		check(battle.effects.filter(func(effect): return effect.kind == "segment_break").size() == 2, "Mixed early and projectile deaths produce one break snapshot each (%s)" % ("pack" if with_pack else "gun"))
		for frame in 5: battle.step(0.01, Vector2.RIGHT * 600, false, false)
		check(battle.loot.reduce(func(total, drop): return total + int(drop.get("value", 0)), 0) == scrap_total and battle.loot.filter(func(drop): return drop.pack).size() == pack_count and battle.effects.filter(func(effect): return effect.kind == "segment_break").size() == 2, "Following cleanup frames cannot duplicate destruction rewards or feedback (%s)" % ("pack" if with_pack else "gun"))

func test_capacity():
	var body = make_body(60)
	break_segments(body, [1])
	check(body.detached_module_count() == 59 and body.append_segment(gun) and not body.append_segment(gun), "Detached modules reserve capacity while only the destroyed slot can be replaced")
	var save = Save.new(db, "user://fragment-capacity.json", false)
	var battle = Battle.new(db, body)
	var run = Run.new(db, save, body, battle, db.named("Endless Mission"), 0)
	var block: Dictionary = db.kind("BlockReward")[0]
	if not save.available(block.id): save.state.unlocked.append(block.id)
	check(not run.can_reward(block), "Rewards respect detached reservations instead of creating unplaceable excess modules")
	body.actions.duplicate = 1
	check(not body.duplicate_to_mount(1, 2) and body.actions.duplicate == 1, "Duplication cannot exceed total active plus detached module capacity")
	approach(body)
	advance(body, 20)
	check(body.detached_fragments.is_empty() and body.parts.size() == 61 and unique_ownership(body), "A full-capacity recovered chain retains every surviving identity without exceeding 60 modules")

func test_scene_lifecycle():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.save.state.settings.skip_boss = true
	game.start_run()
	game.combat.enemies.clear()
	for i in 4: game.player.append_segment(gun)
	break_segments(game.player, [2])
	var snapshot: Array = game.player.detached_fragments.duplicate(true)
	game.show_pause()
	for i in 5: game._process(0.1)
	check(game.player.detached_fragments == snapshot, "Real pause screen freezes fragment age, wake state and positions")
	game.show_build_ui()
	for i in 5: game._process(0.1)
	check(game.player.detached_fragments == snapshot, "Real assembly screen cannot advance fragment recovery")
	game.run.packs = 1
	game.show_rewards()
	for i in 5: game._process(0.1)
	check(game.player.detached_fragments == snapshot, "Real reward-choice screen cannot advance fragment recovery")
	game.run.packs = 0
	game.show_game()
	game._process(0.1)
	check(game.player.detached_fragments[0].age > float(snapshot[0].age), "Returning to normal gameplay resumes fragment age")
	game.run.finish(false)
	game.show_result()
	snapshot = game.player.detached_fragments.duplicate(true)
	for i in 5: game._process(0.1)
	check(game.player.detached_fragments == snapshot, "Run results freeze remaining fragments")
	var persisted = JSON.parse_string(FileAccess.get_file_as_string(game.save.path))
	check(persisted is Dictionary and not persisted.has("detached_fragments") and not persisted.has("fragment_recovery"), "Encounter-only fragment state is not serialized into persistent profile saves")
	game.show_menu()
	game.start_run()
	check(game.player.parts.size() == 1 and game.player.detached_fragments.is_empty(), "Leaving and starting a new run never carries salvage into another encounter")
	game.cursor_system.shutdown()
	game.audio_system.shutdown()
	game.particle_effects.clear()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 12:
		OS.delay_msec(10)
		await process_frame
	game.queue_free()
	await process_frame
	await process_frame

func execute():
	db = DB.new()
	gun = str(db.named("Core_Gun_Gatling").id)
	test_physical_order()
	test_multiple_breaks()
	test_combat_owners()
	test_recovery_animation()
	test_delay_and_coil()
	test_upgrades_and_moving_recovery()
	test_inactive_and_edges()
	test_mixed_phase_deaths()
	test_capacity()
	await test_scene_lifecycle()
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks}
	FileAccess.open("res://artifacts/fragment-recovery-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
