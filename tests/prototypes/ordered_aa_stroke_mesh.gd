extends RefCounted
## Experimental only. Production flagella never loads this script.
## Independently expressed geometry matching Godot 4.6.3's positive-width AA
## line topology, including its square feathered corners and primitive order:
## https://github.com/godotengine/godot/blob/4.6.3-stable/servers/rendering/renderer_canvas_cull.cpp#L665-L835
## Native GLES3 quad triangulation is (0,1,2), (0,2,3). No inter-line sorting.
const VERTICES_PER_STROKE=36
const FEATHER=1.25
var mesh=ArrayMesh.new()
var vertices=PackedVector3Array()
var colors=PackedColorArray()
var indices=PackedInt32Array()
var cursor=0
var topology_changed=true
var update_colors=true
var geometry_builds=0
var vertex_updates=0

func begin(strokes:int,styles_changed:bool=true):
	cursor=0;update_colors=styles_changed
	var size=strokes*VERTICES_PER_STROKE
	topology_changed=vertices.size()!=size
	if not topology_changed:return
	update_colors=true;vertices.resize(size);colors.resize(size);indices.resize(strokes*54)
	for quad in strokes*9:
		var base=quad*4;var offset=quad*6
		indices[offset]=base;indices[offset+1]=base+1;indices[offset+2]=base+2
		indices[offset+3]=base;indices[offset+4]=base+2;indices[offset+5]=base+3

func quad(a:Vector2,b:Vector2,c:Vector2,d:Vector2,ink:Color,coverage:Vector4):
	vertices[cursor]=Vector3(a.x,a.y,0);vertices[cursor+1]=Vector3(b.x,b.y,0)
	vertices[cursor+2]=Vector3(c.x,c.y,0);vertices[cursor+3]=Vector3(d.x,d.y,0)
	if update_colors:
		colors[cursor]=Color(ink,ink.a*coverage.x);colors[cursor+1]=Color(ink,ink.a*coverage.y)
		colors[cursor+2]=Color(ink,ink.a*coverage.z);colors[cursor+3]=Color(ink,ink.a*coverage.w)
	cursor+=4

func stroke(start:Vector2,finish:Vector2,ink:Color,width:float):
	assert(width>=0,"Prototype supports the positive widths used by flagella")
	var backwards=start-finish
	var normal=backwards.orthogonal().normalized()
	var half=normal*width*.5
	var a=start+half;var b=start-half;var c=finish-half;var d=finish+half
	var feather=FEATHER*minf(1,width)
	var lateral=normal*feather;var cap=backwards.normalized()*feather
	var edge=Vector4(1,0,0,1);var corner=Vector4(1,0,0,0)
	# Each complete stroke precedes the next stroke: centre, four sides, corners.
	quad(a,b,c,d,ink,Vector4.ONE)
	quad(a,a+lateral,d+lateral,d,ink,edge)
	quad(b,b-lateral,c-lateral,c,ink,edge)
	quad(a,a+cap,b+cap,b,ink,edge)
	quad(d,d-cap,c-cap,c,ink,edge)
	quad(a,a+cap,a+lateral+cap,a+lateral,ink,corner)
	quad(b,b+cap,b-lateral+cap,b-lateral,ink,corner)
	quad(d,d-cap,d+lateral-cap,d+lateral,ink,corner)
	quad(c,c-cap,c-lateral-cap,c-lateral,ink,corner)

func finish():
	assert(cursor==vertices.size(),"Every reserved stroke must be submitted")
	if vertices.is_empty():mesh.clear_surfaces();return
	if topology_changed or update_colors or mesh.get_surface_count()==0:
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
		mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		geometry_builds+=1
	else:
		mesh.surface_update_vertex_region(0,0,vertices.to_byte_array());vertex_updates+=1
	# Conservative prototype bounds; no clipped feather, cap, or self-crossing.
	mesh.custom_aabb=AABB(Vector3(-10000,-10000,-1),Vector3(20000,20000,2))

func triangle_points()->PackedVector2Array:
	var result=PackedVector2Array();result.resize(vertices.size())
	for i in vertices.size():result[i]=Vector2(vertices[i].x,vertices[i].y)
	return result
