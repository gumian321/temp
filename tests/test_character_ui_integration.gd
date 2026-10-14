extends SceneTree
var checks: Array = []
func check(ok: bool, title: String):
	checks.append({"name": title, "passed": ok})
	if not ok: printerr("FAIL: ", title)
func _initialize(): call_deferred("execute")
func execute():
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.set_process(false)
	game.save.state.settings.skip_boss = true
	game.save.state.roster_unlocked = ["centipede", "spider", "beetle"]
	for id in ["spider", "beetle"]:
		game.save.select_character(id); game.start_run(); game.set_process(false)
		game.show_build_ui(); await process_frame
		var cap = game.player.module_cap()
		check((game.build_ui.segment_buttons.is_empty() and game.build_ui.insert_targets.size() == 8) if id == "spider" else (game.build_ui.segment_buttons.size() == cap and game.build_ui.insert_targets.is_empty()), id + ": armory distinguishes growing legs from fixed beetle hardpoints")
		var reward: Dictionary = {}
		for r in game.db.kind("BlockReward"):
			if game.save.available(r.id): reward = r; break
		game.player.pending = [reward.blockCore]; game.build_ui.rebuild()
		var data = {"kind": "inventory", "index": 0, "id": reward.blockCore}
		var first_mount = 8 if id == "spider" else cap
		check(game.build_ui.can_drop({"kind": "mount", "before": first_mount}, data), id + ": UI permits placement into an empty leg root or hardpoint")
		game.build_ui.drop({"kind": "mount", "before": first_mount}, data); await process_frame
		check(game.player.pending.is_empty() and game.player.part_at(first_mount) > 0 and game.player.parts.size() == 2, id + ": UI placement consumes exactly one pending module")
		while game.player.parts.size() - 1 < cap: game.player.append_segment(reward.blockCore)
		game.player.pending = [reward.blockCore]; game.build_ui.rebuild()
		var uid = game.player.parts[game.player.part_at(cap)].feedback_uid
		game.build_ui.drop({"kind": "mount", "before": cap}, data); await process_frame
		if id == "spider":
			check(game.player.pending.size() == 1 and game.player.parts.size() == cap + 1 and game.player.parts[game.player.part_at(cap)].feedback_uid == uid, "Full spider leg rejects accidental replacement and preserves inventory")
		else:
			check(game.player.pending.is_empty() and game.player.parts.size() == cap + 1 and game.player.parts[game.player.part_at(cap)].feedback_uid != uid, id + ": UI full-body replacement changes one module without growing or duplicating inventory")
		var key = InputEventKey.new(); key.physical_keycode = KEY_SPACE; key.keycode = KEY_SPACE; key.pressed = true
		game.show_pause(); game._unhandled_input(key)
		check(game.combat.character_abilities.cooldown == 0, id + ": paused Space cannot activate a skill")
		game.show_build_ui(); game._unhandled_input(key)
		check(game.combat.character_abilities.cooldown == 0, id + ": armory Space cannot activate a skill")
		game.controls.bind("character_skill", KEY_F)
		game.show_game(); game._unhandled_input(key)
		check(game.combat.character_abilities.cooldown == 0, id + ": rebinding skill removes old Space activation")
		key.physical_keycode = KEY_F; key.keycode = KEY_F
		game._unhandled_input(key)
		check(game.combat.character_abilities.cooldown > 0, id + ": remapped skill fires only in live gameplay")
		game.controls.bind("character_skill", KEY_SPACE)
	game.save.fresh(); game.save.state.settings.skip_boss = true; game.start_run(); game.set_process(false)
	var support: Dictionary = {}
	for r in game.db.kind("BlockReward"):
		if preload("res://scripts/character_roster.gd").is_support(game.db, r.blockCore): support = r; break
	game.save.state.unlocked.append(support.id)
	for i in 3:
		game.run.rewards.enqueue(true); game.run.offers = [support]; game.show_rewards()
		var epoch = game.reward_epoch
		game.choose_reward(support, epoch); game.choose_reward(support, epoch); await process_frame
		check(game.save.character_run_support_count() == i + 1 and game.player.pending.size() == 1, "Reward UI double-click grants support exactly once: " + str(i + 1))
		game.build_ui.drop({"kind": "gap", "before": i + 1}, {"kind": "inventory", "index": 0, "id": support.blockCore}); await process_frame
		check(game.save.character_run_support_count() == i + 1 and game.player.pending.is_empty(), "Installing support cannot farm unlock progress: " + str(i + 1))
	check(game.save.character_unlocked("spider"), "Three legitimate UI support rewards unlock spider")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.process_mode = Node.PROCESS_MODE_DISABLED
	game.queue_free(); await process_frame; await process_frame
	var report = {"checks": checks, "passed": checks.all(func(c): return c.passed)}
	FileAccess.open("res://artifacts/character-ui-integration-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
