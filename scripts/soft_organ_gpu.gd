extends RefCounted
## Retained canvas items deform immutable atlas meshes on the GPU. Used only
## for the player's mounted organs; enemy bodies keep their existing ordering.
const SHADER=preload("res://shaders/soft_organ.gdshader")
const Ink=preload("res://scripts/blue_ink.gd")
var items:Dictionary={}
var geometry:Dictionary={}
var frame=0

func begin_frame():
	frame=0
	for item in items.values():RenderingServer.canvas_item_set_visible(item.rid,false)

func prune(used:Dictionary):
	for key in items.keys():
		if not used.has(key):
			RenderingServer.free_rid(items[key].rid);items.erase(key)
	# Retain only mesh layouts used by surviving organs, not every past loadout.
	var retained:Dictionary={}
	for item in items.values():retained[item.geometry_key]=true
	for key in geometry.keys():
		if not retained.has(key):geometry.erase(key)

func paint(canvas:CanvasItem,key:String,texture:Texture2D,at:Vector2,bounds:Vector2,angle:float,family:int,clock:float,pulse:float,tint:Color,seed:float,activity:float,flame:bool,strain_axis:Vector2,strain:float)->ArrayMesh:
	var extent=Ink.fitted_size(texture,bounds)
	var source=texture.atlas if texture is AtlasTexture else texture
	var region=texture.region if texture is AtlasTexture else Rect2(Vector2.ZERO,texture.get_size())
	var geometry_key=[source.get_rid(),region,source.get_size()]
	if not geometry.has(geometry_key):geometry[geometry_key]=make_mesh(region,source.get_size())
	var mesh:ArrayMesh=geometry[geometry_key]
	if not items.has(key):
		var material=ShaderMaterial.new();material.shader=SHADER
		var rid=RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid,canvas.get_canvas_item())
		RenderingServer.canvas_item_set_material(rid,material.get_rid())
		items[key]={"rid":rid,"material":material,"geometry_key":[],"parameters":{},"transform":Transform2D.IDENTITY,"tint":Color(-1,-1,-1,-1)}
	var item:Dictionary=items[key]
	if item.geometry_key!=geometry_key:
		RenderingServer.canvas_item_clear(item.rid)
		RenderingServer.canvas_item_add_mesh(item.rid,mesh.get_rid(),Transform2D.IDENTITY,Color.WHITE,source.get_rid())
		item.geometry_key=geometry_key;item.source=source
	var transform=Transform2D(angle,at)
	if item.transform!=transform:
		RenderingServer.canvas_item_set_transform(item.rid,transform);item.transform=transform
	if item.tint!=tint:
		RenderingServer.canvas_item_set_modulate(item.rid,tint);item.tint=tint
	if item.parameters.get("extent")!=extent:
		RenderingServer.canvas_item_set_custom_rect(item.rid,true,Rect2(-extent,extent*2))
	var phase=clock+seed*.71
	var age=(.18-clampf(pulse,0,.18))/.18
	var kick=(1-age)*(1-age)*cos(age*PI*1.5) if pulse>0 else 0.0
	set_parameter(item,"extent",extent)
	set_parameter(item,"family",family)
	set_parameter(item,"pose",Vector4(phase,kick,activity,sin(phase*24)*.045 if flame and pulse>0 else 0.0))
	var axis=strain_axis.normalized()
	set_parameter(item,"traction",Vector3(axis.x,axis.y,clampf(strain,-.24,.36)))
	# Match the caller's back-to-front traversal, including after reattachment.
	RenderingServer.canvas_item_set_draw_index(item.rid,frame)
	frame+=1
	RenderingServer.canvas_item_set_visible(item.rid,true)
	return mesh

func set_parameter(item:Dictionary,name:String,value):
	if item.parameters.get(name)==value:return
	item.material.set_shader_parameter(name,value);item.parameters[name]=value

func make_mesh(region:Rect2,source_size:Vector2)->ArrayMesh:
	var vertices=PackedVector3Array();var uvs=PackedVector2Array();var indices=PackedInt32Array()
	for y in 9:
		for x in 9:
			var uv=Vector2(x,y)/8.0
			vertices.append(Vector3(uv.x-.5,uv.y-.5,0))
			uvs.append((region.position+Vector2.ONE*.5+uv*(region.size-Vector2.ONE))/source_size)
	for y in 8:
		for x in 8:
			var a=y*9+x;var b=a+9
			indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _notification(what):
	if what==NOTIFICATION_PREDELETE:
		for item in items.values():RenderingServer.free_rid(item.rid)
