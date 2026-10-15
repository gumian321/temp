extends Node2D
## Fixed material batches, shared by all attacks. No per-shot nodes/materials,
## screen reads, render targets, or simulation writes. Generated art stays intact.
const SHADER = preload("res://shaders/attack_material.gdshader")
const Feedback = preload("res://scripts/weapon_feedback.gd")
const MODES = {"gatling":0,"shotgun":0,"cannon":0,"flame":0,"flak":1,"nuke":1,"mine":1,"rocket":2,"drone":2,"rail":3,"tesla":4,"emp":5,"sonic":6,"blackhole":7,"impact":8,"silk":9,"tendril":10,"repair_drone":11,"scrap_drone":12}
var batches: Dictionary = {}
var materials: Dictionary = {}
var friendly_batches: Dictionary = {}
var hostile_batches: Dictionary = {}
var source: Node2D
var foreground_painter: Painter
var frame_time: float = 0.0
var trace_commands: bool = false
var last_occlusion: Rect2 = Rect2(-1,-1,-1,-1)

class Batch extends RefCounted:
	var rid: RID
	var material: ShaderMaterial
	var z_index: int
	var commands: Array = []
	var command_count: int = 0
	var trace: bool = false
	func setup(parent: RID, shader_material: ShaderMaterial, depth: int):
		rid=RenderingServer.canvas_item_create()
		material=shader_material;z_index=depth
		RenderingServer.canvas_item_set_parent(rid,parent)
		RenderingServer.canvas_item_set_z_index(rid,depth)
		if material!=null:RenderingServer.canvas_item_set_material(rid,material.get_rid())
	func clear():
		if command_count>0:RenderingServer.canvas_item_clear(rid)
		command_count=0
		if trace:commands.clear()
	func dispose():
		if rid.is_valid():RenderingServer.free_rid(rid);rid=RID()
	func _notification(what):
		if what==NOTIFICATION_PREDELETE and rid.is_valid():RenderingServer.free_rid(rid)

class Painter extends RefCounted:
	var batch: Batch
	var source: Node2D
	var shader_family: String
	# Compatibility alias, never a separate command stream.
	var texture_batch: Batch
	var current_transform: Transform2D = Transform2D.IDENTITY
	func world(at): return source.world(at)
	func get_viewport_rect(): return source.get_viewport_rect()
	func draw_set_transform(at: Vector2, rotation: float = 0.0, scale: Vector2 = Vector2.ONE):
		var next: Transform2D
		if at==Vector2.ZERO and rotation==0.0 and scale==Vector2.ONE:
			if current_transform==Transform2D.IDENTITY:return
			next=Transform2D.IDENTITY
		else:next=Transform2D(rotation,scale,0.0,at)
		if next==current_transform:return
		current_transform=next
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_set_transform"])
		RenderingServer.canvas_item_add_set_transform(batch.rid,next)
	func draw_texture_rect(texture: Texture2D, rect: Rect2, tile: bool, modulate: Color = Color.WHITE):
		# Native Texture2D dispatch preserves AtlasTexture margins/filter clipping.
		# Recentering preserves the shader's texture-local material coordinates.
		var centre=rect.get_center()
		if centre!=Vector2.ZERO:
			var centred=current_transform
			centred.origin=current_transform*centre
			RenderingServer.canvas_item_add_set_transform(batch.rid,centred)
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_texture_rect"])
		texture.draw_rect(batch.rid,Rect2(-rect.size*0.5,rect.size),tile,modulate)
		if centre!=Vector2.ZERO:RenderingServer.canvas_item_add_set_transform(batch.rid,current_transform)
	func draw_line(a: Vector2,b: Vector2,color: Color,width: float = 1.0,antialiased: bool = false):
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_line"])
		RenderingServer.canvas_item_add_line(batch.rid,a,b,color,width,antialiased)
	func draw_circle(at: Vector2,radius: float,color: Color,filled: bool = true,width: float = -1.0,antialiased: bool = false):
		if not filled:
			draw_arc(at,radius,0.0,TAU,maxi(32,int(radius*2.0)),color,width,antialiased)
			return
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_circle"])
		RenderingServer.canvas_item_add_circle(batch.rid,at,radius,color,antialiased)
	func draw_polygon(points,colors,uvs=PackedVector2Array(),texture=null):
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_polygon"])
		RenderingServer.canvas_item_add_polygon(batch.rid,points,colors,uvs,texture.get_rid() if texture!=null else RID())
	func draw_colored_polygon(points: PackedVector2Array,color: Color):
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_colored_polygon"])
		RenderingServer.canvas_item_add_polygon(batch.rid,points,PackedColorArray([color]))
	func draw_polyline(points: PackedVector2Array,color: Color,width: float = 1.0,antialiased: bool = false):
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_polyline"])
		RenderingServer.canvas_item_add_polyline(batch.rid,points,PackedColorArray([color]),width,antialiased)
	func draw_arc(at,radius,from,to,count,color,width=1.0,antialiased=false):
		if count<2:return
		var points=PackedVector2Array();points.resize(count)
		var span=clampf(to-from,-TAU,TAU)
		for i in count:points[i]=at+Vector2.from_angle(from+span*float(i)/float(count-1))*radius
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_arc"])
		RenderingServer.canvas_item_add_polyline(batch.rid,points,PackedColorArray([color]),width,antialiased)

func attach(canvas: Node2D):
	source=canvas
	canvas.set_meta("attack_shader_layer",self)
	canvas.add_child(self)
	name="AttackShaderMaterials"
	for key in MODES:
		var mat=ShaderMaterial.new()
		mat.shader=SHADER
		mat.set_shader_parameter("material_kind",MODES[key])
		var style=Feedback.profile(key)
		mat.set_shader_parameter("accent",style.color if key not in ["silk","tendril"] else Color("8ee9dc"))
		if key=="repair_drone":mat.set_shader_parameter("accent",Color("82f1d2"))
		if key=="scrap_drone":mat.set_shader_parameter("accent",Color("f7c56b"))
		mat.set_shader_parameter("rate",0.8+float(MODES.keys().find(key))*0.071)
		materials[key]=mat
		for hostile in [false,true]:
			var batch=Batch.new()
			batch.setup(get_canvas_item(),mat,3 if hostile else 1)
			batch.trace=trace_commands
			var painter=Painter.new()
			painter.texture_batch=batch
			painter.batch=batch;painter.source=canvas;painter.shader_family=key
			batches[key+str(hostile)]=painter
			if hostile:hostile_batches[key]=painter
			else:friendly_batches[key]=painter
	var front=Batch.new()
	front.setup(get_canvas_item(),null,2)
	front.trace=trace_commands
	foreground_painter=Painter.new()
	foreground_painter.source=canvas;foreground_painter.batch=front;foreground_painter.texture_batch=front

func begin_frame(time: float):
	frame_time=time
	foreground_painter.batch.clear()
	foreground_painter.current_transform=Transform2D.IDENTITY
	for mat in materials.values():mat.set_shader_parameter("clock",time)
	for painter in batches.values():
		painter.batch.clear()
		painter.current_transform=Transform2D.IDENTITY

static func route(canvas, key: String, hostile: bool = false):
	# Existing test canvases and optional raw-art previews retain their old API.
	if canvas is Painter: return canvas
	if not canvas is Node2D:return canvas
	var layer=canvas.get_meta(&"attack_shader_layer",false)
	if not layer is Node2D:return canvas
	var index: Dictionary = layer.hostile_batches if hostile else layer.friendly_batches
	var painter: Painter = index.get(key)
	if painter==null:painter=index["impact"]
	# A batch may receive many independently transformed effects in one frame.
	painter.draw_set_transform(Vector2.ZERO)
	return painter

func stats()->Dictionary:
	var commands=0
	for painter in batches.values():commands+=painter.batch.command_count
	return {"materials":materials.size(),"batches":batches.size()+1,"commands":commands}

func set_occlusion(rect: Rect2):
	var viewport_size=source.get_viewport_rect().size.max(Vector2.ONE)
	rect=Rect2(rect.position/viewport_size,rect.size/viewport_size)
	if rect==last_occlusion:return
	last_occlusion=rect
	for mat in materials.values():
		mat.set_shader_parameter("occlusion",Vector4(rect.position.x,rect.position.y,rect.size.x,rect.size.y))

static func foreground(canvas):
	if not canvas is Node2D:return canvas
	var layer=canvas.get_meta(&"attack_shader_layer",false)
	if not layer is Node2D:return canvas
	var painter: Painter = layer.foreground_painter
	painter.draw_set_transform(Vector2.ZERO)
	return painter

func _exit_tree():
	for painter in batches.values():painter.batch.dispose()
	if foreground_painter!=null:foreground_painter.batch.dispose()
