extends SceneTree
var checks: Array = []
class MeasuredWorld extends "res://scripts/cave_world.gd":
	var placements: Array = []
	func safe_position(point: Vector2, radius: float) -> Vector2:
		var started = Time.get_ticks_usec()
		var result = super.safe_position(point, radius)
		placements.append({"ms": float(Time.get_ticks_usec() - started) / 1000, "radius": radius})
		return result
func _initialize(): call_deferred("execute")
func check(ok: bool, label: String):
	checks.append({"passed": ok, "label": label})
	if not ok: push_error(label)
func wait_ready(game):
	var deadline = Time.get_ticks_msec() + 60000
	var held = true
	var captured = false
	while game.deployment_active and Time.get_ticks_msec() < deadline:
		if game.run != null and game.deployment_ui.progress.value >= 12: held = held and game.run.elapsed == 0
		if DisplayServer.get_name() != "headless" and not captured and game.deployment_ui.progress.value >= 60 and game.deployment_ui.progress.value < 95:
			await RenderingServer.frame_post_draw
			check(root.get_visible_rect().encloses(game.deployment_ui.progress.get_global_rect()) and root.get_visible_rect().encloses(game.deployment_ui.status.get_global_rect()), "Loading bar and caption fit inside the viewport")
			root.get_texture().get_image().save_png("res://artifacts/deployment-progress.png")
			captured = true
		await process_frame
	game.set_process(false)
	check(not game.deployment_active and game.screen == "game", "Deployment automatically enters the completed battle")
	check(held, "Simulation remains frozen throughout preparation and first rendering")
func execute():
	root.size = Vector2i(1440, 900)
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	game.test_mode = true; game.save.fresh(); game.selected_mission = game.db.named("Survival Mission")
	var measured_world=MeasuredWorld.new();game.charcoal_terrain.world=measured_world
	game.begin_run()
	check(game.deployment_active and game.screen == "deploying" and game.deployment_ui.is_visible_in_tree(), "Loading plate appears before any world generation")
	var epoch = game.deployment_epoch
	game.begin_run()
	check(game.deployment_epoch == epoch, "Repeated deployment input cannot start a second world")
	var escape = InputEventAction.new(); escape.action = "pause"; escape.pressed = true
	game._unhandled_input(escape)
	check(game.screen == "deploying", "Pause input cannot bypass unfinished loading")
	await wait_ready(game)
	var first_report = game.deployment_report.duplicate(true)
	measured_world.placements.sort_custom(func(a,b):return a.ms>b.ms)
	first_report.placements=measured_world.placements.slice(0,20)
	var steps: Array = first_report.progress
	check(steps.size() > 20 and steps[0].progress == 0 and steps[-1].progress == 100, "Real loading jobs report progress from zero through completion")
	var monotonic = true
	var distinct: Dictionary = {}
	for i in steps.size():
		distinct[steps[i].frame] = true
		if i > 0: monotonic = monotonic and steps[i].progress >= steps[i - 1].progress
	check(monotonic and distinct.size() > 20, "Progress never runs backwards and is presented on separate frames")
	check(first_report.map_nodes == 16 and game.run.map_director.pending_nodes.is_empty(), "All sixteen original map nodes finish before entry")
	check(game.combat.enemies.all(func(e):return e.kind!="Asteroid") and game.run.map_director.nodes.values().any(func(n):return n.get("cave_deposit",false)), "Continuous cave deposits replace redundant legacy giant-boulder fields")
	check(first_report.prepared_chunks > 0 and game.cave_terrain.meshes.size() >= first_report.prepared_chunks, "The whole first viewport and camera margin are already meshed")
	check(game.player.terrain == game.combat.terrain and game.player.terrain.enabled, "Prepared simulation and rendering share the same excavatable world")
	var meshes = game.cave_terrain.meshes.duplicate()
	game.cave_terrain.sync()
	check(meshes == game.cave_terrain.meshes, "First game frame reuses prepared rock meshes")
	game.begin_run(); game.show_menu(); game.begin_run()
	game.save.unlock_all_characters();game.save.select_character("spider")
	await wait_ready(game)
	check(game.player.character_id == "spider" and not game.player.terrain.enabled and game.deployment_report.prepared_chunks == 0, "Cancel/redeploy discards the old coroutine and also supports the non-cave character")
	game.begin_run(); game.show_menu()
	for i in 4: await process_frame
	check(not game.deployment_active and game.screen == "home", "Leaving preparation cannot reopen a stale battle")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "centipede": first_report, "spider": game.deployment_report}
	FileAccess.open("res://artifacts/deployment-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify({"passed": report.passed, "checks": checks, "elapsed_ms": first_report.elapsed_ms, "phases": first_report.phases}))
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.queue_free(); await process_frame; await process_frame
	quit(0 if report.passed else 1)
