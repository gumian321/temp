extends RefCounted
## Research-only exact native AA tether topology with ordered original points.
const Neck=preload("res://tests/prototypes/neck_gpu_batch.gd")
const CAPACITY=128
var data:Image
var texture:ImageTexture
var shader:Shader
var mesh:ArrayMesh
var groups:Dictionary={}
var count=0
func _init():
	data=Image.create(16,CAPACITY,false,Image.FORMAT_RGBAF);data.fill(Color.TRANSPARENT)
	texture=ImageTexture.create_from_image(data)
	var source=preload("res://shaders/attack_material.gdshader").code
	var declarations=FileAccess.get_file_as_string("res://tests/prototypes/repair_tether_declarations.gdshaderinc")
	var vertex=FileAccess.get_file_as_string("res://tests/prototypes/repair_tether_vertex.gdshaderinc")
	shader=Shader.new();shader.code=source.replace("void vertex(){",declarations+"\nvoid vertex(){\n"+vertex)
	var maker=Neck.new();var original=maker.make_mesh(1.0)
	var arrays=original.surface_get_arrays(0)
	# Native tether lines precede the terminal circle. Neck topology has circle first.
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var first=indices.slice(0,576);indices=indices.slice(576);indices.append_array(first)
	arrays[Mesh.ARRAY_INDEX]=indices
	mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
func setup(materials:Dictionary):
	for material in materials.values():material.shader=shader;material.set_shader_parameter("repair_data",texture)
func begin_frame():
	count=0
	for group in groups.values():group.count=0
func paint(painter,drone:Dictionary,zoom:float,clock:float)->bool:
	if count>=CAPACITY:return false
	var start:Vector2=painter.world(drone.position);var end:Vector2=painter.world(drone.target.position)
	var axis=start.direction_to(end)
	if start.distance_squared_to(end)<1.0:axis=Vector2.from_angle(float(drone.get("angle",0)));start=end-axis*9.0*zoom
	var side=axis.orthogonal()
	for i in 9:
		var t=float(i)/8.0;var point=start.lerp(end,t)+side*sin(t*PI)*sin(clock*7.0-t*5.0)*2.0*zoom
		data.set_pixel(i,count,Color(point.x,point.y,0,0))
	data.set_pixel(9,count,Color(end.x,end.y,2.2*zoom,zoom))
	var parent=painter.batch.rid
	if not groups.has(parent):
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_2D;mm.use_custom_data=true;mm.mesh=mesh
		mm.instance_count=CAPACITY;mm.visible_instance_count=0
		for i in CAPACITY:mm.set_instance_transform_2d(i,Transform2D.IDENTITY)
		mm.custom_aabb=AABB(Vector3(-10000,-10000,-1),Vector3(20000,20000,2))
		groups[parent]={"mm":mm,"count":0}
	var group=groups[parent]
	group.mm.set_instance_custom_data(group.count,Color(count,0,-67,0))
	if group.count==0:painter.draw_set_transform(Vector2.ZERO);painter.draw_multimesh(group.mm,null)
	group.count+=1;count+=1
	return true
func finish():
	texture.update(data)
	for group in groups.values():group.mm.visible_instance_count=group.count
