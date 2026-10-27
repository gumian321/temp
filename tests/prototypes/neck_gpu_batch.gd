extends RefCounted
## Prototype: original nine curve points, original ordered AA strip topology.
const Geometry=preload("res://scripts/ordered_canvas_geometry.gd")
const Ink=preload("res://scripts/blue_ink.gd")
const CAPACITY=128
var material:ShaderMaterial
var data:Image
var texture:ImageTexture
var instances:MultiMesh
var mesh_zoom=-1.0
var count=0
func _init():
	data=Image.create(16,CAPACITY,false,Image.FORMAT_RGBAF);data.fill(Color.TRANSPARENT)
	texture=ImageTexture.create_from_image(data)
	material=ShaderMaterial.new();material.shader=preload("res://tests/prototypes/neck_gpu_batch.gdshader")
	material.set_shader_parameter("neck_data",texture)
	instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_2D;instances.use_custom_data=true
	instances.instance_count=CAPACITY;instances.visible_instance_count=0
	for i in CAPACITY:
		instances.set_instance_transform_2d(i,Transform2D.IDENTITY)
		instances.set_instance_custom_data(i,Color(i,0,0,0))
	instances.custom_aabb=AABB(Vector3(-10000,-10000,-1),Vector3(20000,20000,2))
func begin(zoom:float):
	count=0
	if mesh_zoom!=zoom:instances.mesh=make_mesh(zoom);mesh_zoom=zoom
func append(anchor:Vector2,tip:Vector2,radius:float,zoom:float,alpha:float):
	if count>=CAPACITY:return false
	var bend=(tip-anchor).orthogonal().normalized()*minf(5.0*zoom,anchor.distance_to(tip)*.22)
	for step in 9:
		var t=float(step)/8.0
		var point=anchor.lerp(tip,t)+bend*sin(t*PI)
		data.set_pixel(step,count,Color(point.x,point.y,0,0))
	data.set_pixel(9,count,Color(anchor.x,anchor.y,radius,zoom))
	data.set_pixel(10,count,Color(alpha*.7,alpha*.8,alpha,0))
	count+=1;return true
func finish():texture.update(data);instances.visible_instance_count=count
func strip(points:PackedVector2Array,uvs:PackedVector2Array,vertices:PackedVector2Array,tex:PackedVector2Array,indices:PackedInt32Array):
	var base=vertices.size();vertices.append_array(points);tex.append_array(uvs)
	for i in range(2,points.size()):
		if i%2==0:indices.append_array(PackedInt32Array([base+i-2,base+i-1,base+i]))
		else:indices.append_array(PackedInt32Array([base+i-1,base+i-2,base+i]))
func make_mesh(_zoom:float)->ArrayMesh:
	# Circle offsets are generated with the native float32 trigonometry once.
	var circle=Geometry.new();circle.ellipse(Vector2.ZERO,1,1,Color.WHITE)
	var vertices=PackedVector2Array();var tex=PackedVector2Array();var indices=PackedInt32Array()
	# Store circle unit radius in x/y, fill/feather flag in UV.x.
	for i in circle.points.size():
		vertices.append(circle.points[i]);tex.append(Vector2(1 if i>=66 and (i-66)%2==1 else 0,0))
	indices.append_array(circle.indices)
	# Feather vertices need their native unit angle rather than 2.25 radius.
	for i in range(66,vertices.size()):
		if (i-66)%2==1:vertices[i]=vertices[i-1]
	for stage in [1,2]:
		var points=PackedVector2Array();var uv=PackedVector2Array()
		for side in [1,-1]:points.append(Vector2(0,side));uv.append(Vector2(-1,stage))
		for i in 9:
			for side in [1,-1]:points.append(Vector2(i,side));uv.append(Vector2(0,stage))
		for side in [1,-1]:points.append(Vector2(8,side));uv.append(Vector2(1,stage))
		strip(points,uv,vertices,tex,indices)
		for side in [1,-1]:
			points=PackedVector2Array([Vector2(0,side),Vector2(0,side)])
			uv=PackedVector2Array([Vector2(-1,stage),Vector2(2,stage)])
			for i in 9:
				points.append(Vector2(i,side));points.append(Vector2(i,side))
				uv.append(Vector2(0,stage));uv.append(Vector2(3,stage))
			points.append_array(PackedVector2Array([Vector2(8,side),Vector2(8,side),Vector2(8,side)]))
			uv.append_array(PackedVector2Array([Vector2(0,stage),Vector2(4,stage),Vector2(1,stage)]))
			strip(points,uv,vertices,tex,indices)
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=tex;arrays[Mesh.ARRAY_INDEX]=indices
	var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return result
