extends "res://tests/test_centipede_scene.gd"
const Roster=preload("res://scripts/character_roster.gd")

func settle():
	for i in range(4):await process_frame

func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.save.path="user://debug-unlock-all.json";game.save.fresh()
	game.save.state.disabled=[game.save.state.unlocked[0]]
	game.show_menu();await settle()
	var before=game.save.state.duplicate(true)
	check(game.debug_unlock_button.is_visible_in_tree() and game.debug_unlock_button.text.contains("一键全开"),"Home exposes the requested unlock-all button")
	await click_at(game.debug_unlock_button.get_global_rect().get_center());await settle()
	check(Roster.ids().all(func(id):return game.save.character_unlocked(id)),"One real click unlocks every playable character")
	var all_rewards=game.db.catalog.values().filter(func(r):return str(r.get("class","")).ends_with("Reward"))
	check(not all_rewards.is_empty() and all_rewards.all(func(r):return game.save.available(r.id)),"Every skill and reward definition is unlocked and enabled")
	check(game.db.research.all(func(node):return node.nodeRewardsList.all(func(id):return game.save.available(id))),"Every tier of every evolution branch is available")
	check(game.db.stores.MissionDataStore.missionsList.all(func(id):return id in game.save.state.missions) and game.save.state.systems.get("ToggleResearches",false),"One-click full access includes missions and reward-pool controls")
	var preserved=true
	for field in ["meta","settings","scores","statistics","achievements","tutorials","blueprint","selected_character","roster_progress"]:
		preserved=preserved and game.save.state[field]==before[field]
	check(preserved and game.home_points_label.text==str(before.meta),"Unlocking preserves currency, selected character and unrelated progress")
	check(game.debug_unlock_button.text.contains("已全部解锁"),"Successful click immediately confirms full unlock")
	var loaded=load("res://scripts/save_store.gd").new(game.db,game.save.path)
	check(loaded.state.unlocked==game.save.state.unlocked and loaded.state.roster_unlocked==game.save.state.roster_unlocked and loaded.state.disabled==game.save.state.disabled,"Full unlock persists through a fresh save-store load")
	var unlocked=game.save.state.duplicate(true)
	await click_at(game.debug_unlock_button.get_global_rect().get_center());await settle()
	check(game.save.state==unlocked,"Repeated clicks are safe and do not duplicate unlocks")
	game.show_characters();await settle()
	var nest=game.panel.get_child(0)
	await click_at(nest.cards.spider.get_global_rect().get_center());await settle()
	check(game.save.state.selected_character=="spider","A newly unlocked character can immediately be selected")
	unlocked=game.save.state.duplicate(true);game.debug_unlock_all_content()
	check(game.save.state==unlocked,"A stale callback outside home cannot change the profile")
	# Verify atomic rollback from an actually locked profile on write failure.
	game.save.fresh();game.show_menu();await settle()
	var locked=game.save.state.duplicate(true)
	var valid_path=game.save.path;game.save.path="user://missing-directory/unlocks.json"
	game.debug_unlock_all_content()
	check(game.save.state==locked and game.debug_unlock_button.text.contains("保存失败"),"A failed save keeps all content locked and displays a retry message")
	game.save.path=valid_path
	game.show_menu();await settle()
	for resolution in [Vector2i(1440,900),Vector2i(1280,720)]:
		root.size=resolution;await settle()
		var button=game.debug_unlock_button
		var physical_rect=root.get_final_transform()*button.get_global_rect()
		check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(physical_rect),"Unlock-all button stays visible at "+str(resolution))
		await capture("debug-unlock-all-home-"+str(resolution.x))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures}
	FileAccess.open("res://artifacts/debug-unlock-all-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
