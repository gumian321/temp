extends "res://tests/test_centipede_scene.gd"
const Branches=preload("res://scripts/mutation_branches.gd")
const UI=preload("res://scripts/game_ui.gd")
func settle():
	for i in 4:await process_frame
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.performance_overlay.visible=false
	game.save.path="user://mutation-branches-scene.json";game.save.fresh();game.save.state.meta=10000;game.save.unlock_all_content()
	game.show_lab();await settle()
	var lab=game.panel.get_child(0)
	for section in ["sustain","summon"]:
		await click_at(lab.section_buttons[section].get_global_rect().get_center());await settle()
		for branch in Branches.DEFINITIONS:
			var info=Branches.DEFINITIONS[branch]
			if lab.node_sections[info.node]!=section:continue
			var child=lab.node_buttons[info.node];var parent=lab.node_buttons[str(info.parent)]
			check(lab.world.get_global_rect().encloses(child.get_global_rect()),"Section navigation shows the complete branch node: "+branch)
			check(child.position.y>parent.position.y and child.size==lab.NODE_SIZE,"Branch child has a stable hit box below its parent: "+branch)
			check(visible_text(child).contains("1") and visible_text(child).contains("/ 1"),"Research progress remains visible on the branch node: "+branch)
		await capture("branches-evolution-"+section)
	await click_at(lab.node_buttons["60302"].get_global_rect().get_center());await settle()
	check(visible_text(lab.detail).contains("猎杀强虫") and visible_text(lab.detail).contains("本局不再出现"),"Branch detail identifies its effect and the opposing path")
	check(lab.detail.get_node("EvolutionArt").size==Vector2(340,340),"Generated branch art fits the evolution detail panel")
	check(lab.detail.get_node("BranchRules").size.x<=550 and lab.detail.get_node("BranchRules").get_line_count()>1,"Branch commitment rules wrap inside their dialog column")
	await capture("branches-hunter-detail")
	lab.dismiss_detail();lab.fit_tree();await settle();await capture("branches-evolution-overview")
	var branch_rolls:Dictionary={}
	for branch in Branches.DEFINITIONS:
		game.start_run();await settle()
		game.player.terrain=null;game.combat.terrain=null;game.charcoal_terrain.world.enabled=false;game.cave_terrain.hide()
		game.combat.enemies.clear();game.combat.drones.clear();game.combat.effects.clear()
		game.player.parts[0].stun=1000
		var weapon=str(Branches.DEFINITIONS[branch].weapon);var core=game.db.asset("expanded_"+weapon+"_core")
		game.player.add_piece(core.id,game.player.next_segment_cell());game.player.levels["expanded_"+weapon+"_upgrade"]=1;game.player.refresh_upgrades()
		game.run.rng.seed=2400+int(Branches.DEFINITIONS[branch].node)
		var reward=game.db.asset(Branches.reward_id(branch));var found=false
		# A disclosed upgrade-pack fixture uses the real dealer and eligibility rules.
		# No synthetic offer arrays or mutations of weapon data.
		for attempt in 24:
			game.run.rewards.queue=[{"id":game.db.named("Level Up Reward Pack").id,"rarity":2}];game.run.packs=1
			var hand=game.run.roll_rewards()
			if reward in hand:found=true;branch_rolls[branch]=attempt+1;break
			game.run.rewards.recycle()
		check(found,"Real upgrade pack dealer offers the eligible branch: "+branch)
		if not found:continue
		game.show_rewards();await settle()
		var choice=game.run.offers.find(reward)
		check(game.reward_ui.progress_labels[choice].text.contains("二选一"),"Reward badge states the irreversible run choice: "+branch)
		check(game.reward_ui.buttons[choice].tooltip_text.contains("本局不再出现"),"Card tooltip names the opposing path: "+branch)
		check(game.reward_ui.faces[choice].get_rect().size.y<=game.reward_ui.buttons[choice].size.y,"Branch description stays inside the reward card: "+branch)
		if branch=="toxin_spread":await capture("branches-reward-card")
		if branch=="parasite_hunter":
			root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720);await settle()
			check(root.get_visible_rect().encloses(game.reward_ui.board.get_global_rect()),"Branch rewards fit a 1280 by 720 window")
			await capture("branches-reward-1280x720")
		await click_at(game.reward_ui.buttons[choice].get_global_rect().get_center());await settle()
		check(Branches.selected(game.player,weapon)==branch and game.screen=="game","Clicking the branch applies it and returns to battle: "+branch)
		check(not game.run.can_reward(reward),"The chosen one-time branch leaves the reward pool: "+branch)
		root.size=Vector2i(1440,900);await settle()
		check(Branches.core_texture(game.player,core)==game.db.reward_sprite(reward),"Mounted weapon uses its evolved organ appearance: "+branch)
		game.camera=Vector2(100,0);game.zoom=1.6
		for at in [Vector2(270,-90),Vector2(290,0),Vector2(270,90)]:
			var enemy=game.combat.spawn(game.db.pool["250"],at);enemy.hp=5000;enemy.max_hp=5000;enemy.guns=[];enemy.stun=1000;enemy.mission_controlled=true
		var caption=UI.label(game.panel,game.db.title(reward),Vector2(360,130),30,UI.TEXT)
		var subtitle=UI.label(game.panel,"",Vector2(360,174),18,UI.MUTED);subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;subtitle.clip_text=true;subtitle.text=game.db.text(reward.rewardDesc);subtitle.size=Vector2(750,80)
		UI.label(game.panel,"演示：真实器官自动攻击 / 静止高血量目标",Vector2(360,760),16,UI.MUTED)
		for tick in 180:
			game.combat.step(1.0/60,Vector2(290,0),false);game.test_time+=1.0/60;game.run.elapsed+=1.0/60
			if tick==105:await capture("branches-combat-"+branch)
		check(game.combat.enemies.any(func(enemy):return enemy.hp<5000),"Evolved mounted organ deals actual combat damage: "+branch)
		if branch=="parasite_hunter":
			game.show_build_ui();await settle();await capture("branches-hunter-assembly")
			check(visible_text(game.panel).contains("身体拼接"),"Evolved art also renders in the body editor")
		caption=null
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures,"branch_rolls":branch_rolls,"fixture":"All research unlocked. One mounted weapon with one base upgrade. Actual upgrade-pack dealer and mouse selection; real automatic combat against stationary high-health targets. Not a balance or frame-rate benchmark."}
	FileAccess.open("res://artifacts/mutation-branches-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
