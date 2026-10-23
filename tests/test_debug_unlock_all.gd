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
	var all_rewards=game.db.catalog.values().filter(func(r):return str(r.get("class","")).ends_with("Reward") and not r.get("retired",false))
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
	game.debug_reset_skill_progress()
	check(game.save.state==unlocked,"A stale reset callback outside home cannot change the profile")
	game.show_menu();await settle()
	game.save.state.meta=321
	game.save.state.disabled=[game.save.state.unlocked[0]]
	game.save.state.systems["UnrelatedSystem"]=true
	game.save.state.scores["debug-reset"]=900
	game.save.state.statistics["stat_BossesKilled"]=2
	game.save.state.roster_progress.boss_kills=2
	game.save.state.tutorials["debug-reset"]=true
	game.save.state.achievements.append("ACH_LAB_FULL")
	var before_reset=game.save.state.duplicate(true)
	check(game.debug_reset_skills_button.is_visible_in_tree() and game.debug_reset_skills_button.text.contains("恢复初始技能"),"Home exposes the requested initial-skills reset button")
	await click_at(game.debug_reset_skills_button.get_global_rect().get_center());await settle()
	check(game.save.state.unlocked==game.db.stores.RewardDataStore.rewardsUnlockedList,"One real click restores exactly the original new-profile skill pool")
	check(game.save.state.disabled.is_empty() and not game.save.state.systems.has("ToggleResearches") and game.save.state.systems.get("UnrelatedSystem",false),"Reset restores initial reward filtering and preserves unrelated systems")
	check(game.save.state.meta==10000 and game.home_points_label.text=="10000","Reset grants 10,000 research points and immediately updates the home balance")
	preserved=true
	for field in ["roster_unlocked","selected_character","roster_progress","missions","settings","scores","statistics","achievements","tutorials","blueprint"]:
		preserved=preserved and game.save.state[field]==before_reset[field]
	check(preserved,"Skill reset preserves characters, selected Spider, missions, settings and records")
	check(game.debug_reset_skills_button.text.contains("已恢复初始技能") and game.debug_unlock_button.text.contains("一键全开"),"Reset confirms success and clears the previous all-unlocked message")
	loaded=load("res://scripts/save_store.gd").new(game.db,game.save.path)
	# JSON stores numbers as floats; compare persisted values with matching types.
	check(JSON.parse_string(JSON.stringify(loaded.state))==JSON.parse_string(JSON.stringify(game.save.state)),"Initial skills, research points and preserved progress survive reload")
	await capture("debug-reset-skills-home")
	var reset_state=game.save.state.duplicate(true)
	await click_at(game.debug_reset_skills_button.get_global_rect().get_center());await settle()
	check(game.save.state==reset_state,"Repeated resets do not stack currency or change unrelated progress")
	game.save.state.meta=20000
	game.debug_reset_skill_progress()
	check(game.save.state.meta==20000 and game.home_points_label.text=="20000","Reset preserves a balance already above the debug allowance")
	game.show_lab();await settle()
	var lab=game.panel.get_child(0)
	check(lab.points.text=="20000 RP","Evolution screen immediately shows the funded initial profile")
	await capture("debug-reset-skills-evolution")
	var research_node:Dictionary={}
	for node in game.db.research:
		if node.nodeRewardsList[0] in game.save.state.unlocked:continue
		var parent_id=str(int(node.get("previousUpgradeTreeNode",{}).get("fileID",0)))
		var parents=game.db.research.filter(func(candidate):return candidate.id==parent_id)
		if parents.is_empty() or parents[0].nodeRewardsList[0] in game.save.state.unlocked:
			research_node=node;break
	check(not research_node.is_empty(),"Initial profile has an available first evolution")
	if not research_node.is_empty():
		var price=game.save.research_price(research_node,0)
		check(game.save.unlock_research(research_node,0) and game.save.state.meta==20000-price,"Evolution can be purchased again from the start at its normal price")
	game.show_menu();await settle()
	var before_failed_reset=game.save.state.duplicate(true)
	var reset_path=game.save.path;game.save.path="user://missing-directory/reset-skills.json"
	game.debug_reset_skill_progress()
	check(game.save.state==before_failed_reset and game.debug_reset_skills_button.text.contains("保存失败"),"A failed reset save rolls back skills and currency and displays a retry message")
	game.save.path=reset_path
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
		for button in [game.debug_unlock_button,game.debug_reset_skills_button]:
			var physical_rect=root.get_final_transform()*button.get_global_rect()
			check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(physical_rect),button.name+" stays visible at "+str(resolution))
		check(not game.debug_unlock_button.get_global_rect().intersects(game.debug_reset_skills_button.get_global_rect()) and game.debug_reset_skills_button.get_global_rect().end.y<=game.home_points_label.get_global_rect().position.y,"Both debug actions fit above the balance without overlap at "+str(resolution))
		await capture("debug-unlock-all-home-"+str(resolution.x))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures}
	FileAccess.open("res://artifacts/debug-unlock-all-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
