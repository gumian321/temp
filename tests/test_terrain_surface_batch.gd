extends SceneTree
const Terrain = preload("res://scripts/cave_terrain.gd")
var checks: Array = []
class Holder extends RefCounted:
	var world = preload("res://scripts/cave_world.gd").new()
class Owner extends RefCounted:
	var charcoal_terrain = Holder.new()

func _initialize(): call_deferred("execute")

func check(ok: bool, title: String):
	checks.append({"passed": ok, "name": title})
	if not ok: printerr("FAIL: ", title)

func sample_buffer(seed_value: float, colored: bool) -> Dictionary:
	var vertices = PackedVector3Array([Vector3(seed_value, -0.125, 0), Vector3(seed_value + 0.0625, 4.75, 0), Vector3(seed_value - 2.5, 2.125, 0)])
	var uvs = PackedVector2Array([Vector2(-1.125, 0.375), Vector2(0.0625, 4.75), Vector2(2.5, 2.125)])
	var colors = PackedColorArray([Color(0.1, 0.25, 0.75, 0.3), Color(0.7, 0.125, 0.375, 0.8), Color(0.625, 0.5, 0.25, 1)]) if colored else PackedColorArray()
	return {"vertices": vertices, "uvs": uvs, "colors": colors}

func execute():
	if "--native-surface-storage" in OS.get_cmdline_user_args():
		await inspect_native_surface_storage()
		return
	var terrain = Terrain.new()
	var first = {"top_buffer": sample_buffer(12345.125, false), "ore_buffer": sample_buffer(-8765.25, true)}
	var second = {"top_buffer": sample_buffer(-0.0625, false), "ore_buffer": terrain.new_ore_buffer()}
	for chunk in [first, second]: chunk.top = terrain.make_mesh(chunk.top_buffer.vertices, chunk.top_buffer.uvs, chunk.top_buffer.colors)
	terrain.meshes = {Vector2i(3, 2): first, Vector2i(-1, 4): second}
	terrain.visible_chunks = [Vector2i(-1, 4), Vector2i(3, 2)]
	var top = terrain.merged_surface_buffer("top")
	var expected_vertices: PackedVector3Array = second.top_buffer.vertices.duplicate()
	expected_vertices.append_array(first.top_buffer.vertices)
	var expected_uvs: PackedVector2Array = second.top_buffer.uvs.duplicate()
	expected_uvs.append_array(first.top_buffer.uvs)
	check(top.vertices.to_byte_array() == expected_vertices.to_byte_array(), "Caps preserve exact vertex bytes and visible chunk triangle order")
	check(top.uvs.to_byte_array() == expected_uvs.to_byte_array() and top.colors.is_empty(), "Caps preserve UV bytes and the original absent color attribute")
	var ore = terrain.merged_surface_buffer("ore")
	check(ore.vertices.to_byte_array() == first.ore_buffer.vertices.to_byte_array() and ore.uvs.to_byte_array() == first.ore_buffer.uvs.to_byte_array() and ore.colors.to_byte_array() == first.ore_buffer.colors.to_byte_array(), "Minerals preserve exact vertex, UV and color bytes across an empty chunk")
	var tail = terrain.merged_surface_buffer("top", true)
	check(tail.vertices.to_byte_array() == first.top_buffer.vertices.to_byte_array() and tail.uvs.to_byte_array() == first.top_buffer.uvs.to_byte_array(), "Cap tail excludes exactly the first nonempty source command")
	terrain.refresh_surface_batch()
	check(terrain.surface_first_top == second.top, "First cap command retains its original mesh and sampler state")
	var old_mesh = terrain.surface_meshes.top
	terrain.refresh_surface_batch()
	check(terrain.surface_meshes.top == old_mesh, "Unchanged geometry and visible IDs retain uploaded surfaces")
	terrain.geometry_generation += 1
	terrain.refresh_surface_batch()
	check(terrain.surface_meshes.top != old_mesh and old_mesh in terrain.retired_surface_meshes, "Geometry changes replace surfaces while retaining old command resources")
	old_mesh = terrain.surface_meshes.top
	terrain.visible_chunks.reverse()
	terrain.refresh_surface_batch()
	check(terrain.surface_meshes.top != old_mesh and terrain.surface_chunks == terrain.visible_chunks, "Visible chunk order changes invalidate the surface cache")
	terrain.reset()
	check(terrain.surface_meshes.is_empty() and terrain.surface_chunks.is_empty() and terrain.surface_generation == -1, "Reset discards merged surface identity and visible IDs")
	terrain.refresh_surface_batch()
	check(terrain.surface_meshes.is_empty(), "An empty view issues no merged surface meshes")
	terrain.free()
	var report = {"passed": checks.all(func(item): return item.passed), "checks": checks}
	FileAccess.open("res://artifacts/terrain-surface-batch-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)

func inspect_native_surface_storage():
	var terrain = Terrain.new()
	var owner_game = Owner.new()
	owner_game.charcoal_terrain.world.reset_cave(true)
	terrain.game = owner_game
	for y in range(-2, 2):
		for x in range(-3, 3):
			var id = Vector2i(x, y)
			terrain.meshes[id] = terrain.build_chunk(id, owner_game.charcoal_terrain.world.chunk_at(id))
			terrain.visible_chunks.append(id)
	terrain.refresh_surface_batch()
	await process_frame
	var rows: Array = []
	for key in ["top", "ore"]:
		var source_vertices = PackedVector3Array()
		var source_uvs = PackedVector2Array()
		var source_colors = PackedColorArray()
		var formats: Array = []
		var skipped_first = false
		for id in terrain.visible_chunks:
			var mesh: ArrayMesh = terrain.meshes[id][key]
			if mesh == null: continue
			if key == "top" and not skipped_first:
				skipped_first = true
				continue
			formats.append(mesh.surface_get_format(0))
			var arrays = mesh.surface_get_arrays(0)
			source_vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
			source_uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
			if arrays[Mesh.ARRAY_COLOR] != null: source_colors.append_array(arrays[Mesh.ARRAY_COLOR])
		if not terrain.surface_meshes.has(key): continue
		var combined: ArrayMesh = terrain.surface_meshes[key]
		var arrays = combined.surface_get_arrays(0)
		var gpu_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var gpu_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var gpu_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var raw = terrain.merged_surface_buffer(key, key == "top")
		rows.append({"key": key, "source_formats": formats, "combined_format": combined.surface_get_format(0), "vertices": source_vertices.size(), "gpu_vertices_equal": source_vertices.to_byte_array() == gpu_vertices.to_byte_array(), "gpu_uvs_equal": source_uvs.to_byte_array() == gpu_uvs.to_byte_array(), "gpu_colors_equal": source_colors.to_byte_array() == gpu_colors.to_byte_array(), "raw_vertices_equal": raw.vertices.to_byte_array() == gpu_vertices.to_byte_array(), "raw_uvs_equal": raw.uvs.to_byte_array() == gpu_uvs.to_byte_array()})
	var passed = not rows.is_empty() and rows.all(func(row): return row.gpu_vertices_equal and row.gpu_uvs_equal and row.gpu_colors_equal)
	var report = {"passed": passed, "renderer": DisplayServer.get_name(), "rows": rows}
	FileAccess.open("res://artifacts/terrain-surface-native-storage.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); terrain.free(); quit(0 if passed else 1)
