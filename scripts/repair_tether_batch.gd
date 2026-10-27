extends RefCounted
## Ordered original repair points; native AA topology reconstructed in the shared attack material.
const Neck=preload("res://scripts/neck_geometry_batch.gd")
const CAPACITY=128
var data:Image
var texture:ImageTexture
var mesh:ArrayMesh
var groups:Dictionary={}
var count=0
var dirty=false
var enabled=OS.get_environment("RBPEW_ENABLE_REPAIR_TETHER_BATCH")!="0" and OS.get_environment("RBPEW_LEGACY_REPAIR_TETHER_BATCH")!="1"
func _init():
	data=Image.create(16,CAPACITY,false,Image.FORMAT_RGBAF);data.fill(Color.TRANSPARENT)
	texture=ImageTexture.create_from_image(data)
	var original=Neck.make_mesh(1.0)
	var arrays=original.surface_get_arrays(0)
	# Native tether lines precede the terminal circle. Neck topology has circle first.
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var first=indices.slice(0,576);indices=indices.slice(576);indices.append_array(first)
	arrays[Mesh.ARRAY_INDEX]=indices
	mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
func setup(materials:Dictionary):
	for material in materials.values():material.set_shader_parameter("repair_data",texture)
func begin_frame():
	count=0
	for group in groups.values():group.count=0
func paint(painter,drone:Dictionary,zoom:float,clock:float)->bool:
	if not enabled or count>=CAPACITY or not is_finite(zoom) or zoom<.23:return false
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
	group.count+=1;count+=1;dirty=true
	return true
func finish():
	if dirty:texture.update(data);dirty=false
	for group in groups.values():
		if group.mm.visible_instance_count!=group.count:group.mm.visible_instance_count=group.count
func dispose():groups.clear()
