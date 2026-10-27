extends RefCounted
## Ordered quads sampling the original images and mip chains, without an atlas.
const CAPACITY=512
const MAX_SOURCES=8
const MAX_GROUPS=64
var enabled=OS.get_environment("RBPEW_ENABLE_RADAR_ICON_BATCH")!="0" and OS.get_environment("RBPEW_LEGACY_RADAR_ICON_BATCH")!="1"
var material:ShaderMaterial
var data:Image
var texture:ImageTexture
var mesh:ArrayMesh
var sources:Dictionary={}
var source_refs:Array=[]
var groups:Array=[]
var active:Dictionary={}
var group_cursor=0
var count=0
var dirty=false
var effective_filter=0
var compatible_filter=false
func _init():
	data=Image.create(5,CAPACITY,false,Image.FORMAT_RGBAF);data.fill(Color.TRANSPARENT);texture=ImageTexture.create_from_image(data)
	material=ShaderMaterial.new();material.shader=preload("res://shaders/radar_icon_batch.gdshader");material.set_shader_parameter("icon_data",texture)
	var vertices=PackedVector2Array([Vector2.ZERO,Vector2.DOWN,Vector2.ONE,Vector2.RIGHT])
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=vertices
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,3,0,2]);mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
func begin(canvas):
	count=0;group_cursor=0;active={};dirty=false
	effective_filter=canvas.texture_filter
	var item=canvas
	while effective_filter==CanvasItem.TEXTURE_FILTER_PARENT_NODE:
		item=null if item.is_set_as_top_level() else item.get_parent()
		if not item is CanvasItem:
			effective_filter=int(canvas.get_viewport().canvas_item_default_texture_filter)+1;break
		effective_filter=item.texture_filter
	compatible_filter=effective_filter==CanvasItem.TEXTURE_FILTER_LINEAR
	for group in groups:group.count=0
	if enabled and compatible_filter and (canvas.material==null or canvas.material==material):canvas.material=material
	elif canvas.material==material:canvas.material=null
func interrupt():active={}
func source_slot(source:Texture2D)->int:
	if source==null or source is ViewportTexture:return -1
	if source is AtlasTexture and (source.margin!=Rect2() or source.atlas==null or source.atlas is AtlasTexture):return -1
	var backing:Texture2D=source.atlas if source is AtlasTexture else source
	var rect=source.region if source is AtlasTexture else Rect2(Vector2.ZERO,source.get_size())
	if rect.size.x<=0 or rect.size.y<=0:return -1
	var key=backing.get_rid()
	if sources.has(key):return sources[key]
	# Regions stay per instance. All threat regions share one original backing.
	if sources.size()>=MAX_SOURCES:return -1
	var slot=sources.size();sources[key]=slot;source_refs.append(backing)
	material.set_shader_parameter("source_"+str(slot),backing)
	return slot
func paint(canvas,source:Texture2D,rect:Rect2,tint:Color)->bool:
	if not enabled or not compatible_filter or canvas.material!=material or count>=CAPACITY or rect.size.x<=0 or rect.size.y<=0:return false
	var slot=source_slot(source)
	if slot<0:return false
	if active.is_empty():
		if group_cursor>=MAX_GROUPS:return false
		if group_cursor>=groups.size():
			var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_2D;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=CAPACITY;mm.visible_instance_count=0
			for i in CAPACITY:mm.set_instance_transform_2d(i,Transform2D.IDENTITY)
			groups.append({"mm":mm,"count":0})
		active=groups[group_cursor];group_cursor+=1
		var view=canvas.get_viewport_rect().grow(250)
		active.mm.custom_aabb=AABB(Vector3(view.position.x,view.position.y,-1),Vector3(view.size.x,view.size.y,2))
		canvas.draw_multimesh(active.mm,null)
	data.set_pixel(0,count,Color(rect.position.x,rect.position.y,rect.size.x,rect.size.y))
	data.set_pixel(1,count,tint)
	data.set_pixel(2,count,Color(slot,1 if source is AtlasTexture and source.filter_clip else 0,0,0))
	var backing:Texture2D=source.atlas if source is AtlasTexture else source
	var region=source.region if source is AtlasTexture else Rect2(Vector2.ZERO,source.get_size())
	var origin=region.position/backing.get_size();var extent=region.size/backing.get_size();var inset=Vector2.ONE*.5/backing.get_size()
	data.set_pixel(3,count,Color(origin.x,origin.y,extent.x,extent.y))
	data.set_pixel(4,count,Color(origin.x+inset.x,origin.y+inset.y,origin.x+extent.x-inset.x,origin.y+extent.y-inset.y))
	active.mm.set_instance_custom_data(active.count,Color(count,0,-71,0));active.count+=1;count+=1;dirty=true
	return true
func finish():
	if dirty:texture.update(data);dirty=false
	for group in groups:
		if group.mm.visible_instance_count!=group.count:group.mm.visible_instance_count=group.count
