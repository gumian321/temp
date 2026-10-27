extends RefCounted
## Retain the clock-independent shadow and four AA filaments per exact size.
## The original breathing arc and reward marks remain native drawing commands.
const Geometry=preload("res://scripts/ordered_canvas_geometry.gd")
const Wet=preload("res://scripts/viscous_projectiles.gd")
const Ink=preload("res://scripts/blue_ink.gd")
const MAX_TEMPLATES=128
static var templates:Dictionary={}
static var builds=0
static func mesh_for(size:float)->ArrayMesh:
	if templates.has(size):return templates[size]
	var geometry=Geometry.new()
	var radius=geometry._f32(size*.37)
	geometry.ellipse(Vector2(0,size*.22),radius,radius,Color("11111277"))
	for side in [-1,1]:
		var line=PackedVector2Array()
		for i in 9:
			var t=float(i)/8
			line.append(Vector2(side*size*(.12+.31*t),size*(.15+.16*sin(t*PI))))
		geometry.polyline(line,Color("1b1b1b"),2.4)
		geometry.polyline(line,Color("aaa89c"),.8)
	var vertices=PackedVector3Array();vertices.resize(geometry.points.size())
	for i in vertices.size():vertices[i]=Vector3(geometry.points[i].x,geometry.points[i].y,0)
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=geometry.colors;arrays[Mesh.ARRAY_INDEX]=geometry.indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if templates.size()>=MAX_TEMPLATES:templates.erase(templates.keys()[0])
	templates[size]=mesh;builds+=1
	return mesh
static func paint(canvas,at:Vector2,size:float,clock:float,accent:Color,reward:bool)->bool:
	if not canvas is CanvasItem or not is_finite(size) or size<=0:return false
	# The egg illustration must stay behind all geometry, as in the game's
	# existing ink stream. Generic/custom-material canvases retain the reference.
	var illustrations=canvas.get("ink_world")
	var source=Wet.texture("egg")
	var native_material=canvas.material==null or canvas.get_meta(&"native_canvas_passthrough",null)==canvas.material
	if not illustrations is CanvasItem or not illustrations.show_behind_parent or not native_material or Ink.keeps_color(source):return false
	var breathing=1.0+sin(clock*2.2+at.x*.01)*.025
	var extent=Vector2(size*.95,size*.88)*breathing
	canvas.art(source,at,extent,-PI/2,Color.WHITE)
	# A command-local transform preserves the caller's current drawing state.
	var mesh=mesh_for(size)
	# Canvas commands hold RIDs, not resource references. An eviction during
	# this draw must not free a mesh whose command has already been submitted.
	var epoch=Engine.get_process_frames()
	if canvas.get_meta(&"pod_mesh_epoch",-1)!=epoch:
		canvas.set_meta(&"pod_mesh_epoch",epoch);canvas.set_meta(&"pod_mesh_draw_refs",{})
	var retained:Dictionary=canvas.get_meta(&"pod_mesh_draw_refs")
	retained[mesh.get_rid()]=mesh
	canvas.draw_mesh(mesh,null,Transform2D(0.0,at))
	canvas.draw_arc(at,extent.y*.28,-1.25,1.05,15,Color(accent,.8),1.3,true)
	if reward:
		canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-9),at+Vector2(5,0),at+Vector2(0,9),at+Vector2(-5,0)]),accent)
		canvas.draw_line(at-Vector2(0,5),at+Vector2(0,4),Color("fff4dd"),1.1,true)
	return true
