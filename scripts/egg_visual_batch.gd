extends RefCounted
## Three instanced draws per texture/team instead of per-egg sprite, AA ring
## and halo commands. Simulation objects, source artwork and pigment stay live.
const Layers=preload("res://scripts/attack_shader_layer.gd")
const Ink=preload("res://scripts/blue_ink.gd")
const Feedback=preload("res://scripts/weapon_feedback.gd")
var sprites:Dictionary={}
var rings:Dictionary={}
var halos:Dictionary={}

func batch(store:Dictionary,key,custom:bool=false)->Dictionary:
	if not store.has(key):
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_2D;mm.use_colors=true;mm.use_custom_data=custom
		store[key]={"mm":mm,"zoom":-1.0}
	return store[key]

func reserve(mm:MultiMesh,count:int):
	if mm.instance_count<count: mm.instance_count=maxi(16,ceili(float(count)/16.0)*16)
	mm.visible_instance_count=count

func visible_mines(canvas,mines:Array)->Dictionary:
	var groups={false:[],true:[]}
	var rect:Rect2=canvas.get_viewport_rect().grow(220)
	for mine in mines:
		var at:Vector2=canvas.world(mine.position)
		if rect.has_point(at):groups[not bool(mine.get("friendly",true))].append({"mine":mine,"at":at})
	return groups

func paint_sprites(canvas,battle,zoom:float)->bool:
	if not Layers.route(canvas,"mine") is Layers.Painter:return false
	var groups=visible_mines(canvas,battle.special.mines)
	for hostile in groups:
		var textures={}
		for row in groups[hostile]:
			var texture:Texture2D=canvas.db.sprite(row.mine.data.mineSprite)
			if texture==null:continue
			if not textures.has(texture):textures[texture]=[]
			textures[texture].append(row)
		for texture:Texture2D in textures:
			var key=str(texture.get_instance_id())+":"+str(hostile)
			var item=batch(sprites,key);var mm:MultiMesh=item.mm
			var source:Texture2D=texture.atlas if texture is AtlasTexture else texture
			if item.zoom!=zoom:
				var size=Ink.fitted_size(texture,Vector2(22,22)*zoom)
				var rect:Rect2=texture.region if texture is AtlasTexture else Rect2(Vector2.ZERO,texture.get_size())
				var vertices=PackedVector3Array();var uvs=PackedVector2Array()
				for uv:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
					var point=(uv-Vector2.ONE*.5)*size
					vertices.append(Vector3(point.x,point.y,0));uvs.append((rect.position+uv*rect.size)/source.get_size())
				var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
				var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mm.mesh=mesh;item.zoom=zoom
			var rows:Array=textures[texture];reserve(mm,rows.size())
			for i in rows.size():
				mm.set_instance_transform_2d(i,Transform2D(0.0,rows[i].at));mm.set_instance_color(i,Color.WHITE)
			Layers.route(canvas,"mine",hostile).draw_multimesh(mm,source)
	return true

func paint_markers(canvas,battle,zoom:float,clock:float,halo_texture:Texture2D)->bool:
	if not Layers.route(canvas,"mine") is Layers.Painter:return false
	var groups=visible_mines(canvas,battle.special.mines)
	for hostile in groups:
		var rows:Array=groups[hostile]
		if rows.is_empty():continue
		var ring_batch=batch(rings,hostile,true);var halo_batch=batch(halos,hostile)
		var ring_mm:MultiMesh=ring_batch.mm;var halo_mm:MultiMesh=halo_batch.mm
		if ring_mm.mesh==null:
			var mesh=QuadMesh.new();mesh.size=Vector2(2,2);ring_mm.mesh=mesh
		if halo_batch.zoom!=zoom:
			var mesh=QuadMesh.new();mesh.size=Vector2.ONE*24*zoom;halo_mm.mesh=mesh;halo_batch.zoom=zoom
		reserve(ring_mm,rows.size());reserve(halo_mm,rows.size())
		var low:Vector2=rows[0].at;var high=low
		for i in rows.size():
			var row:Dictionary=rows[i];var at:Vector2=row.at
			low=low.min(at);high=high.max(at)
			var pulse=.5+.5*sin(clock*6+row.mine.position.x)
			var transform=Transform2D(0.0,at)
			ring_mm.set_instance_transform_2d(i,transform)
			ring_mm.set_instance_custom_data(i,Color((15+pulse*4)*zoom,at.x,at.y,1.0+.75*zoom))
			ring_mm.set_instance_color(i,Color(Feedback.PROFILES.mine.color,.35+pulse*.35))
			halo_mm.set_instance_transform_2d(i,transform);halo_mm.set_instance_color(i,Color(Feedback.PROFILES.mine.accent,.55))
		# The vertex shader expands a unit quad into the full ring. Include its
		# real extent in culling so rings remain visible at viewport edges.
		var padding=24.0*zoom+2.0
		ring_mm.custom_aabb=AABB(Vector3(low.x-padding,low.y-padding,-1),Vector3(high.x-low.x+padding*2,high.y-low.y+padding*2,2))
		var painter=Layers.route(canvas,"mine",hostile)
		painter.draw_multimesh(ring_mm);painter.draw_multimesh(halo_mm,halo_texture)
	return true
