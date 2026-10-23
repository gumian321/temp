extends Node2D
## Flat top-down chalk rock, broken ink contours and mineral inclusions. The small
## underlying cells have no visible seams; all vertices are shared in world space.
const World = preload("res://scripts/cave_world.gd")
const Art = preload("res://scripts/charcoal_art.gd")
const ORE_ATLAS = preload("res://assets/charcoal_ink/ore_grains/ore_grains_v2.png")
const ORE_GRID = Vector2(3, 2)
const LIFT = Vector2.ZERO
const StrokeBatch=preload("res://scripts/cave_stroke_batch.gd")
var use_stroke_meshes=true
var shadow_strokes:Node2D
var detail_strokes:Dictionary={}
var chip_fill:Node2D
var game
var meshes: Dictionary = {}
var visible_chunks: Array = []
var retired_meshes: Array = []
var mineral_cells: Dictionary = {}
var cap_cells:Dictionary={}
var patches:Dictionary={}
var ore_patches: Dictionary = {}
var prefetch_frame = -1
var prefetched = 0
var warm_job:Dictionary={}
var geometry_generation=0
var detail_generation=-1
var caps: Node2D
var minerals: Node2D
var mineral_texture: Texture2D
var details: Node2D
var hints: Node2D
var hint_text = ""
var hint_position = Vector2.INF
var chip_mesh: ArrayMesh

class Caps extends Node2D:
	var terrain
	func _draw(): terrain.paint_caps(self)

class Details extends Node2D:
	var terrain
	func _draw(): terrain.paint_details(self)

class Minerals extends Node2D:
	var terrain
	func _draw(): terrain.paint_minerals(self)

class Hints extends Node2D:
	var terrain
	func _draw(): terrain.paint_hint(self)

class ChipFill extends Node2D:
	var terrain
	func _draw():
		if terrain.chip_mesh!=null:draw_mesh(terrain.chip_mesh,null)

func setup(owner_game):
	game = owner_game; z_index = -6
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shadow_strokes=StrokeBatch.new();shadow_strokes.setup(Color(0,0,0,.38),7);add_child(shadow_strokes)
	caps = Caps.new(); caps.terrain = self; add_child(caps)
	minerals = Minerals.new(); minerals.terrain = self; add_child(minerals)
	details = Details.new(); details.terrain = self; add_child(details)
	for row in [["hatches",Color(.08,.08,.07,.24),1.1],["cracks",Color("141411"),2.0],["fractures",Color(.12,.12,.10,.75),1.1],["chips",Color("282824"),.8],["edges",Color("242421"),1.8],["rim",Color(.82,.81,.76,.55),.9]]:
		if row[0]=="chips":chip_fill=ChipFill.new();chip_fill.terrain=self;details.add_child(chip_fill)
		var stroke=StrokeBatch.new();stroke.setup(row[1],row[2]);details.add_child(stroke);detail_strokes[row[0]]=stroke
	hints = Hints.new(); hints.terrain = self; add_child(hints); hints.top_level = true
	var surface = ShaderMaterial.new()
	surface.shader = preload("res://shaders/cave_rock.gdshader")
	surface.set_shader_parameter("rock_texture", Art.texture("ground"))
	caps.material = surface
	var mineral_surface = ShaderMaterial.new()
	mineral_surface.shader = preload("res://shaders/cave_minerals.gdshader")
	minerals.material = mineral_surface
	# Generate this once, rather than reimporting or touching textures during
	# bites. Mipmaps keep the small inked grains steady at normal game zoom.
	var image = ORE_ATLAS.get_image()
	if not image.has_mipmaps(): image.generate_mipmaps()
	mineral_texture = ImageTexture.create_from_image(image)

func reset():
	retired_meshes.append_array(meshes.values())
	meshes.clear(); visible_chunks.clear()
	mineral_cells.clear(); ore_patches.clear(); prefetch_frame = -1; prefetched = 0
	cap_cells.clear()
	patches.clear()
	warm_job.clear()
	geometry_generation+=1

func preparation_chunks() -> Array:
	if not game.charcoal_terrain.world.enabled: return []
	var extent = game.get_viewport_rect().size / game.zoom
	# Enter with an extra chunk already prepared, so the first camera seam does
	# not schedule an entire cold rock mesh during combat.
	var view = Rect2(game.camera - extent * .5, extent).grow(90+World.CHUNK*World.CELL)
	var size = World.CHUNK * World.CELL
	var low = Vector2i((view.position / size).floor())
	var high = Vector2i((view.end / size).floor())
	var jobs: Array = []
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1): jobs.append(Vector2i(x, y))
	return jobs

func prepare_chunk(id: Vector2i):
	var data = game.charcoal_terrain.world.chunk_at(id)
	if meshes.has(id) and meshes[id].version == data.version: return
	if meshes.has(id): retired_meshes.append(meshes[id])
	meshes[id] = build_chunk(id, data)

func prepare_ahead(on_screen:Rect2):
	var size=World.CHUNK*World.CELL
	var ahead=on_screen.grow(90+size)
	var low=Vector2i((ahead.position/size).floor());var high=Vector2i((ahead.end/size).floor())
	if not warm_job.is_empty() and not Rect2(Vector2(warm_job.id)*size,Vector2.ONE*size).intersects(ahead):warm_job.clear()
	if warm_job.is_empty():
		var best=INF;var chosen=Vector2i.MAX
		for y in range(low.y,high.y+1):
			for x in range(low.x,high.x+1):
				var id=Vector2i(x,y)
				if meshes.has(id):continue
				var distance=((Vector2(id)+Vector2.ONE*.5)*size-game.camera).length_squared()
				if distance<best:best=distance;chosen=id
		if chosen==Vector2i.MAX:return
		warm_job={"id":chosen,"index":0}
	var span=World.CHUNK/World.DRAW_PATCH
	if warm_job.index>=span*span:
		prepare_chunk(warm_job.id);warm_job.clear();return
	var started=Time.get_ticks_usec()
	while warm_job.index<span*span:
		var index=int(warm_job.index)
		cached_patch(Vector2i(warm_job.id)*span+Vector2i(index%span,index/span))
		warm_job.index+=1
		if Time.get_ticks_usec()-started>=900:break

func sync():
	visible = game.screen in ["game", "pause", "result", "rewards", "build"] and not game.radar_mode and game.charcoal_terrain.world.enabled
	if not visible: return
	var extent = game.get_viewport_rect().size / game.zoom
	var on_screen = Rect2(game.camera - extent * 0.5, extent)
	var view = on_screen.grow(90)
	if prefetch_frame != Engine.get_process_frames():
		prefetch_frame = Engine.get_process_frames(); prefetched = 0
	var size = World.CHUNK * World.CELL
	var low = Vector2i((view.position / size).floor())
	var high = Vector2i((view.end / size).floor())
	var next_chunks: Array = []
	var geometry_changed = false
	var damage_changed = false
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var id = Vector2i(x, y)
			if not meshes.has(id):
				# The larger look-ahead ring prepares small patches over several
				# frames; visible rock and actual bites still refresh immediately.
				var outside = not Rect2(Vector2(id) * size, Vector2.ONE * size).grow(8).intersects(on_screen)
				if outside:continue
			var data = game.charcoal_terrain.world.chunk_at(id)
			if not meshes.has(id) or meshes[id].version != data.version:
				if meshes.has(id): retired_meshes.append(meshes[id])
				meshes[id] = build_chunk(id, data)
				geometry_changed = true
			elif meshes[id].damage_version != data.damage_version:
				meshes[id].cracks = build_cracks(id, data)
				meshes[id].strokes.cracks=StrokeBatch.build_buffer(meshes[id].cracks,2.0)
				meshes[id].damage_version = data.damage_version
				damage_changed = true
			next_chunks.append(id)
	var view_changed = next_chunks != visible_chunks
	visible_chunks = next_chunks
	if meshes.size() > 80:
		for id in meshes.keys():
			if meshes.size()<=80:break
			if id not in visible_chunks:
				retired_meshes.append(meshes[id]); meshes.erase(id)
	# Keep the canvas commands while the camera moves. Godot can transform the
	# retained rock drawing without rebuilding every line and ore polygon.
	position = game.world(Vector2.ZERO); scale = Vector2.ONE * game.zoom
	if geometry_changed or view_changed:
		geometry_generation+=1
		queue_redraw(); caps.queue_redraw(); minerals.queue_redraw()
	if geometry_changed or damage_changed or view_changed: details.queue_redraw()
	if prefetched==0:
		prefetched=1;prepare_ahead(on_screen)
	hints.visible = game.screen == "game"
	var text = game.db.ui("Push into rock to chew a tunnel", "顶住岩壁啃挖 · 矿脉掉落水晶")
	if game.charcoal_terrain.world.mining_active: text = game.db.ui("CHEWING · Release direction to stop", "正在啃挖 · 松开方向停止")
	elif game.player.motion.reversing: text = game.db.ui("BACKING OUT · Following the tunnel", "沿洞道后退中")
	var at = Vector2(24, game.get_viewport_rect().size.y - 140)
	if text != hint_text or at != hint_position:
		hint_text = text; hint_position = at; hints.queue_redraw()

func make_mesh(vertices: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray) -> ArrayMesh:
	if vertices.is_empty(): return null
	var mesh = ArrayMesh.new()
	var arrays = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not colors.is_empty():arrays[Mesh.ARRAY_COLOR] = colors
	if not uvs.is_empty(): arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func new_ore_buffer() -> Dictionary:
	return {"vertices": PackedVector3Array(), "uvs": PackedVector2Array(), "colors": PackedColorArray()}

func cached_ore(cell: Vector2i, shape: Dictionary, kind: int) -> Dictionary:
	if mineral_cells.has(cell) and is_same(mineral_cells[cell].shape, shape): return mineral_cells[cell].buffer
	var buffer = new_ore_buffer()
	build_ore(cell, shape.pieces, kind, buffer)
	if mineral_cells.size() >= 1024:
		var oldest = mineral_cells.keys()
		for i in 64: mineral_cells.erase(oldest[i])
	mineral_cells[cell] = {"shape": shape, "buffer": buffer}
	return buffer

func cached_cap(cell:Vector2i,shape:Dictionary)->Dictionary:
	if cap_cells.has(cell) and is_same(cap_cells[cell].shape,shape):return cap_cells[cell]
	var vertices=PackedVector3Array();var uvs=PackedVector2Array()
	for piece in shape.pieces:
		var polygon:PackedVector2Array=piece.polygon
		for triangle in range(1,polygon.size()-1):
			for i in [0,triangle,triangle+1]:
				var at=polygon[i]
				vertices.append(Vector3(at.x,at.y,0));uvs.append(at/1450.0+Vector2(.32,.37))
	if cap_cells.size()>=12000:
		var oldest=cap_cells.keys()
		for i in 128:cap_cells.erase(oldest[i])
	var result={"shape":shape,"vertices":vertices,"uvs":uvs}
	cap_cells[cell]=result
	return result

func cached_patch(id:Vector2i)->Dictionary:
	var world = game.charcoal_terrain.world
	var version=int(world.patch_versions.get(id,0))
	if patches.has(id) and patches[id].version==version:return patches[id]
	var edges = PackedVector2Array(); var hatches = PackedVector2Array()
	var rows:Array=[]
	var data=world.chunk_at(world.chunk_id(id*World.DRAW_PATCH))
	for y in World.DRAW_PATCH:
		var row={"vertices":PackedVector3Array(),"uvs":PackedVector2Array(),"edges":PackedVector2Array(),"hatches":PackedVector2Array(),"ore":new_ore_buffer()}
		rows.append(row)
		for x in World.DRAW_PATCH:
			var cell = id * World.DRAW_PATCH + Vector2i(x, y)
			var index = world.cell_index(cell)
			var shape = world.cell_shape(cell)
			var cap=cached_cap(cell,shape)
			row.vertices.append_array(cap.vertices);row.uvs.append_array(cap.uvs)
			edges.append_array(shape.outline)
			row.edges.append_array(shape.outline)
			if data.solid[index] == 0: continue
			var center = (Vector2(cell) + Vector2.ONE * 0.5) * World.CELL + LIFT
			var n = world.noise_id(cell, 71)
			var kind = world.ore(cell)
			if kind == 0 and n % 4 == 0:
				var stroke = Vector2(7 + n % 7, -8 - (n / 13) % 7)
				hatches.append(center - stroke * 0.5); hatches.append(center + stroke * 0.5)
				row.hatches.append(center-stroke*.5);row.hatches.append(center+stroke*.5)
			if kind > 0:
				var infill = cached_ore(cell, shape, kind)
				row.ore.vertices.append_array(infill.vertices);row.ore.uvs.append_array(infill.uvs);row.ore.colors.append_array(infill.colors)
	if patches.size()>=2048:
		var oldest=patches.keys()
		for i in 64:patches.erase(oldest[i])
	var strokes={"shadow":StrokeBatch.build_buffer(edges,7),"edges":StrokeBatch.build_buffer(edges,1.8),"hatches":StrokeBatch.build_buffer(hatches,1.1)}
	var result={"version":version,"rows":rows,"strokes":strokes}
	patches[id]=result
	return result

func build_chunk(id: Vector2i, data: Dictionary) -> Dictionary:
	var vertices=PackedVector3Array();var uvs=PackedVector2Array()
	var edges=PackedVector2Array();var hatches=PackedVector2Array()
	var ore_buffer=new_ore_buffer()
	var span=World.CHUNK/World.DRAW_PATCH
	var stroke_parts={"shadow":[],"edges":[],"hatches":[]}
	for y in World.CHUNK:
		for x in span:
			var patch=cached_patch(id*span+Vector2i(x,y/World.DRAW_PATCH))
			var row=patch.rows[y%World.DRAW_PATCH]
			vertices.append_array(row.vertices);uvs.append_array(row.uvs)
			edges.append_array(row.edges);hatches.append_array(row.hatches)
			ore_buffer.vertices.append_array(row.ore.vertices);ore_buffer.uvs.append_array(row.ore.uvs);ore_buffer.colors.append_array(row.ore.colors)
			if y%World.DRAW_PATCH==0:
				for key in stroke_parts:stroke_parts[key].append(patch.strokes[key])
	var weathering = build_weathering(edges)
	var cracks=build_cracks(id,data)
	var chip_edges=PackedVector2Array()
	for chip in weathering.chips:
		for i in chip.size():chip_edges.append(chip[i]);chip_edges.append(chip[(i+1)%chip.size()])
	var strokes={}
	for key in stroke_parts:strokes[key]=StrokeBatch.merge_buffers(stroke_parts[key])
	for row in [["cracks",cracks,2.0],["fractures",weathering.fractures,1.1],["chips",chip_edges,.8],["rim",weathering.rim,.9]]:
		strokes[row[0]]=StrokeBatch.build_buffer(row[1],row[2])
	return {"version": data.version, "damage_version": data.damage_version, "top": make_mesh(vertices, uvs, PackedColorArray()), "edges": edges, "hatches": hatches, "cracks": cracks, "ore": make_mesh(ore_buffer.vertices, ore_buffer.uvs, ore_buffer.colors),
		"fractures": weathering.fractures, "chips": weathering.chips, "rim": weathering.rim,"strokes":strokes}

func ore_patch(cell: Vector2i, kind: int) -> Array:
	if ore_patches.has(cell): return ore_patches[cell]
	var world = game.charcoal_terrain.world
	var pending: Array[Vector2i] = [cell]
	var members: Dictionary = {cell: true}
	var low = cell; var high = cell
	# Read the original ore field, including already excavated cells. The same
	# deposit keeps its texture placement as mining removes pieces of its wall.
	while not pending.is_empty() and members.size() < 64:
		var current = pending.pop_back()
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if members.has(next) or world.ore(next) != kind: continue
			members[next] = true; pending.append(next)
			low = low.min(next); high = high.max(next)
	var span = Vector2(high - low + Vector2i.ONE) * World.CELL
	var center = (Vector2(low + high) + Vector2.ONE) * World.CELL * 0.5
	var vertical = span.y > span.x
	var short_side = minf(span.x, span.y); var long_side = maxf(span.x, span.y)
	var count = 2 if long_side / short_side > 1.35 else 1
	var axis = Vector2.DOWN if vertical else Vector2.RIGHT
	var spread = maxf(0, long_side - short_side * 0.8)
	var stamps: Array = []
	for i in count:
		var n = world.noise_id(low, 23819 + i * 997)
		var at = center + axis * ((float(i) - 0.5) * spread if count == 2 else 0.0)
		var size = short_side * (1.48 + float(n % 5) * 0.025)
		var transform = Transform2D(float(n % 360) * TAU / 360.0, at)
		stamps.append({"transform": transform, "inverse": transform.affine_inverse(), "size": size, "variant": n % 6})
	if ore_patches.size() > 2048:
		var oldest = ore_patches.keys()
		for i in 128: ore_patches.erase(oldest[i])
	for member in members: ore_patches[member] = stamps
	return stamps

func clip_ore(polygon: PackedVector2Array, stamp: Dictionary, tint: Color, pieces: Array, buffer: Dictionary):
	var bounds = Rect2(polygon[0], Vector2.ZERO)
	for at in polygon: bounds = bounds.expand(at)
	for piece in pieces:
		if not bounds.intersects(piece.bounds): continue
		# Texture coordinates come from the whole deposit, while the triangles
		# use the exact physical rock. Adjacent cells never show sprite seams.
		for patch in Geometry2D.intersect_polygons(polygon, piece.polygon):
			for triangle in range(1, patch.size() - 1):
				for i in [0, triangle, triangle + 1]:
					var at: Vector2 = patch[i]
					var local = stamp.inverse * at / stamp.size + Vector2.ONE * 0.5
					var tile = Vector2(int(stamp.variant) % 3, int(stamp.variant) / 3)
					buffer.vertices.append(Vector3(at.x, at.y, 0))
					buffer.uvs.append((tile + local) / ORE_GRID); buffer.colors.append(tint)

func build_ore(cell: Vector2i, pieces: Array, kind: int, buffer: Dictionary):
	if pieces.is_empty(): return
	var tint: Color = [Color("3fc7cc"), Color("d3a34c"), Color("ce659c")][kind - 1]
	for stamp in ore_patch(cell, kind):
		var polygon = PackedVector2Array()
		for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
			polygon.append(stamp.transform * (corner * stamp.size))
		clip_ore(polygon, stamp, tint, pieces, buffer)

func build_weathering(edges: PackedVector2Array) -> Dictionary:
	var world = game.charcoal_terrain.world
	var fractures = PackedVector2Array(); var rim = PackedVector2Array(); var chips: Array = []
	var decorated: Dictionary = {}
	for i in range(0, edges.size(), 2):
		var a = edges[i]; var b = edges[i + 1]
		var axis = (b - a).normalized()
		var inward = Vector2(-axis.y, axis.x)
		var middle = a.lerp(b, 0.5)
		var key = Vector2i((middle / 28.0).floor())
		var n = world.noise_id(key, 19739)
		# Break the uniform pale piping into quiet patches of exposed chalk.
		if n % 5 != 0:
			var inset = inward * (1.1 + float(n % 4) * 0.25)
			rim.append(a + inset); rim.append(b + inset)
		if decorated.has(key): continue
		decorated[key] = true
		if n % 11 < 2:
			var p = middle + inward * 2.5
			var q = p + inward * (3 + n % 4) + axis * (float((n / 7) % 11) - 5)
			var r = q + inward * (3 + (n / 11) % 5) + axis * (float((n / 13) % 11) - 5)
			if world.wall_blocked(p) and world.wall_blocked(q):
				fractures.append(p); fractures.append(q)
				if world.wall_blocked(r): fractures.append(q); fractures.append(r)
				var branch = q + axis * (4 + n % 4) + inward * 2
				if n % 3 == 0 and world.wall_blocked(branch): fractures.append(q); fractures.append(branch)
		if n % 7 == 0:
			var at = middle - inward * (6 + n % 6) + axis * (float((n / 17) % 7) - 3)
			if not world.wall_blocked(at, 2):
				var scale_value = 1.5 + float(n % 4) * 0.4
				var polygon = PackedVector2Array([at - axis * scale_value, at + inward * scale_value * 0.7, at + axis * scale_value * 0.7, at - inward * scale_value])
				chips.append(polygon)
	return {"fractures": fractures, "chips": chips, "rim": rim}

func build_cracks(id: Vector2i, data: Dictionary) -> PackedVector2Array:
	var world = game.charcoal_terrain.world
	var cracks = PackedVector2Array()
	# Bite marks change much more often than rock geometry. Only visit the
	# damaged cells; intact caps and cut faces keep their existing GPU meshes.
	for index in data.damage:
		var cell = id * World.CHUNK + Vector2i(int(index) % World.CHUNK, int(index) / World.CHUNK)
		var center = (Vector2(cell) + Vector2.ONE * 0.5) * World.CELL + LIFT
		var n = world.noise_id(cell, 71)
		var arm = 6.0 + float(data.damage[index]) / world.durability(cell) * 8.0
		for side in 3:
			cracks.append(center); cracks.append(center + Vector2.from_angle(float(side) * 2.1 + n % 9) * arm)
	return cracks

func _draw():
	if game == null: return
	shadow_strokes.visible=use_stroke_meshes
	if use_stroke_meshes:
		var buffers=[]
		for id in visible_chunks:buffers.append(meshes[id].strokes.shadow)
		shadow_strokes.set_buffers(buffers)
	else:
		var edges=PackedVector2Array()
		for id in visible_chunks:edges.append_array(meshes[id].edges)
		if not edges.is_empty():draw_multiline(edges,Color(0,0,0,.38),7,true)

func paint_caps(canvas: Node2D):
	for id in visible_chunks:
		var item = meshes[id]
		if item.top != null: canvas.draw_mesh(item.top, Art.texture("ground"))

func paint_minerals(canvas: Node2D):
	for id in visible_chunks:
		if meshes[id].ore != null: canvas.draw_mesh(meshes[id].ore, mineral_texture)

func paint_details(canvas: Node2D):
	for stroke in detail_strokes.values():stroke.visible=use_stroke_meshes
	chip_fill.visible=use_stroke_meshes
	if use_stroke_meshes and detail_generation==geometry_generation:
		var buffers=[]
		for id in visible_chunks:buffers.append(meshes[id].strokes.cracks)
		detail_strokes.cracks.set_buffers(buffers);chip_fill.queue_redraw()
		retired_meshes.clear()
		return
	var hatches = PackedVector2Array(); var cracks = PackedVector2Array(); var fractures = PackedVector2Array()
	var edges = PackedVector2Array(); var rim = PackedVector2Array(); var chip_edges = PackedVector2Array()
	var chips: Array = []
	for id in visible_chunks:
		var item = meshes[id]
		hatches.append_array(item.hatches); cracks.append_array(item.cracks); fractures.append_array(item.fractures)
		edges.append_array(item.edges); rim.append_array(item.rim); chips.append_array(item.chips)
		for chip in item.chips:
			for i in chip.size(): chip_edges.append(chip[i]); chip_edges.append(chip[(i + 1) % chip.size()])
	if not use_stroke_meshes:
		if not hatches.is_empty(): canvas.draw_multiline(hatches, Color(0.08, 0.08, 0.07, 0.24), 1.1, true)
		if not cracks.is_empty(): canvas.draw_multiline(cracks, Color("141411"), 2.0, true)
		if not fractures.is_empty(): canvas.draw_multiline(fractures, Color(0.12, 0.12, 0.10, 0.75), 1.1, true)
	# Keep fills together, then all outlines together. Alternating the two for
	# each tiny chip broke the canvas batch hundreds of times in one viewport.
	var chip_vertices = PackedVector3Array(); var chip_colors = PackedColorArray()
	for chip in chips:
		for triangle in range(1,chip.size()-1):
			for i in [0,triangle,triangle+1]:
				chip_vertices.append(Vector3(chip[i].x,chip[i].y,0));chip_colors.append(Color("7d7c75"))
	chip_mesh=make_mesh(chip_vertices,PackedVector2Array(),chip_colors)
	if use_stroke_meshes:chip_fill.queue_redraw()
	elif chip_mesh!=null:canvas.draw_mesh(chip_mesh,null)
	if not use_stroke_meshes and not chip_edges.is_empty(): canvas.draw_multiline(chip_edges, Color("282824"), 0.8, true)
	# Rough ink contours, broken chalk lips and fine fractures keep a flat view.
	if use_stroke_meshes:
		for key in detail_strokes:
			var buffers=[]
			for id in visible_chunks:buffers.append(meshes[id].strokes[key])
			detail_strokes[key].set_buffers(buffers)
		detail_generation=geometry_generation
	else:
		if not edges.is_empty(): canvas.draw_multiline(edges, Color("242421"), 1.8, true)
		if not rim.is_empty(): canvas.draw_multiline(rim, Color(0.82, 0.81, 0.76, 0.55), 0.9, true)
	# Canvas commands hold RIDs rather than resources. Release old meshes only
	# after BOTH the cap and mineral command lists have been replaced.
	retired_meshes.clear()

func paint_hint(canvas: Node2D):
	canvas.draw_style_box(Art.panel_skin(false, true), Rect2(hint_position, Vector2(440, 34)))
	canvas.draw_string(game.font, hint_position + Vector2(22, 23), hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("eeece2"))
