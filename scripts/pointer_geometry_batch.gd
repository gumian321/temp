extends RefCounted
## One retained boss-pointer template, with unchanged native triangle order.
## The command-local basis rotates it without changing the caller's draw state.
const Geometry=preload("res://scripts/ordered_canvas_geometry.gd")
static var template:ArrayMesh
static var builds=0
static func mesh_for()->ArrayMesh:
	if template!=null:return template
	var at=Vector2.ZERO;var direction=Vector2.RIGHT;var side=direction.orthogonal()
	var tip=at+direction*12;var base=at-direction*14
	var outline=PackedVector2Array([tip,base+side*9,base+direction*6,base-side*9,tip])
	var geometry=Geometry.new()
	geometry.polygon(outline,Color("121212"))
	geometry.polyline(outline,Color("d7d3c3"),1.4)
	geometry.aa_line(base+direction*8,tip-direction*3,Color("ff387c"),2.0)
	var gem=base-direction*12
	geometry.polygon(PackedVector2Array([gem+direction*6,gem+side*4,gem-direction*6,gem-side*4]),Color("ff387c"))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=geometry.points;arrays[Mesh.ARRAY_COLOR]=geometry.colors;arrays[Mesh.ARRAY_INDEX]=geometry.indices
	template=ArrayMesh.new();template.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	builds+=1
	return template
static func paint(canvas:CanvasItem,at:Vector2,direction:Vector2):
	# This single static reference owns the mesh for all recorded canvas RIDs.
	canvas.draw_mesh(mesh_for(),null,Transform2D(direction,-direction.orthogonal(),at))
