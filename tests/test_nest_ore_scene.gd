extends "res://tests/test_centipede_scene.gd"

const World = preload("res://scripts/cave_world.gd")
class RawOreWorld extends World:
	func ore(cell: Vector2i) -> int: return original_ore(cell)

func settle():
	for i in 4: await process_frame

func shot(tag: String) -> Image:
	game.sync_camera_layers(); game.insect_layer.sync(game, 0); game.queue_redraw()
	await settle()
	if DisplayServer.get_name() == "headless": return null
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var path = "res://artifacts/nest-ore-" + tag + ".png"
	check(image.save_png(path) == OK, "Native capture: " + tag); captures.append(path)
	return image

func patch_difference(a: Image, b: Image, center: Vector2i, radius: int) -> float:
	var difference = 0.0
	for y in range(center.y - radius, center.y + radius):
		for x in range(center.x - radius, center.x + radius):
			var from = a.get_pixel(x, y); var to = b.get_pixel(x, y)
			difference += absf(from.r - to.r) + absf(from.g - to.g) + absf(from.b - to.b)
	return difference / (radius * radius * 4)

func use_world(world):
	game.charcoal_terrain.world = world; game.player.terrain = world; game.combat.terrain = world
	game.cave_terrain.reset()

func execute():
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate(); root.add_child(game); await settle()
	game.set_process(false); game.test_mode = true; game.save.fresh(); game.start_run(); game.set_process(false)
	game.tutorials.visible = false
	game.combat.enemies.clear(); game.combat.drones.clear(); game.combat.enemy_drones.clear()
	game.combat.effects.clear(); game.combat.death_splatters.clear(); game.combat.loot.clear(); game.combat.bullets.clear()
	var map = game.run.map_director
	map.nodes.clear(); map.pending_nodes.clear(); map.actor_jobs.clear()
	map.spawn_node(Vector2.ZERO, 103)
	var node: Dictionary = map.nodes[Vector2.ZERO]
	for e in game.combat.enemies: e.guns = []; e.components = []; e.warp = 0
	game.camera = node.position; game.center = Vector2(720, 450); game.zoom = 1.8
	game.player.head = game.player.terrain.safe_position(node.position + Vector2(-450, 250), 30); game.player.motion.reset(); game.player.refresh_positions()
	# Isolate the center's drawing from its independently rendered defenders.
	var members: Array = game.combat.enemies.duplicate()
	game.combat.enemies.clear(); var center_sprite = node.center_sprite; node.erase("center_sprite")
	var empty = await shot("nest-empty-reference")
	node.center_sprite = center_sprite
	var intact = await shot("nest-intact")
	game.combat.enemies = members
	for uid in node.objectives:
		var e = game.combat.entity(uid); e.hp = 0
	game.combat.step(0, Vector2.RIGHT, false, false); map.step(0)
	check(not node.has("center_sprite") and game.combat.effects.any(func(fx): return fx.kind == "explosion" and fx.position == node.position), "Actual map clear removes the center and produces its burst")
	game.combat.step(.08, Vector2.RIGHT, false, false)
	await shot("nest-burst")
	# Inspect the fully expired center without pickups or surviving guards covering it.
	game.combat.enemies.clear(); game.combat.loot.clear(); game.insect_layer.clear()
	game.combat.step(2, Vector2.RIGHT, false, false)
	var cleared = await shot("nest-cleared")
	if empty != null:
		var drawn = patch_difference(empty, intact, Vector2i(720,450), 70)
		var remains = patch_difference(empty, cleared, Vector2i(720,450), 70)
		check(drawn > .02 and remains < .001, "Native pixels show a live center, then restore the empty ground after the burst")

	var world = World.new(); world.reset_cave(true)
	var example = Vector2i.MAX
	for pit in world.nearby(Rect2(-4200,-4200,8400,8400)):
		var bounds: Rect2 = Rect2(pit.bounds).grow(120)
		var low = Vector2i((bounds.position / World.CELL).floor()); var high = Vector2i((bounds.end / World.CELL).floor())
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var cell = Vector2i(x, y)
				if world.original_ore(cell) != 1 or world.ore(cell) != 0: continue
				if world.cell_shape(cell).outline.size() > 0: example = cell; break
			if example != Vector2i.MAX: break
		if example != Vector2i.MAX: break
	check(example != Vector2i.MAX, "A real cyan deposit on a generated cave boundary reproduces the reported hard-wall overlap")
	if example != Vector2i.MAX:
		game.camera = (Vector2(example) + Vector2.ONE * .5) * World.CELL; game.zoom = 1.8
		var reference = RawOreWorld.new(); reference.reset_cave(true); use_world(reference)
		await shot("ore-overlap-before")
		use_world(world)
		await shot("ore-hard-wall-clear")
		var safe_vertices = true; var vertex_count = 0
		for id in game.cave_terrain.visible_chunks:
			var mesh = game.cave_terrain.meshes[id].ore
			if mesh == null: continue
			for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var point = Vector2(vertex.x, vertex.y); vertex_count += 1
				for pit in world.nearby(Rect2(point, Vector2.ZERO)):
					var local = (point - Vector2(pit.at)).rotated(-float(pit.angle)).abs()
					var half = World.SIZE * float(pit.scale) * .5
					if local.x < half.x and local.y < half.y: safe_vertices = false
		check(safe_vertices, "Every submitted mineral-mesh vertex remains outside nearby painted hard walls")
		check(world.ore(example) == 0 and reference.ore(example) == 1, "The formerly obstructed deposit is excluded by the real simulation field")
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.queue_free(); await settle()
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "captures": captures, "former_overlap_cell": example}
	FileAccess.open("res://artifacts/nest-ore-scene-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
