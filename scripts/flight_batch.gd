extends RefCounted
## Ordered instances of the existing flight strips and illustrated bodies.
## Commands are inserted into the original material stream, so support trails,
## live shots, remnants and effects keep their original relative order.
const CAPACITY=768
const WIDTH=32
const MAX_GROUPS=96
var enabled=true
var materials:Dictionary
var image_data:Image
var texture_data:ImageTexture
var mesh:ArrayMesh
var entries:Dictionary={}
var free_slots:Array=[]
var groups:Dictionary={}
var current_groups:Dictionary={}
var serials:Dictionary={}
var dirty=false
var submitted=0
var identity_buffer=PackedFloat32Array()

func setup(shared_materials:Dictionary):materials=shared_materials

func initialize():
	if image_data!=null:return
	image_data=Image.create(WIDTH,CAPACITY,false,Image.FORMAT_RGBAF);image_data.fill(Color(0,0,0,0))
	texture_data=ImageTexture.create_from_image(image_data);mesh=make_mesh()
	for material in materials.values():material.set_shader_parameter("flight_data",texture_data)
	for slot in range(CAPACITY-1,-1,-1):free_slots.append(slot)

func begin_frame():
	submitted=0;current_groups.clear();serials.clear()
	for id in entries.keys():
		var entry:Dictionary=entries[id]
		if not entry.used:free_slots.append(entry.slot);entries.erase(id)
		else:entry.used=false
	for group in groups.values():group.count=0

func interrupt(painter):
	var channel=painter.batch.rid
	painter.flight_open=false
	current_groups.erase(channel);serials[channel]=int(serials.get(channel,0))+1

func enqueue(painter,state:Dictionary,trail:Dictionary,origin:Vector2,scale_factor:float,body:Dictionary={},kind:String="remnant")->bool:
	if not enabled or int(state.get("visual_id",0))<=0:return false
	initialize()
	# A preview/support cue can reuse a live state later in the same frame.
	# Keep its command payload independent of the live illustrated body.
	var id=[int(state.visual_id),kind]
	if not entries.has(id):
		if free_slots.is_empty():
			# Only commands already submitted this frame own their payload slots.
			for retired in entries.keys():
				if not entries[retired].used:free_slots.append(entries[retired].slot);entries.erase(retired)
				if free_slots.size()>=32:break
		if free_slots.is_empty():return false
		entries[id]={"slot":free_slots.pop_back(),"mesh":{},"head":Vector2.INF,"body":{},"used":false}
	var entry:Dictionary=entries[id]
	var source:Texture2D=body.get("source")
	var atlas:Texture2D=source.atlas if source is AtlasTexture else null
	var channel=painter.batch.rid
	var texture_id=atlas.get_rid() if atlas!=null else RID()
	var active:Dictionary=current_groups.get(channel,{})
	if active.is_empty() or active.texture!=texture_id or active.kind!=kind:
		serials[channel]=int(serials.get(channel,0))+1
		var key=[channel,int(serials[channel]),texture_id,kind]
		if not groups.has(key):
			if groups.size()>=MAX_GROUPS:return false
			var instances=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_2D;instances.use_custom_data=true;instances.mesh=mesh
			instances.instance_count=CAPACITY;instances.visible_instance_count=0
			if identity_buffer.is_empty():
				instances.set_instance_transform_2d(0,Transform2D.IDENTITY)
				identity_buffer=instances.buffer
				var stride=identity_buffer.size()/CAPACITY
				for offset in stride:
					if identity_buffer[offset]!=0:
						for i in range(1,CAPACITY):identity_buffer[i*stride+offset]=identity_buffer[offset]
			instances.buffer=identity_buffer
			groups[key]={"instances":instances,"texture":texture_id,"source":atlas,"kind":kind,"count":0,"visible_count":0}
		active=groups[key];current_groups[channel]=active
		var bounds:Rect2=painter.get_viewport_rect().grow(500)
		active.instances.custom_aabb=AABB(Vector3((bounds.position.x-origin.x)/scale_factor,(bounds.position.y-origin.y)/scale_factor,0),Vector3(bounds.size.x/scale_factor,bounds.size.y/scale_factor,1))
		painter.draw_set_transform(origin,0,Vector2.ONE*scale_factor)
		painter.draw_multimesh(active.instances,atlas,true)
		painter.draw_set_transform(Vector2.ZERO)
	if active.count>=CAPACITY:return false
	entry.used=true
	var slot=int(entry.slot)
	if not is_same(entry.mesh,trail):
		entry.mesh=trail
		if int(trail.segments)>0:
			for i in int(trail.segments)+1:
				var at:Vector2=trail.vertices[i*3];var encoded:Color=trail.colors[i*3]
				image_data.set_pixel(4+i*2,slot,Color(at.x,at.y,encoded.r,encoded.g))
				image_data.set_pixel(5+i*2,slot,Color(encoded.b,encoded.a,0,0))
		entry.head=Vector2.INF
	if entry.head!=Vector2(state.position):
		image_data.set_pixel(0,slot,Color(state.position.x,state.position.y,float(trail.segments),1 if state.friendly else 0));entry.head=state.position;dirty=true
	if not body.is_empty():
		var size:Vector2=body.size/scale_factor;var heading=float(body.heading)
		var value=Vector3(size.x,size.y,heading)
		if entry.body.get("pose")!=value or entry.body.get("source")!=source:
			image_data.set_pixel(1,slot,Color(size.x,size.y,heading,1))
			var region:Rect2=source.region;var native=atlas.get_size()
			image_data.set_pixel(2,slot,Color(region.position.x/native.x,region.position.y/native.y,region.size.x/native.x,region.size.y/native.y))
			entry.body={"pose":value,"source":source};dirty=true
	elif not entry.body.is_empty():
		image_data.set_pixel(1,slot,Color(0,0,0,0));entry.body.clear();dirty=true
	else:
		# A slot can be reused after a different illustrated projectile retired.
		image_data.set_pixel(1,slot,Color(0,0,0,0));dirty=true
	active.instances.set_instance_custom_data(active.count,Color(slot,0,-29,0))
	active.count+=1;submitted+=1
	painter.flight_open=true
	return true

func end_frame():
	if dirty:texture_data.update(image_data);dirty=false
	for group in groups.values():
		if group.count!=group.visible_count:group.instances.visible_instance_count=group.count;group.visible_count=group.count

func make_mesh()->ArrayMesh:
	var points=PackedVector3Array();var uvs=PackedVector2Array();var indices=PackedInt32Array()
	for i in 8:
		for bank in [0.0,.39,.999]:points.append(Vector3.ZERO);uvs.append(Vector2(i,2.0+bank))
	for i in 7:
		for bank in 2:
			var a=i*3+bank;var b=a+3
			indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var start=points.size()
	for uv in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:points.append(Vector3(uv.x-.5,uv.y-.5,0));uvs.append(uv)
	indices.append_array(PackedInt32Array([start,start+1,start+2,start,start+2,start+3]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return result

func dispose():
	groups.clear();current_groups.clear();entries.clear();free_slots.clear()
