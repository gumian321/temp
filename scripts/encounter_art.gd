extends RefCounted
## ImageGen raster assets. UV atlases trim padding without modifying source PNGs.
const ROOT = "res://assets/special_encounters/"
# Measured alpha >= 0.1 bounds; near-invisible generation residue must not
# inflate the decal's transparent padding or move its gameplay endpoints.
const REGIONS = {"warning_seal": Rect2(28, 38, 1198, 1174), "charge_lane": Rect2(58, 198, 2070, 336), "hud_plate": Rect2(16, 128, 2142, 436)}
static var textures: Dictionary = {}
static var atlases: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if not textures.has(id): textures[id] = load(ROOT + id + ".png")
	return textures[id]

static func decal(id: String) -> Texture2D:
	if not atlases.has(id):
		var source = texture(id)
		var atlas = AtlasTexture.new()
		atlas.atlas = source
		atlas.region = REGIONS.get(id, Rect2(Vector2.ZERO, source.get_size()))
		atlas.filter_clip = true
		atlases[id] = atlas
	return atlases[id]

static func actor_texture(actor: Dictionary) -> Texture2D:
	var kind = str(actor.get("encounter_type", ""))
	return texture(kind) if kind in ["charger", "broodmother", "treasure"] else null
