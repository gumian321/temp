extends RefCounted
## Generated wet-body atlas, isolated from the original armament compatibility API.
const ATLAS_PATH="res://assets/ui_overhaul/viscous_projectiles_atlas.png"
const CELLS={"mucus":0,"egg":1,"larva":2,"tongue":3,"mucus_splat":4,"egg_burst":5,"goo_bead":6,"wet_trail":7,"larva_contact":2}
const REGIONS=[Rect2(58,133,338,203),Rect2(514,132,322,207),Rect2(946,124,328,221),Rect2(1388,154,331,164),Rect2(74,517,315,279),Rect2(502,520,327,268),Rect2(994,547,227,224),Rect2(1370,600,369,138)]
static var atlas:Texture2D
static var textures:Dictionary={}

static func texture(key:String)->Texture2D:
	if textures.has(key):return textures[key]
	if atlas==null:
		var config=ConfigFile.new()
		if config.load(ATLAS_PATH+".import")==OK:
			var imported=str(config.get_value("remap","path",""))
			if not imported.is_empty() and FileAccess.file_exists(imported):atlas=load(ATLAS_PATH)
		if atlas==null and FileAccess.file_exists(ATLAS_PATH):
			var raw=Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
			if raw!=null and not raw.is_empty():
				raw.generate_mipmaps();atlas=ImageTexture.create_from_image(raw)
		if atlas==null and ResourceLoader.exists(ATLAS_PATH):atlas=load(ATLAS_PATH)
		if atlas==null:return null
	var cell=int(CELLS.get(key,0))
	var result=AtlasTexture.new()
	result.atlas=atlas;result.region=REGIONS[cell];result.filter_clip=true
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
	var source=texture(key)
	if source==null:return false
	canvas.draw_set_transform(at,heading)
	canvas.draw_texture_rect(source,Rect2(-size*0.5,size),false,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)
	return true
