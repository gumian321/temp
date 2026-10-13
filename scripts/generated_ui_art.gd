extends RefCounted
## Generated raster artwork. Geometry is only atlas slicing and nine-patch layout.
const ICON_PATH="res://assets/ui_overhaul/light_ui_icons.png"
const PANEL_PATH="res://assets/ui_overhaul/light_ui_panels.png"
const KEYS=["armor","body","drone","fuel","gear","play","back","pause","evolution","loot","threat","radar","settings","confirm","cancel","timer"]
const ALIASES={"shield":"armor","wing":"drone","research":"evolution","meta":"evolution","reward":"loot","target":"radar","time":"timer","next":"play","check":"confirm","exit":"cancel","sound":"settings","burst":"threat","orbit":"radar","add":"body","grid":"body","rate":"timer","range":"radar"}
# Alpha-connected bounds measured from the unmodified generated raster.
const ICON_REGIONS=[Rect2(53,5,277,284),Rect2(385,17,306,279),Rect2(702,31,359,276),Rect2(1094,43,237,246),Rect2(46,301,293,266),Rect2(389,321,302,216),Rect2(746,315,262,248),Rect2(1101,314,219,245),Rect2(36,570,317,273),Rect2(401,561,263,273),Rect2(746,570,258,264),Rect2(1087,569,248,253),Rect2(44,850,289,241),Rect2(386,844,288,268),Rect2(725,842,281,273),Rect2(1106,835,190,275)]
const PANEL_REGIONS={"normal":Rect2(32,91,727,223),"active":Rect2(780,91,723,223),"hud":Rect2(37,453,811,266),"panel":Rect2(880,370,621,558)}
static var icon_cache:Dictionary={}
static var panel_cache:Dictionary={}
static var skin_cache:Dictionary={}

static func icon(key:String)->Texture2D:
	key=str(ALIASES.get(key,key))
	if not key in KEYS:key="gear"
	if icon_cache.has(key):return icon_cache[key]
	if not ResourceLoader.exists(ICON_PATH):return null
	var atlas:Texture2D=load(ICON_PATH)
	var index=KEYS.find(key)
	var texture=AtlasTexture.new();texture.atlas=atlas
	texture.region=ICON_REGIONS[index];texture.filter_clip=true
	icon_cache[key]=texture
	return texture

static func panel_texture(key:String="panel")->Texture2D:
	if panel_cache.has(key):return panel_cache[key]
	if not ResourceLoader.exists(PANEL_PATH):return null
	var atlas:Texture2D=load(PANEL_PATH)
	var texture=AtlasTexture.new();texture.atlas=atlas
	texture.region=PANEL_REGIONS.get(key,PANEL_REGIONS.panel);texture.filter_clip=true
	panel_cache[key]=texture
	return texture

static func skin(key:String="panel",margin:int=12)->StyleBoxTexture:
	# Downsample the source raster before nine-patch layout, keeping the painted
	# corner proportions at UI scale instead of stretching full-size wing tips.
	if not skin_cache.has(key):
		var source=panel_texture(key)
		if source!=null:
			var image=source.get_image()
			var width=240 if key=="hud" else (300 if key in ["normal","active"] else 180)
			var height=roundi(image.get_height()*float(width)/image.get_width())
			image.resize(width,height,Image.INTERPOLATE_LANCZOS)
			var atlas=AtlasTexture.new();atlas.atlas=ImageTexture.create_from_image(image);atlas.region=Rect2(0,0,width,height)
			skin_cache[key]=atlas
	var box=StyleBoxTexture.new();box.texture=skin_cache.get(key)
	box.texture_margin_left=36 if key in ["normal","active"] else 24
	box.texture_margin_right=box.texture_margin_left
	box.texture_margin_top=24;box.texture_margin_bottom=24
	box.content_margin_left=margin;box.content_margin_right=margin
	box.content_margin_top=margin;box.content_margin_bottom=margin
	return box
