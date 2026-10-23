extends "res://tests/test_centipede_scene.gd"
func settle():
	for i in 4:await process_frame
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.performance_overlay.visible=false
	game.save.path="user://reward-pacing-scene.json";game.save.fresh();game.start_run();await settle()
	game.run.rng.seed=30200
	var hands:Array=[]
	for round_index in 4:
		game.run.rewards.enqueue(true);game.show_rewards();await settle()
		var offers=game.run.offers.duplicate()
		check(game.screen=="rewards" and offers.size()==3 and game.reward_ui.buttons.all(func(button):return not button.disabled),"Real reward modal presents three selectable cards: round %d"%round_index)
		check(game.reward_ui.board.get_global_rect().encloses(game.reward_ui.buttons[2].get_global_rect()),"Actual paced cards fit the reward panel: round %d"%round_index)
		hands.append(offers.map(func(reward):return {"id":reward.id,"title":game.db.title(reward)}))
		await capture("reward-pacing-opening-%d"%(round_index+1))
		if round_index==0:
			var state=game.run.rng.state;var history=game.run.rewards.pacing.history.duplicate(true)
			game.postpone_rewards();await settle();game.show_rewards();await settle()
			check(game.run.offers==offers and game.run.rng.state==state and game.run.rewards.pacing.history==history,"Postpone and reopen in the main scene retains the cards and their history")
		var owned:Array=[]
		for i in game.player.parts.size():owned.append(game.db.armament_variant(game.player.effective_core(i)))
		var selected=0
		for i in offers.size():
			if offers[i].get("class")=="BlockReward" and game.db.asset(offers[i].blockCore).has("coreProjectile") and game.db.armament_variant(offers[i]) not in owned:selected=i;break
		await click_at(game.reward_ui.buttons[selected].get_global_rect().get_center());await settle()
		check(game.run.opened==round_index+1 and game.run.packs==0,"Actual card click consumes one earned pack: round %d"%round_index)
		if game.screen=="build":
			while not game.player.pending.is_empty():await click_at(game.build_ui.tail_target.get_global_rect().get_center());await settle()
			await click_at(game.build_ui.return_button.get_global_rect().get_center());await settle()
		check(game.screen=="game" and game.player.pending.is_empty(),"Selection and installation return to combat normally: round %d"%round_index)
	# Reopen at a second real resolution, using the next genuine hand.
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720);await settle()
	game.run.rewards.enqueue(true);game.show_rewards();await settle()
	check(root.get_visible_rect().encloses(game.reward_ui.board.get_global_rect()),"Mixed choices remain inside a 1280x720 viewport")
	await capture("reward-pacing-1280x720")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	var report={"passed":checks.all(func(item):return item.passed),"checks":checks,"captures":captures,"hands":hands,"fixture":"Fresh profile; four actual sequential earned packs, mouse selection and legal body installation. No replacement offer arrays."}
	FileAccess.open("res://artifacts/reward-pacing-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
