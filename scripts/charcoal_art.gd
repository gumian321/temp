extends RefCounted
## Corrected teacher reference: charcoal floor, chalk cutouts, crossed ink.
const ROOT = "res://assets/charcoal_ink/"
static var textures: Dictionary = {}
static var regions: Dictionary = {}
static var panel_skins: Dictionary = {}
const REGIONS = {
	"rocks": [Rect2(120,158,348,373),Rect2(648,112,566,440),Rect2(76,725,543,407),Rect2(695,722,489,455)],
	"centipede_parts": [Rect2(161,104,452,431),Rect2(863,102,546,439),Rect2(124,623,556,339),Rect2(861,603,554,343)],
	"panel": [Rect2(54,185,2063,345)],
	"chasm": [Rect2(25,11,1494,998)]
}

static func texture(key: String) -> Texture2D:
	if not textures.has(key): textures[key] = load(ROOT + key + ".png")
	return textures[key]

static func cutout(key: String, cell: int = -1, columns: int = 1, rows: int = 1) -> AtlasTexture:
	var cache_key = key + ":" + str(cell)
	if regions.has(cache_key): return regions[cache_key]
	var source = texture(key)
	if REGIONS.has(key):
		var measured = AtlasTexture.new()
		measured.atlas = source; measured.region = REGIONS[key][maxi(cell,0)]
		measured.filter_clip = true; regions[cache_key] = measured
		return measured
	var image = source.get_image()
	var cell_size = Vector2i(image.get_width() / columns, image.get_height() / rows)
	var region = Rect2i(Vector2i.ZERO, image.get_size())
	if cell >= 0: region = Rect2i(Vector2i(cell % columns, cell / columns) * cell_size, cell_size)
	var used = image.get_region(region).get_used_rect()
	var atlas = AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(region.position + used.position, used.size)
	atlas.filter_clip = true
	regions[cache_key] = atlas
	return atlas

static func panel_skin(alert: bool = false, compact: bool = false) -> StyleBoxTexture:
	var key = str(alert) + str(compact)
	if panel_skins.has(key): return panel_skins[key]
	var skin = StyleBoxTexture.new()
	# Scale the nine-slice texture once in memory; generated PNG stays untouched.
	var image = cutout("panel").get_image()
	image.resize(300, 40 if compact else 64, Image.INTERPOLATE_LANCZOS)
	skin.texture = ImageTexture.create_from_image(image)
	skin.texture_margin_left = 42; skin.texture_margin_right = 42
	skin.texture_margin_top = 10 if compact else 17; skin.texture_margin_bottom = skin.texture_margin_top
	skin.content_margin_left = 22; skin.content_margin_right = 22
	skin.content_margin_top = 12; skin.content_margin_bottom = 12
	if alert: skin.modulate_color = Color("ff1764")
	panel_skins[key] = skin
	return skin

static func rock_extent(actor: Dictionary, db) -> float:
	if not actor.has("charcoal_extent"):
		var extent = float(actor.get("radius",30)) * 2.0
		for renderer in actor.get("render",[]):
			var info: Dictionary = db.sprites.get(renderer.sprite,{})
			if not str(info.get("name","")).begins_with("Asteroids_"): continue
			var original = db.sprite(renderer.sprite)
			if original != null:
				extent = maxf(original.get_width()*absf(renderer.sx),original.get_height()*absf(renderer.sy)) / float(info.get("ppu",250)) * 48.0
				break
		actor.charcoal_extent = extent
	return float(actor.charcoal_extent)

static func rock(canvas: CanvasItem, actor: Dictionary, at: Vector2, zoom: float, db):
	var source: Texture2D = cutout("rocks", int(actor.uid) % 4, 2, 2)
	if actor.has("mineral"):
		var damage: Dictionary=actor.mineral
		if damage.dirty: damage.image.generate_mipmaps()
		if not damage.has("texture"):
			damage.texture=ImageTexture.create_from_image(damage.image); damage.dirty=false
		elif damage.dirty:
			damage.texture.update(damage.image); damage.dirty=false
		source=damage.texture
	var extent = source.get_size() * (rock_extent(actor,db) * zoom / maxf(source.get_width(), source.get_height()))
	var tint = Color.WHITE.lerp(Color("ff779d"), clampf(float(actor.get("feedback_left", 0)) / .095, 0, 1) * .55)
	canvas.draw_texture_rect(source, Rect2(at - extent * .5, extent), false, tint)
