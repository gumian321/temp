extends RefCounted
## Experimental only. Matched start/end pairs and a uniform two-color palette.
## Native framebuffer rounding between the two strokes is not assumed equal:
## test_ordered_aa_stroke_mesh must establish the measured error first.
var instances=MultiMesh.new()
var material=ShaderMaterial.new()
var capacity=0

func _init():
	var mesh=QuadMesh.new();mesh.size=Vector2.ONE
	instances.transform_format=MultiMesh.TRANSFORM_2D;instances.use_custom_data=true;instances.mesh=mesh
	material.shader=preload("res://tests/prototypes/ordered_aa_pair.gdshader")

func native_color(value:Color)->Color:
	# GLES3's native CommandPrimitive uploads RGBA as half-float instance data;
	# material uniforms otherwise retain full float precision before blending.
	var bytes=PackedByteArray();bytes.resize(8)
	for i in 4:bytes.encode_half(i*2,value[i])
	return Color(bytes.decode_half(0),bytes.decode_half(2),bytes.decode_half(4),bytes.decode_half(6))

func prepare(strokes:Array,separate:bool=false)->bool:
	if strokes.size()%2!=0 or strokes.is_empty():return false
	var outer:Color=strokes[0][2];var inner:Color=strokes[1][2]
	for i in range(0,strokes.size(),2):
		if strokes[i][0]!=strokes[i+1][0] or strokes[i][1]!=strokes[i+1][1] or strokes[i][2]!=outer or strokes[i+1][2]!=inner:return false
		if float(strokes[i][3])<=0 or float(strokes[i+1][3])<=0 or float(strokes[i+1][3])>float(strokes[i][3]):return false
	material.set_shader_parameter("outer_ink",native_color(outer));material.set_shader_parameter("inner_ink",native_color(inner))
	material.set_shader_parameter("separate_layers",separate)
	var count=strokes.size() if separate else strokes.size()/2
	if count!=capacity:instances.instance_count=count;capacity=count
	for i in count:
		var index=i if separate else i*2
		var start:Vector2=strokes[index][0];var finish:Vector2=strokes[index][1]
		var width=float(strokes[index][3]);var inner_width=width if separate else float(strokes[index+1][3])
		var span=finish-start;var length=span.length();var direction=span.normalized()
		var feather=1.25*minf(1,width)
		var transform=Transform2D(direction*(length+feather*2),direction.orthogonal()*(width+feather*2),(start+finish)*.5)
		instances.set_instance_transform_2d(i,transform)
		instances.set_instance_custom_data(i,Color(length,width,inner_width,i%2 if separate else 0))
	instances.visible_instance_count=count
	instances.custom_aabb=AABB(Vector3(-10000,-10000,-1),Vector3(20000,20000,2))
	return true
