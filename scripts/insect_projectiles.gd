extends RefCounted
## Generated organic bodies. Internal source weapon IDs remain compatible with saves.
const ATLAS_PATH = "res://assets/ui_overhaul/insect_projectiles_atlas.png"
const Feedback = preload("res://scripts/weapon_feedback.gd")
const INK = Color("213b6e")
const REGIONS = [Rect2(22,181,424,183),Rect2(466,145,359,230),Rect2(872,133,364,257),Rect2(19,480,384,300),Rect2(409,441,419,346),Rect2(857,447,383,364),Rect2(27,886,403,240),Rect2(448,902,336,227),Rect2(796,879,444,270)]
const CELLS = {"gatling":0,"shotgun":1,"cannon":2,"flak":3,"rocket":4,"nuke":5,"emp":6,"blackhole":7,"sonic":8,"rail":0,"tesla":6,"flame":2,"drone":0,"mine":5,"impact":0}
const SIZES = {"gatling":Vector2(19,9),"shotgun":Vector2(22,15),"cannon":Vector2(27,22),"flak":Vector2(25,21),"rocket":Vector2(34,27),"nuke":Vector2(41,34),"emp":Vector2(27,18),"blackhole":Vector2(28,25),"sonic":Vector2(30,19)}
static var textures: Dictionary = {}
static var atlas: Texture2D

static func family(bullet: Dictionary) -> String:
	var key = str(bullet.get("fx_family",Feedback.family(bullet.get("data",{}))))
	return key if CELLS.has(key) else "gatling"

static func angle(bullet: Dictionary) -> float:
	var direction = Vector2(bullet.get("velocity",Vector2.ZERO))
	if direction.length_squared()<0.0001: direction=Vector2(bullet.get("direction",Vector2.RIGHT))
	return direction.angle()

static func load_atlas(force_raw: bool = false) -> Texture2D:
	var source:Texture2D
	var config=ConfigFile.new()
	if not force_raw and config.load(ATLAS_PATH+".import")==OK:
		var imported=str(config.get_value("remap","path",""))
		if not imported.is_empty() and FileAccess.file_exists(imported):source=load(ATLAS_PATH)
	if source==null and FileAccess.file_exists(ATLAS_PATH):
		var raw=Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
		if raw!=null and not raw.is_empty():
			raw.generate_mipmaps()
			source=ImageTexture.create_from_image(raw)
	if source==null and not FileAccess.file_exists(ATLAS_PATH) and ResourceLoader.exists(ATLAS_PATH):source=load(ATLAS_PATH)
	return source

static func texture(key: String) -> Texture2D:
	var cell = int(CELLS.get(key,0))
	if textures.has(cell):return textures[cell]
	if atlas==null:atlas=load_atlas()
	# Failed loads are never cached, so a fresh import can recover immediately.
	if atlas==null:return null
	var result=AtlasTexture.new()
	result.atlas=atlas;result.region=REGIONS[cell];result.filter_clip=true
	textures[cell]=result
	return result

static func paint(canvas, bullet: Dictionary, zoom: float):
	var key=family(bullet)
	var at:Vector2=canvas.world(bullet.position)
	var heading=angle(bullet)
	var axis=Vector2.from_angle(heading)
	var hostile=not bool(bullet.get("friendly",true))
	var size:Vector2=SIZES.get(key,Vector2(22,13))
	size*=zoom*clampf(float(bullet.get("radius",4.0))/4.0,1.0,2.0)
	var source=texture(key)
	canvas.draw_set_transform(at,heading)
	if source!=null:
		var native_size=source.get_size()
		var fit=minf(size.x/native_size.x,size.y/native_size.y)
		var extent=native_size*fit
		canvas.draw_texture_rect(source,Rect2(-extent/2,extent),false,Color("ff7897") if hostile else Color.WHITE)
	else:
		# Missing atlas stays biological: tapered chitin splinter, never old factory art.
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(size.x*0.5,0),Vector2(-size.x*0.35,-size.y*0.35),Vector2(-size.x*0.15,0),Vector2(-size.x*0.35,size.y*0.35)]),Color("ef7594") if hostile else Color("efbd55"))
	canvas.draw_set_transform(Vector2.ZERO)
	if hostile:
		# Rear fork gives incoming shots a shape cue as well as the pink tint.
		var side=axis.orthogonal()
		var rear=at-axis*size.x*0.58
		canvas.draw_polyline(PackedVector2Array([rear-axis*4*zoom-side*4*zoom,rear,rear-axis*4*zoom+side*4*zoom]),Color("b44870"),maxf(1.0,1.7*zoom),true)
