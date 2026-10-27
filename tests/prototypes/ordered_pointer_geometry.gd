extends RefCounted
## Experiment only: ordered arrow geometry from boss_direction.paint.
const Geometry=preload("res://tests/prototypes/ordered_pod_geometry.gd")
var template:ArrayMesh
var transient:Array=[]
var builds=0
func make(at:Vector2,direction:Vector2)->ArrayMesh:
	var side=direction.orthogonal()
	var tip=at+direction*12
	var base=at-direction*14
	var outline=PackedVector2Array([tip,base+side*9,base+direction*6,base-side*9,tip])
	var geometry=Geometry.new()
	geometry.polygon(outline,Color("121212"))
	geometry.polyline(outline,Color("d7d3c3"),1.4)
	geometry.aa_line(base+direction*8,tip-direction*3,Color("ff387c"),2.0)
	var gem=base-direction*12
	geometry.polygon(PackedVector2Array([gem+direction*6,gem+side*4,gem-direction*6,gem-side*4]),Color("ff387c"))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=geometry.points;arrays[Mesh.ARRAY_COLOR]=geometry.colors;arrays[Mesh.ARRAY_INDEX]=geometry.indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	builds+=1
	return mesh
func begin():transient.clear()
func paint(canvas:CanvasItem,at:Vector2,direction:Vector2,absolute:bool=false):
	if absolute:
		var mesh=make(at,direction);transient.append(mesh);canvas.draw_mesh(mesh,null)
	else:
		if template==null:template=make(Vector2.ZERO,Vector2.RIGHT)
		canvas.draw_mesh(template,null,Transform2D(direction,-direction.orthogonal(),at))
