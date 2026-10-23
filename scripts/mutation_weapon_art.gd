extends RefCounted
static var atlases:Dictionary={}
static var textures:Dictionary={}
static func texture(key:String,cell:int=0)->Texture2D:
	var id=key+":"+str(cell)
	if textures.has(id):return textures[id]
	if not atlases.has(key):
		var path="res://assets/new_weapons/"+key+"_atlas.png"
		if not ResourceLoader.exists(path):return null
		atlases[key]=load(path)
	var atlas:Texture2D=atlases[key]
	var size=atlas.get_size()/2.0
	var origin=Vector2(cell%2,cell/2)*size
	var region=Rect2(origin,size)
	# Generated branches have asymmetric transparent gutters; preserve whole sprites.
	if key=="toxin_branches":
		var rects=[Rect2(0,0,700,700),Rect2(700,0,554,700),Rect2(0,700,700,554),Rect2(700,700,554,554)]
		region=rects[cell]
	elif key=="boneblade_branches" and cell<2:
		region=Rect2(0,0,700,627) if cell==0 else Rect2(700,0,554,627)
	elif key=="parasite_branches":
		region=Rect2((cell%2)*627,0 if cell<2 else 670,627,670 if cell<2 else 584)
	origin=region.position;size=region.size
	var pixels=atlas.get_image()
	if pixels!=null:
		var used=pixels.get_region(Rect2i(region)).get_used_rect()
		if used.has_area():region=Rect2(origin+Vector2(used.position),Vector2(used.size)).grow(1).intersection(Rect2(origin,size))
	var result=AtlasTexture.new();result.atlas=atlas;result.region=region;result.filter_clip=true
	textures[id]=result
	return result
static func sprite(canvas,key:String,cell:int,at:Vector2,size:Vector2,rotation:float=0.0,tint:Color=Color.WHITE):
	var image=texture(key,cell)
	if image==null:return
	var extent=image.get_size();extent*=minf(size.x/extent.x,size.y/extent.y)
	canvas.draw_set_transform(at,rotation)
	canvas.draw_texture_rect(image,Rect2(-extent*.5,extent),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)
