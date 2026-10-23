extends RefCounted
## Closed flight bodies plus separate legacy contact and beam textures.
const AttackShaders = preload("res://scripts/attack_shader_layer.gd")
const ATLAS_PATH="res://assets/ui_overhaul/viscous_projectiles_atlas.png"
const BODY_ATLAS_PATH="res://assets/ui_overhaul/projectile_bodies_atlas.png"
const SPECIAL_BODY_ATLAS_PATH="res://assets/ui_overhaul/special_projectile_bodies_atlas.png"
const SPECIAL_BODY_KEYS=["emp","blackhole"]
const BODY_REGIONS={"mucus":Rect2(96,158,465,392),"egg":Rect2(690,157,488,403),"larva":Rect2(89,751,553,321),"tongue":Rect2(715,733,450,376)}
const CELLS={"mucus":0,"egg":1,"larva":2,"tongue":3,"mucus_splat":4,"egg_burst":5,"goo_bead":6,"wet_trail":7,"larva_contact":2}
const REGIONS=[Rect2(58,133,338,203),Rect2(514,132,322,207),Rect2(946,124,328,221),Rect2(1388,154,331,164),Rect2(74,517,315,279),Rect2(502,520,327,268),Rect2(994,547,227,224),Rect2(1370,600,369,138)]
static var atlas:Texture2D
static var body_atlas:Texture2D
static var special_body_atlas:Texture2D
static var textures:Dictionary={}

static func load_atlas(path:String)->Texture2D:
	var source:Texture2D
	var config=ConfigFile.new()
	if config.load(path+".import")==OK:
		var imported=str(config.get_value("remap","path",""))
		if not imported.is_empty() and FileAccess.file_exists(imported):source=load(path)
	if source==null and FileAccess.file_exists(path):
		var raw=Image.load_from_file(ProjectSettings.globalize_path(path))
		if raw!=null and not raw.is_empty():
			raw.generate_mipmaps();source=ImageTexture.create_from_image(raw)
	if source==null and ResourceLoader.exists(path):source=load(path)
	return source

static func texture(key:String)->Texture2D:
	if key=="larva_contact":return texture("larva")
	if textures.has(key):return textures[key]
	var cell=int(CELLS.get(key,0))
	var result=AtlasTexture.new()
	if key in SPECIAL_BODY_KEYS:
		if special_body_atlas==null:special_body_atlas=load_atlas(SPECIAL_BODY_ATLAS_PATH)
		if special_body_atlas==null:return null
		result.atlas=special_body_atlas
		result.region=Rect2(359,131,556,461) if key=="emp" else Rect2(354,698,570,452)
	elif BODY_REGIONS.has(key):
		if body_atlas==null:body_atlas=load_atlas(BODY_ATLAS_PATH)
		if body_atlas==null:return null
		result.atlas=body_atlas;result.region=BODY_REGIONS[key]
	else:
		if atlas==null:atlas=load_atlas(ATLAS_PATH)
		if atlas==null:return null
		result.atlas=atlas;result.region=REGIONS[cell]
	result.filter_clip=true
	textures[key]=result
	return result

static func family(shot:Dictionary,weapon:String)->String:
	if shot.has("organic_family"):return str(shot.organic_family)
	if weapon in ["rocket","drone"]:return "larva"
	if weapon in ["nuke","flak","mine"]:return "egg"
	if weapon in ["tesla","rail","sonic"]:return "tongue"
	if weapon in ["gatling","shotgun","cannon","flame"]:return "mucus"
	return ""

static func pose(shot:Dictionary,kind:String,time:float)->Vector2:
	var phase=float(shot.get("organic_phase",Vector2(shot.get("origin",shot.position)).x*0.037))
	var wave=sin(time*(18.0 if kind=="larva" else 11.0)+phase)
	if kind=="larva":return Vector2(1.0+wave*0.13,1.0-wave*0.18)
	if kind=="egg":return Vector2(1.0+wave*0.05,1.0-wave*0.05)
	return Vector2(1.10+wave*0.12,0.94-wave*0.12)

static func stamp(canvas,key:String,at:Vector2,size:Vector2,heading:float=0.0,alpha:float=1.0)->bool:
	canvas=AttackShaders.route(canvas,{"egg":"nuke","egg_burst":"nuke","larva":"rocket","larva_contact":"rocket","tongue":"rail","emp":"emp","blackhole":"blackhole"}.get(key,"gatling"))
	var source=texture(key)
	if source==null:return false
	canvas.draw_set_transform(at,heading)
	canvas.draw_texture_rect(source,Rect2(-size*0.5,size),false,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)
	return true
