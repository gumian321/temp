extends "res://tests/test_centipede_scene.gd"
func settle():
	for i in 4:await process_frame
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.path="user://mutation-scene.json";game.save.fresh()
	# Batched simulation and PNG readback are not a real-time FPS benchmark.
	game.performance_overlay.visible=false
	game.save.state.meta=10000;game.save.unlock_all_content()
	game.show_lab();await settle()
	var lab=game.panel.get_child(0)
	check(lab.node_buttons.size()==game.db.research.size(),"Every existing and new evolution appears in the sectioned map")
	check(lab.node_buttons.values().all(func(button):return button.size==lab.NODE_SIZE),"High-resolution organ icons cannot enlarge evolution node hit areas")
	check(lab.node_sections["60001"]=="sustain" and lab.node_sections["60002"]=="sustain" and lab.node_sections["60003"]=="summon","New weapons occupy their intended evolution sections")
	lab.fit_tree();await settle();await capture("new-weapons-evolution-overview")
	for section in ["sustain","summon","support"]:
		await click_at(lab.section_buttons[section].get_global_rect().get_center());await settle()
		check(is_equal_approx(lab.magnification,.9),"Real section click restores readable zoom: "+section)
		await capture("new-weapons-evolution-"+section)
	await click_at(lab.section_buttons.sustain.get_global_rect().get_center());await settle()
	var toxin_button=lab.node_buttons["60001"]
	await click_at(toxin_button.get_global_rect().get_center());await settle()
	check(is_instance_valid(lab.detail) and visible_text(lab.detail).contains("毒囊"),"Clicking a new evolution opens its real artwork and localized description")
	check(lab.detail.get_node("EvolutionArt").size==Vector2(340,340),"High-resolution evolution artwork fits its reserved preview area")
	check(lab.detail.get_node("EvolutionDescription").size.x<=550 and lab.detail.get_node("EvolutionDescription").get_line_count()>1,"New weapon descriptions wrap within the dialog text column")
	await capture("new-weapons-toxin-detail")
	lab.dismiss_detail();game.start_run();await settle()
	# Disclosed render fixture: three mounted organs and stationary high-health targets.
	# Real combat, shaders, generated artwork and main scene rendering remain active.
	game.player.terrain=null;game.combat.terrain=null
	game.charcoal_terrain.world.enabled=false;game.cave_terrain.hide()
	game.combat.enemies.clear();game.combat.drones.clear();game.combat.effects.clear()
	game.player.parts[0].stun=1000
	for key in ["toxin","boneblade","parasite"]:
		var core=game.db.asset("expanded_"+key+"_core")
		check(game.player.add_piece(core.id,game.player.next_segment_cell()),"New organ installs in the normal body chain: "+key)
	game.camera=Vector2(75,0);game.zoom=1.3
	for at in [Vector2(220,-60),Vector2(280,85),Vector2(390,-10)]:
		var enemy=game.combat.spawn(game.db.pool["250"],at)
		enemy.hp=5000;enemy.max_hp=5000;enemy.guns=[];enemy.stun=1000;enemy.mission_controlled=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/new-weapons-frames"))
	var frame_index=0
	for tick in 240:
		game.combat.step(1.0/60,Vector2(260,0),false)
		game.test_time+=1.0/60;game.run.elapsed+=1.0/60
		if tick%8==0:
			game._process(0);game.queue_redraw();await process_frame;await process_frame
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				var path="res://artifacts/new-weapons-frames/frame-%04d.png"%frame_index
				root.get_texture().get_image().save_png(path)
			frame_index+=1
	check(not game.combat.mutation_weapons.pools.is_empty(),"Normally mounted toxin organs create real toxic ground in combat")
	check(not game.combat.mutation_weapons.larvae.is_empty(),"Normally mounted brood organs create live temporary larvae")
	check(game.combat.enemies.any(func(enemy):return enemy.hp<5000),"The real main-scene combat fixture takes actual new-weapon damage")
	await capture("new-weapons-combat")
	game.show_build_ui();await settle();await capture("new-weapons-assembly")
	check(visible_text(game.panel).contains("身体拼接"),"New weapon art also renders in the existing assembly interface")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures,"animation_frames":frame_index,"fixture":"Three newly mounted organs versus three stationary high-health targets; normal main-scene rendering and combat."}
	FileAccess.open("res://artifacts/mutation-weapons-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
