extends Node2D
## Two triangles per original line, with pixel-sized antialiasing in the shader.
## Geometry changes only with rock/damage/view changes, never camera motion.
const SHADER=preload("res://shaders/cave_stroke.gdshader")
var mesh:ArrayMesh
var retired:Array=[]
var width=1.0
var sources:Array=[]

func setup(ink:Color,line_width:float):
	width=line_width
	var surface=ShaderMaterial.new();surface.shader=SHADER
	surface.set_shader_parameter("ink_color",ink);surface.set_shader_parameter("half_width",width*.5)
	material=surface

func set_segments(segments:PackedVector2Array):
	set_buffers([build_buffer(segments,width)])

static func build_buffer(segments:PackedVector2Array,line_width:float)->Dictionary:
	var vertices=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray()
	for i in range(0,segments.size(),2):
		var a:Vector2=segments[i];var b:Vector2=segments[i+1];var delta:Vector2=b-a;var length:float=delta.length()
		if length<0.000001:continue
		var axis:Vector2=delta/length;var side:Vector2=axis.orthogonal();var center:Vector2=(a+b)*.5
		var along:float=length*.5+1.5;var across:float=line_width*.5+1.5
		var code:int=clampi(roundi(length*.5*256),0,65535)
		var encoded:Color=Color(float(code>>8)/255.0,float(code&255)/255.0,0,1)
		for corner:Vector2 in [Vector2(-along,-across),Vector2(along,-across),Vector2(along,across),Vector2(-along,-across),Vector2(along,across),Vector2(-along,across)]:
			var point:Vector2=center+axis*corner.x+side*corner.y
			vertices.append(Vector3(point.x,point.y,0));uvs.append(corner);colors.append(encoded)
	return {"vertices":vertices,"uvs":uvs,"colors":colors}

static func merge_buffers(buffers:Array)->Dictionary:
	var vertices=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray()
	for buffer in buffers:
		vertices.append_array(buffer.vertices);uvs.append_array(buffer.uvs);colors.append_array(buffer.colors)
	return {"vertices":vertices,"uvs":uvs,"colors":colors}

func set_buffers(buffers:Array):
	if sources.size()==buffers.size():
		var unchanged=true
		for i in buffers.size():
			if not is_same(sources[i],buffers[i]):unchanged=false;break
		if unchanged:return
	sources=buffers
	var vertices=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray()
	for buffer in buffers:
		vertices.append_array(buffer.vertices);uvs.append_array(buffer.uvs);colors.append_array(buffer.colors)
	if mesh!=null:retired.append(mesh)
	mesh=null
	if not vertices.is_empty():
		mesh=ArrayMesh.new();var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	queue_redraw()

func _draw():
	if mesh!=null:draw_mesh(mesh,null)
	retired.clear()
