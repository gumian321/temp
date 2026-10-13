extends "res://tests/test_centipede_scene.gd"
## Real mouse placement/reordering, independent health and destruction in the new UI.
func settle():
	for i in range(4):await process_frame
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.state.settings.skip_boss=true
	check(game.screen=="home","Startup goes straight to the main menu")
	await capture("chain-00-startup")
	game.start_run();await settle()
	check(game.player.segment_count()==0 and game.player.parts.size()==1,"Starting a run shows only the head")
	await capture("chain-01-head-only")
	# Check the rump attachment visually in vertical headings as well.
	game.player.facing=Vector2.UP;game.player.refresh_positions()
	await capture("chain-01-head-only-up")
	game.player.facing=Vector2.DOWN;game.player.refresh_positions()
	await capture("chain-01-head-only-down")
	game.player.facing=Vector2.RIGHT;game.player.refresh_positions()
	game.show_build_ui();await settle()
	check(game.build_ui.slots.is_empty() and game.build_ui.insert_targets.size()==1,"Empty construction has a growth target without a nine-slot grid")
	await capture("chain-02-empty-assembly")
	var names=["Core_Gun_Gatling","Core_Gun_Cannon","Core_Shield","Core_Repair"]
	for name in names:game.player.pending.append(game.db.named(name).id)
	game.show_build_ui();await settle()
	await drag_at(game.build_ui.inventory[0].get_global_rect().get_center(),Vector2(873,760))
	check(game.player.segment_count()==0 and game.player.pending.size()==4,"Invalid native drop keeps the reward and creates no segment")
	await drag_at(game.build_ui.inventory[0].get_global_rect().get_center(),game.build_ui.tail_target.get_global_rect().get_center(),true)
	await settle()
	check(game.player.segment_count()==1 and game.player.parts_on_segment(1).size()==1,"The first native drop creates one occupied segment")
	var first:Dictionary=game.player.parts[game.player.part_at(1)]
	await drag_at(game.build_ui.inventory[0].get_global_rect().get_center(),game.build_ui.insert_targets[1].get_global_rect().get_center());await settle()
	check(game.player.segment_count()==2 and first.segment==2,"Dropping in front inserts a new segment and moves the previous one back")
	await drag_at(game.build_ui.inventory[0].get_global_rect().get_center(),game.build_ui.insert_targets[2].get_global_rect().get_center());await settle()
	check(game.player.segment_count()==3 and first.segment==3,"A new element can be inserted between existing segments")
	await click_at(game.build_ui.inventory[0].get_global_rect().get_center())
	await click_at(game.build_ui.tail_target.get_global_rect().get_center());await settle()
	check(game.player.pending.is_empty() and game.player.segment_count()==4,"Click placement also adds one complete segment")
	check("1 元素 = 1 体节" in visible_text(game.panel),"The assembly screen communicates one element per segment with a compact equation")
	await capture("chain-03-assembly")
	game.player.actions.move=0;game.player.actions.swap=0
	var repair:Dictionary=game.player.parts[game.player.part_at(4)]
	var owner_index=game.player.parts.find(repair)
	await drag_at(game.build_ui.segment_buttons[4].get_global_rect().get_center(),game.build_ui.insert_targets[1].get_global_rect().get_center());await settle()
	check(repair.segment==1 and game.player.parts.find(repair)==owner_index,"Native drag reorders a whole segment without changing its combat owner index")
	check(game.player.segment_count()==4 and game.player.actions.move==0 and game.player.actions.swap==0,"Reordering does not grow the body or spend actions")
	await capture("chain-04-reordered")
	var dead=game.player.part_at(2)
	var follower:Dictionary=game.player.parts[game.player.part_at(3)]
	var tail:Dictionary=game.player.parts[game.player.part_at(4)]
	var follower_hp=float(follower.hp)
	for part in game.player.parts:
		if game.db.asset(part.id).get("class")=="ShieldCore":part.shield=0;part.stun=10.0
	game.combat.hurt_player(dead,100000,100000)
	game.combat.step(.01,game.player.head+Vector2.RIGHT*400,false)
	check(game.player.segment_count()==3 and follower.segment==2 and tail.segment==3,"A middle segment explosion compacts the surviving chain")
	check(follower.hp==follower_hp and game.player.parts[0].hp>0,"Independent follower and head health survive the middle-segment loss")
	game.show_build_ui();await settle()
	check(game.build_ui.segment_buttons.size()==3 and game.build_ui.insert_targets.size()==4,"Construction redraws the shorter chain after combat destruction")
	await capture("chain-05-after-destruction")
	game.show_game()
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
	game.combat.enemies.clear()
	var enemy=game.combat.spawn(game.db.pool["250"],game.player.head+Vector2(280,0))
	enemy.hp=10000;enemy.max_hp=10000;enemy.guns=[];enemy.mission_controlled=true
	for frame in range(90):game._process(1.0/60)
	check(game.player.head.length()>60 and game.combat.statistics.get("stat_BulletsFired",0)>0,"The reordered and shortened centipede still moves and fires")
	game.zoom=1.25;game.camera=game.player.head-Vector2(80,0)
	await capture("chain-06-combat")
	game.player.actions.wall=1;game.show_build_ui();await settle()
	await click_at(game.build_ui.segment_buttons[1].get_global_rect().get_center())
	await click_at(game.build_ui.armor_button.get_global_rect().get_center());await settle()
	check(game.player.parts[game.player.part_at(1)].wall and game.player.actions.wall==0,"Armor applies to one complete selected segment")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(12):OS.delay_msec(10);await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed),"scope":"Real native dragging/clicking in the production single-element chain UI, plus a controlled combat/destruction fixture."}
	FileAccess.open("res://artifacts/chain-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
