extends "res://tests/test_centipede_scene.gd"
var routes: Array = []

class BoundaryOverlay extends Node2D:
	var game
	var pit: Dictionary
	var routes: Array
	func _draw():
		var outline = PackedVector2Array()
		for point in pit.polygon:outline.append(game.world(point))
		outline.append(outline[0]);draw_polyline(outline,Color(1,.12,.35,.85),2,true)
		for route in routes:
			var screen = PackedVector2Array()
			for point in route:screen.append(game.world(point))
			if screen.size()>1:draw_polyline(screen,Color(.3,.85,1,.8),2,true)
		draw_arc(game.world(game.player.head),game.player.collision_radius(0),0,TAU,48,Color(.4,1,.6),2,true)

func shot(tag: String):
	game.sync_camera_layers();game.insect_layer.sync(game,0);game.battle_hud.refresh();game.queue_redraw()
	await process_frame;await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var path="res://artifacts/chasm-"+tag+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Native capture "+tag);captures.append(path)

func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.save.fresh();game.test_mode=false
	game.selected_mission=game.db.named("Survival Mission");game.start_run();game.set_process(false)
	# These measured cliff fixtures exercise the indestructible pit component;
	# cave generation and mining are covered by test_cave_scene separately.
	game.player.terrain.reset_cave(false)
	game.combat.enemies.clear();game.combat.drones.clear();game.combat.loot.clear();game.combat.effects.clear()
	var terrain=game.player.terrain
	check(terrain==game.charcoal_terrain.world and terrain==game.combat.terrain,"Production renderer, player and enemies share one terrain")
	var pit=terrain.shape("opening:2",terrain.OPENING[2],1.24,2.26)
	var center=Rect2(pit.bounds).get_center()
	var start=Vector2(pit.bounds.position.x-70,center.y)
	var other_shore=Vector2(pit.bounds.end.x+65,center.y)
	game.player.head=start;game.player.facing=Vector2.RIGHT;game.player.motion.reset();game.player.refresh_positions()
	game.camera=center;game.center=Vector2(720,450)
	for frame in 180:game.player.step(1.0/60.0,Vector2.RIGHT,false)
	check(not terrain.blocked(game.player.head,30),"Real player pressing into cliff remains on shore")
	var stationary=game.player.head
	for kind in ["charger","broodmother","treasure","hatchling"]:
		var enemy=game.run.encounters.spawn_special(kind,center)
		check(not terrain.blocked(enemy.position,enemy.radius),"Special enemy spawns on land: "+kind)
	game.combat.enemies.clear()
	# A charging monster may slide at the lip but never traverses the black void.
	var charger=game.run.encounters.spawn_special("charger",start)
	charger.encounter_phase="dash";charger.phase_left=1.0;charger.charge_direction=Vector2.RIGHT;charger.warp=0
	var clear=true
	for frame in 60:
		game.run.encounters.move_actor(charger,1.0/60.0)
		clear=clear and not terrain.blocked(charger.position,charger.radius)
	check(clear,"Production charger dash obeys the cliff before contact damage")
	game.combat.enemies.clear()
	for i in 3:
		var e=game.combat.spawn(game.db.pool["250"],other_shore+Vector2(20*i,(i-1)*70))
		e.components=[];e.guns=[];e.warp=0;e.stop_distance=0;e.movement={"enginePower":2.0,"rotEngineModifier":120.0}
		routes.append([Vector2(e.position)])
	await shot("opposite-shores")
	clear=true
	for frame in 480:
		game.combat.step(1.0/60.0,other_shore,false,false)
		for i in game.combat.enemies.size():
			var e=game.combat.enemies[i]
			clear=clear and not terrain.blocked(e.position,e.radius)
			if frame%6==0:routes[i].append(Vector2(e.position))
	check(clear,"Rendered chase stays outside the same painted lip")
	check(game.combat.enemies.any(func(e):return Vector2(e.position).distance_to(stationary)<90),"Monsters reach the player's shore by going around")
	var overlay=BoundaryOverlay.new();overlay.game=game;overlay.pit=pit;overlay.routes=routes;game.add_child(overlay)
	await shot("routes-debug");overlay.queue_free();await process_frame
	await shot("shore-after-chase")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures,"debug":"Pink outline is collision lip; cyan lines are measured monster routes. Overlay is test-only."}
	FileAccess.open("res://artifacts/chasm-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
