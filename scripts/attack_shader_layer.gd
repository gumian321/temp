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
var retained_projectiles:Dictionary={}
var projectile_pool:Dictionary={}
var pooled_projectiles=0
var projectile_geometry_builds=0
var projectile_order=0
var use_retained_projectiles=OS.get_environment("RBPEW_LEGACY_BULLET_DRAW")!="1"
const MAX_POOLED_PROJECTILES=96
var muzzle_batch=preload("res://scripts/muzzle_batch.gd").new()
var use_muzzle_batch=OS.get_environment("RBPEW_LEGACY_MUZZLE_DRAW")!="1"
var batch_muzzles_this_frame=false
var flight_batch=preload("res://scripts/flight_batch.gd").new()
var use_flight_batch=OS.get_environment("RBPEW_LEGACY_FLIGHT_BATCH")!="1"
var batch_flights_this_frame=false

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
	static var circles:Dictionary={}
	var batch: Batch
	var source: Node2D
	var shader_family: String
	var owner_layer:Node2D
	var flight_open=false
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
		if flight_open:owner_layer.flight_batch.interrupt(self)
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
		if flight_open:owner_layer.flight_batch.interrupt(self)
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_line"])
		RenderingServer.canvas_item_add_line(batch.rid,a,b,color,width,antialiased)
	func draw_circle(at: Vector2,radius: float,color: Color,filled: bool = true,width: float = -1.0,antialiased: bool = false):
		if flight_open:owner_layer.flight_batch.interrupt(self)
		if not filled:
			draw_arc(at,radius,0.0,TAU,maxi(32,int(radius*2.0)),color,width,antialiased)
			return
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_circle"])
		RenderingServer.canvas_item_add_circle(batch.rid,at,radius,color,antialiased)
	func draw_polygon(points,colors,uvs=PackedVector2Array(),texture=null):
		if flight_open:owner_layer.flight_batch.interrupt(self)
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_polygon"])
		RenderingServer.canvas_item_add_polygon(batch.rid,points,colors,uvs,texture.get_rid() if texture!=null else RID())
	func draw_triangle_array(indices: PackedInt32Array, points: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array = PackedVector2Array()):
		if flight_open:owner_layer.flight_batch.interrupt(self)
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_triangle_array"])
		RenderingServer.canvas_item_add_triangle_array(batch.rid,indices,points,colors,uvs)
	func draw_colored_polygon(points: PackedVector2Array,color: Color):
		if flight_open:owner_layer.flight_batch.interrupt(self)
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_colored_polygon"])
		RenderingServer.canvas_item_add_polygon(batch.rid,points,PackedColorArray([color]))
	func draw_multimesh(multimesh:MultiMesh,texture:Texture2D=null,flight:bool=false):
		if not flight and flight_open:owner_layer.flight_batch.interrupt(self)
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_multimesh"])
		RenderingServer.canvas_item_add_multimesh(batch.rid,multimesh.get_rid(),texture.get_rid() if texture!=null else RID())
	func draw_polyline(points: PackedVector2Array,color: Color,width: float = 1.0,antialiased: bool = false):
		if flight_open:owner_layer.flight_batch.interrupt(self)
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_polyline"])
		RenderingServer.canvas_item_add_polyline(batch.rid,points,PackedColorArray([color]),width,antialiased)
	func draw_polyline_colors(points: PackedVector2Array,colors: PackedColorArray,width: float = 1.0,antialiased: bool = false):
		if flight_open:owner_layer.flight_batch.interrupt(self)
		batch.command_count+=1
		if batch.trace:batch.commands.append([&"draw_polyline_colors"])
		RenderingServer.canvas_item_add_polyline(batch.rid,points,colors,width,antialiased)
	func draw_arc(at,radius,from,to,count,color,width=1.0,antialiased=false):
		if flight_open:owner_layer.flight_batch.interrupt(self)
		if count<2:return
		var points:PackedVector2Array
		if from==0.0 and to==TAU and count<=512:
			if not circles.has(count):
				if circles.size()>=64:circles.erase(circles.keys()[0])
				var circle=PackedVector2Array();circle.resize(count)
				for i in count:circle[i]=Vector2.from_angle(TAU*float(i)/float(count-1))
				circles[count]=circle
			# Preserve every original point and AA setting. Transforming the
			# cached unit arc runs natively instead of 44 trig calls per egg.
			points=Transform2D(0.0,Vector2.ONE*radius,0.0,at)*circles[count]
		else:
			points=PackedVector2Array();points.resize(count)
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
		mat.set_shader_parameter("muzzle_color",style.color)
		mat.set_shader_parameter("muzzle_accent",style.accent)
		mat.set_shader_parameter("muzzle_weight",float(style.weight))
		mat.set_shader_parameter("muzzle_husk",key in ["gatling","shotgun","cannon","flak"])
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
			painter.owner_layer=self
			batches[key+str(hostile)]=painter
			if hostile:hostile_batches[key]=painter
			else:friendly_batches[key]=painter
	var front=Batch.new()
	front.setup(get_canvas_item(),null,2)
	front.trace=trace_commands
	foreground_painter=Painter.new()
	foreground_painter.source=canvas;foreground_painter.batch=front;foreground_painter.texture_batch=front
	muzzle_batch.setup(materials)
	flight_batch.setup(materials)

func begin_frame(time: float):
	batch_muzzles_this_frame=false
	batch_flights_this_frame=false;flight_batch.begin_frame()
	muzzle_batch.begin_frame();queue_redraw()
	projectile_order=0
	# Static cell membranes/nuclei retain their exact native drawing commands.
	# Only transforms move; hiding unseen items also handles radar/pause switches.
	for id in retained_projectiles.keys():
		var entry:Dictionary=retained_projectiles[id]
		if not entry.used:
			retained_projectiles.erase(id)
			if pooled_projectiles<MAX_POOLED_PROJECTILES:
				if not projectile_pool.has(entry.shape):projectile_pool[entry.shape]=[]
				projectile_pool[entry.shape].append(entry);pooled_projectiles+=1
			else:entry.painter.batch.dispose()
		else:
			entry.used=false
	frame_time=time
	foreground_painter.batch.clear()
	foreground_painter.current_transform=Transform2D.IDENTITY
	for mat in materials.values():mat.set_shader_parameter("clock",time)
	for painter in batches.values():
		painter.flight_open=false
		painter.batch.clear()
		painter.current_transform=Transform2D.IDENTITY

func paint_retained_projectile(painter:Painter,id:int,cue:Dictionary,at:Vector2,heading:float,build:Callable)->bool:
	if not use_retained_projectiles or trace_commands or id<=0:return false
	var entry:Dictionary=retained_projectiles.get(id,{})
	var extent:Vector2=cue.size
	if not entry.is_empty() and (entry.family!=painter.shader_family or entry.extent!=extent):
		entry.painter.batch.dispose();retained_projectiles.erase(id);entry={}
	if entry.is_empty():
		var shape=[painter.shader_family,extent]
		var pool:Array=projectile_pool.get(shape,[])
		if not pool.is_empty():
			entry=pool.pop_back();pooled_projectiles-=1
			if pool.is_empty():projectile_pool.erase(shape)
		else:
			var batch=Batch.new();batch.setup(painter.batch.rid,painter.batch.material,0)
			var cached=Painter.new();cached.batch=batch;cached.texture_batch=batch;cached.source=source
			build.call(cached,Vector2.ZERO,0.0,cue)
			entry={"painter":cached,"shape":shape,"family":painter.shader_family,"extent":extent,"transform":Transform2D.IDENTITY,"used":false,"visible":true,"order":-1}
			projectile_geometry_builds+=1
		retained_projectiles[id]=entry
	var transform=Transform2D(heading,at)
	if entry.transform!=transform:
		RenderingServer.canvas_item_set_transform(entry.painter.batch.rid,transform);entry.transform=transform
	entry.used=true
	if entry.order!=projectile_order:RenderingServer.canvas_item_set_draw_index(entry.painter.batch.rid,projectile_order);entry.order=projectile_order
	projectile_order+=1
	if not entry.visible:RenderingServer.canvas_item_set_visible(entry.painter.batch.rid,true);entry.visible=true
	return true

func end_frame():
	muzzle_batch.end_frame()
	flight_batch.end_frame()
	for entry in retained_projectiles.values():
		if not entry.used and entry.visible:RenderingServer.canvas_item_set_visible(entry.painter.batch.rid,false);entry.visible=false

func _draw():end_frame()

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
	return {"materials":materials.size(),"batches":batches.size()+1,"commands":commands,"retained_projectiles":retained_projectiles.size(),"pooled_projectiles":pooled_projectiles,"projectile_geometry_builds":projectile_geometry_builds}

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
	flight_batch.dispose()
	muzzle_batch.dispose()
	for entry in retained_projectiles.values():entry.painter.batch.dispose()
	for pool in projectile_pool.values():
		for entry in pool:entry.painter.batch.dispose()
	retained_projectiles.clear();projectile_pool.clear()
	for painter in batches.values():painter.batch.dispose()
	if foreground_painter!=null:foreground_painter.batch.dispose()
