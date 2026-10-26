extends RefCounted
## Same five ink tongues, halo and shed husk as weapon_fx; one instanced draw
## per material replaces repeated polygon construction for every discharge.
const CAPACITY=256
var image_data:Image
var texture_data:ImageTexture
var mesh:ArrayMesh
var batches:Dictionary={}
var materials:Dictionary
var count=0
var halo:Texture2D
var dirty=false

func setup(shared_materials:Dictionary):
	materials=shared_materials
	image_data=Image.create(64,16,false,Image.FORMAT_RGBAF);image_data.fill(Color(0,0,0,0))
	texture_data=ImageTexture.create_from_image(image_data);mesh=make_mesh()
	for material in materials.values():material.set_shader_parameter("muzzle_data",texture_data)

func begin_frame():
	count=0
	for batch in batches.values():batch.count=0

func enqueue(painter,effect:Dictionary,zoom:float,source_halo:Texture2D)->bool:
	if count>=CAPACITY:return false
	if halo!=source_halo:
		halo=source_halo
		for material in materials.values():material.set_shader_parameter("muzzle_halo",halo)
	var key=painter.batch.rid
	if not batches.has(key):
		var instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_2D;instances.use_custom_data=true;instances.mesh=mesh
		instances.instance_count=CAPACITY;instances.visible_instance_count=0
		for i in CAPACITY:instances.set_instance_transform_2d(i,Transform2D.IDENTITY)
		var rid=RenderingServer.canvas_item_create();RenderingServer.canvas_item_set_parent(rid,key)
		RenderingServer.canvas_item_set_material(rid,painter.batch.material.get_rid())
		RenderingServer.canvas_item_set_draw_index(rid,-1)
		RenderingServer.canvas_item_add_multimesh(rid,instances.get_rid())
		batches[key]={"rid":rid,"instances":instances,"count":0,"visible_count":0,"viewport":Rect2()}
	var batch:Dictionary=batches[key]
	var duration=float(effect.get("fx_duration",.15));var age=clampf(duration-float(effect.life),0,duration)
	var progress=age/maxf(duration,.001)
	var size=clampf(float(effect.get("visual_scale",1)),.55,1)*zoom
	var at:Vector2=painter.world(effect.position);var direction=Vector2(effect.direction).normalized()
	var seed=float(effect.position.x)*.03+float(effect.position.y)*.017
	write_data(count*3,Color(progress,age,size,seed))
	write_data(count*3+1,Color(at.x,at.y,direction.x,direction.y))
	write_data(count*3+2,Color(1 if effect.get("friendly",true) else 0,0,0,0))
	batch.instances.set_instance_custom_data(batch.count,Color(count,0,0,0))
	batch.count+=1;count+=1;dirty=true
	var viewport:Rect2=painter.get_viewport_rect().grow(500)
	if batch.viewport!=viewport:RenderingServer.canvas_item_set_custom_rect(batch.rid,true,viewport);batch.viewport=viewport
	return true

func write_data(index:int,value:Color):image_data.set_pixel(index%64,index/64,value)
func end_frame():
	if dirty:texture_data.update(image_data);dirty=false
	for batch in batches.values():
		if batch.visible_count!=batch.count:batch.instances.visible_instance_count=batch.count;batch.visible_count=batch.count

func make_mesh()->ArrayMesh:
	var points=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
	var ribbon=PackedVector2Array([Vector2(0,-.25),Vector2(.65,-.5),Vector2(1,0),Vector2(.65,.5),Vector2(0,.25)])
	for part in 7:
		var shape=PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]) if part==0 else (PackedVector2Array([Vector2(0,-1),Vector2(1,-1),Vector2(1,1),Vector2(0,1)]) if part==6 else ribbon)
		var offset=points.size()
		for point in shape:points.append(Vector3(point.x,point.y,0));uv.append(Vector2(part,20))
		for i in range(1,shape.size()-1):indices.append_array(PackedInt32Array([offset,offset+i,offset+i+1]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return result

func dispose():
	for batch in batches.values():RenderingServer.free_rid(batch.rid)
	batches.clear()
