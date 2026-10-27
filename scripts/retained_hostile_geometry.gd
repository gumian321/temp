extends RefCounted
## Compile the canonical hostile-cue drawing calls once per retained shape.
const Geometry=preload("res://scripts/ordered_canvas_geometry.gd")
var geometry=Geometry.new()
var valid=true
func draw_set_transform(at:Vector2,rotation:float=0.0,scale:Vector2=Vector2.ONE):
	# The retained-shape builder deliberately supplies the identity pose; its
	# existing CanvasItem owns the live projectile transform and ordering.
	if at!=Vector2.ZERO or rotation!=0.0 or scale!=Vector2.ONE:valid=false
func draw_colored_polygon(points:PackedVector2Array,color:Color):
	geometry.polygon(points,color)
func draw_polyline(points:PackedVector2Array,color:Color,width:float=1.0,antialiased:bool=false):
	if not antialiased or width<0:valid=false;return
	geometry.polyline(points,color,width)
func draw_circle(at:Vector2,radius:float,color:Color,filled:bool=true,width:float=-1.0,antialiased:bool=false):
	if not filled or not antialiased:valid=false;return
	var native_radius=geometry._f32(radius)
	geometry.ellipse(at,native_radius,native_radius,color)
func draw_arc(at:Vector2,radius:float,from:float,to:float,count:int,color:Color,width:float=1.0,antialiased:bool=false):
	# Match AttackShaderLayer.Painter's existing GDScript point sampling, which
	# differs slightly from CanvasItem.draw_arc's native float32 sampling.
	var points=PackedVector2Array();points.resize(count)
	var span=clampf(to-from,-TAU,TAU)
	for i in count:points[i]=at+Vector2.from_angle(from+span*float(i)/float(count-1))*radius
	draw_polyline(points,color,width,antialiased)
func submit(painter):
	painter.draw_triangle_array(geometry.indices,geometry.points,geometry.colors)
func make_mesh()->ArrayMesh:
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=geometry.points
	arrays[Mesh.ARRAY_COLOR]=geometry.colors
	arrays[Mesh.ARRAY_INDEX]=geometry.indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
