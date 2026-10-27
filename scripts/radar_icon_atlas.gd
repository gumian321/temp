extends RefCounted
## Radar-only atlas. Native source texels and command order stay intact.
## Mipmapped native textures pass through unchanged; only unmipped sources share pixels.
const PADDING=16
const MAX_EDGE=4096
const MAX_BYTES=8*1024*1024
var atlas:ImageTexture
var mapped:Dictionary={}
var report:Dictionary={}

func build(sources:Dictionary)->bool:
	mapped.clear();atlas=null
	var images:Dictionary={};var placements:Dictionary={};var details=[];var passthrough=0
	var cursor=Vector2i(PADDING,PADDING);var row_height=0;var used=Vector2i.ZERO
	for key in sources:
		var texture:Texture2D=sources[key]
		if texture==null:continue
		var backing:Texture2D=texture.atlas if texture is AtlasTexture else texture
		var native_image=backing.get_image()
		if native_image==null or native_image.is_empty():return false
		if native_image.has_mipmaps():
			mapped[key]=texture;passthrough+=1
			continue
		var rid=backing.get_rid()
		if not images.has(rid):
			var image=native_image
			if image.is_compressed() and image.decompress()!=OK:return false
			image.convert(Image.FORMAT_RGBA8)
			var extent=image.get_size()
			if extent.x+PADDING*2>MAX_EDGE or extent.y+PADDING*2>MAX_EDGE:return false
			if cursor.x+extent.x+PADDING>2048:
				cursor=Vector2i(PADDING,cursor.y+row_height+PADDING*2);row_height=0
			if cursor.y+extent.y+PADDING>MAX_EDGE:return false
			images[rid]=image;placements[rid]=cursor
			used=used.max(cursor+extent+Vector2i(PADDING,PADDING))
			cursor.x+=extent.x+PADDING*2;row_height=maxi(row_height,extent.y)
			details.append({"first_key":key,"native_size":[extent.x,extent.y],"source_mipmaps":image.has_mipmaps()})
	if images.is_empty():return false
	var width=nearest_po2(used.x);var height=nearest_po2(used.y)
	var estimated=width*height*4
	if width>MAX_EDGE or height>MAX_EDGE or estimated>MAX_BYTES:return false
	var combined=Image.create(width,height,false,Image.FORMAT_RGBA8);combined.fill(Color.TRANSPARENT)
	for rid in images:
		var source:Image=images[rid];var at:Vector2i=placements[rid];var extent=source.get_size()
		combined.blit_rect(source,Rect2i(Vector2i.ZERO,extent),at)
		# Extrude full native edges into the gutter. No source resampling.
		for pad in range(1,PADDING+1):
			combined.blit_rect(source,Rect2i(0,0,extent.x,1),at+Vector2i(0,-pad))
			combined.blit_rect(source,Rect2i(0,extent.y-1,extent.x,1),at+Vector2i(0,extent.y-1+pad))
			combined.blit_rect(source,Rect2i(0,0,1,extent.y),at+Vector2i(-pad,0))
			combined.blit_rect(source,Rect2i(extent.x-1,0,1,extent.y),at+Vector2i(extent.x-1+pad,0))
		for x in [-1,1]:
			for y in [-1,1]:
				var corner=Vector2i(0 if x<0 else extent.x-1,0 if y<0 else extent.y-1)
				var gutter=at+Vector2i(-PADDING if x<0 else extent.x,-PADDING if y<0 else extent.y)
				combined.fill_rect(Rect2i(gutter,Vector2i(PADDING,PADDING)),source.get_pixelv(corner))
	atlas=ImageTexture.create_from_image(combined)
	for key in sources:
		var original:Texture2D=sources[key]
		if original==null:continue
		if mapped.has(key):continue
		var backing:Texture2D=original.atlas if original is AtlasTexture else original
		var result=AtlasTexture.new();result.atlas=atlas
		result.region=Rect2(placements[backing.get_rid()],backing.get_size())
		if original is AtlasTexture:
			result.region.position+=original.region.position
			result.region.size=original.region.size
			result.margin=original.margin;result.filter_clip=original.filter_clip
		mapped[key]=result
	report={"width":width,"height":height,"atlas_bytes":combined.get_data_size(),"estimated_bytes":estimated,"padding":PADDING,"unique_sources":images.size(),"icons":mapped.size(),"passthrough_mipmapped_icons":passthrough,"sources":details,"mip_strategy":"Only native unmipped textures share an unmipped atlas. All mipmapped native textures pass through unchanged; strict rendered gate required."}
	return true

func texture(key:String)->Texture2D:return mapped.get(key)
