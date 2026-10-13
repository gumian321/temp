extends SceneTree
## Physical sockets, visible moving emitters and a short real-scene preview.
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
var checks: Array = []
var clip_frames = 0
var game

func _initialize(): call_deferred("execute")
func check(ok: bool, title: String):
	checks.append({"name":title,"passed":ok})
	if not ok: printerr("FAIL: ",title)

func shot_at_sway(db, sway: Vector2) -> Dictionary:
	var body = Body.new(db)
	body.install_module(db.named("Core_Gun_Cannon").id, 1, 0)
	body.parts[1].mount_sway = sway
	var battle = Battle.new(db, body)
	var enemy = battle.spawn(db.pool["250"], body.weapon_origin(1) + Vector2(300, 0))
	enemy.hp = 10000; enemy.max_hp = 10000; enemy.guns = []; enemy.mission_controlled = true
	battle.step(0.001, enemy.position, false)
	var flashes = battle.effects.filter(func(e): return e.kind == "muzzle" and e.get("fx_family") == "cannon")
	return {"socket":body.parts[1].position,"flashes":flashes}

func execute():
	var db = DB.new()
	var baseline = shot_at_sway(db, Vector2.ZERO)
	var swayed = shot_at_sway(db, Vector2(0,4))
	check(baseline.socket == swayed.socket, "A swaying cannon keeps its physical socket fixed")
	check(baseline.flashes.size()==1 and swayed.flashes.size()==1, "Both mounted cannons fire through real combat")
	if baseline.flashes.size()==1 and swayed.flashes.size()==1:
		check((Vector2(swayed.flashes[0].position)-Vector2(baseline.flashes[0].position)).distance_to(Vector2(0,4))<0.01, "The actual muzzle follows the visible flexible mount")
	var body = Body.new(db)
	var gun = db.named("Core_Gun_Gatling").id
	var sockets_ok = true
	var edge_visible = true
	for slot in range(9):
		body.reset(); body.install_module(gun, 1, 4)
		edge_visible = edge_visible and body.module_size(1) >= 50
		sockets_ok = sockets_ok and body.collision_radius(1)==27.0
	check(edge_visible, "Each new segment displays its element at a readable large size")
	check(sockets_ok, "The complete shell has a stable physical collision radius")
	for slot in range(8): body.append_segment(gun)
	var attachments = body.blueprint()
	var wobble = 0.0
	var stable = true
	for frame in range(180):
		body.step(1.0/60.0, Vector2.RIGHT if frame<60 else (Vector2.UP if frame<120 else Vector2.ZERO), false)
		for part in body.parts:
			var sway: Vector2 = part.get("mount_sway", Vector2.ZERO)
			stable = stable and sway.is_finite() and sway.length()<=6.001
			wobble = maxf(wobble, sway.length())
	check(stable and wobble>1.0, "Starts, turns and stops produce bounded soft mount movement")
	check(body.blueprint()==attachments, "Flexible mounts preserve construction coordinates and saved blueprints")
	if DisplayServer.get_name()!="headless": await preview(db)
	var report = {"checks":checks,"passed":checks.all(func(c):return c.passed),"clip_frames":clip_frames,"clip_fps":12,"scope":"Real production scene, one element per segment; enemies omitted to show size and sway."}
	FileAccess.open("res://artifacts/weapon-mounts-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)

func picture(path: String, small: bool = false):
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	if small: picture.resize(1080,675,Image.INTERPOLATE_LANCZOS)
	check(picture.save_png(path)==OK,"Saved "+path.get_file())

func preview(db):
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.set_process(false); game.test_mode=true; game.save.state.settings.skip_boss=true
	game.start_run(); game.test_mode=false
	var names = ["Core_Gun_Cannon","Core_Gun_Shotgun","Core_Gun_Gatling","Core_Gun_Sniper","Core_Gun_Flame Thrower","Core_Gun_Tesla"]
	for i in names.size(): game.player.install_module(db.named(names[i]).id,i+1,4)
	game.player.append_segment(db.named(names[0]).id)
	game.combat.enemies.clear(); game.combat.drones.clear()
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}; game.run.rewards.queue.clear(); game.run.packs=0
	game.tutorials.movement_shown=true; game.tutorials.radar_shown=true; game.tutorials.fuel_shown=true
	game.show_game(); game.test_mode=true; game.zoom=1.0; game.camera=game.player.head-Vector2(150,0)
	game.label_at("每节一个元素 · 柔软底座随步伐晃动",Vector2(390,210),23)
	game._process(0); game.test_mode=false
	await picture("res://artifacts/weapon-mounts-large.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/weapon-mount-frames"))
	for frame in range(210):
		Input.action_release("move_right"); Input.action_release("move_up")
		if frame<75: Input.action_press("move_right")
		elif frame<150: Input.action_press("move_up")
		game._process(1.0/60.0)
		game.combat.enemies.clear()
		if frame%5==0:
			await picture("res://artifacts/weapon-mount-frames/frame-%04d.png"%clip_frames,true)
			clip_frames+=1
	Input.action_release("move_right"); Input.action_release("move_up")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(12): OS.delay_msec(10); await process_frame
	game.queue_free(); await process_frame; await process_frame
