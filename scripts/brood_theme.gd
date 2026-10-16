extends RefCounted
## Original combat IDs remain stable; only their presentation is replaced.
const ROOT = "res://assets/blue_ink/brood/"
const WEAPONS = {
	"Cannon":"cannon", "Gatling":"gatling", "Shotgun":"shotgun",
	"Sniper":"sniper", "Rocket":"rocket", "Rocket_AI":"rocket",
	"Flak":"flak", "FlameThrower":"flame", "Tesla":"tesla", "EMP":"emp",
	"SonicWave":"sonic", "Black Holer":"blackhole", "Nuke":"nuke"
}
const SPECIES = ["grub", "beetle", "moth", "sac", "mantis", "queen"]
const SPECIAL_TURRETS = {
	"Turret_Mines":"mine", "Turret_Mines Spawner":"mine_spawner",
	"Turret_Drones_Attack":"drone_bay", "Turret_Drones_Attack_AI":"drone_bay"
}
static var textures: Dictionary = {}

static func install(db):
	preload("res://scripts/insect_armaments.gd").install_art(db)

static func replace_sprite(db, id: String, image: String):
	if not db.sprites.has(id):return
	db.sprites[id] = db.sprites[id].duplicate()
	db.sprites[id].path = ROOT + image + ".png"
	db.sprites[id]["brood"] = true

static func weapon_texture(variant: String) -> Texture2D:
	return preload("res://scripts/insect_armaments.gd").texture(variant)

static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		var source: Texture2D = load(ROOT + id + ".png")
		if source == null: return null
		# Runtime UV region trims only empty alpha. Generated files stay untouched.
		var region = source.get_image().get_used_rect()
		var atlas = AtlasTexture.new()
		atlas.atlas = source
		atlas.region = region
		atlas.filter_clip = true
		textures[id] = atlas
	return textures[id]

static func eligible(e: Dictionary) -> bool:
	return str(e.get("kind", "")).begins_with("AI") or e.get("kind", "") in ["SpawnerStation", "MineController", "TraderUnit"]

static func species(e: Dictionary) -> String:
	if e.has("brood_species"): return e.brood_species
	match str(e.get("kind", "")):
		"AIBossUnit": return "queen"
		"AIBossPartController", "AIGuardUnitController": return "beetle"
		"AIStation", "AIStationPartController", "SpawnerStation", "MineController": return "sac"
		"AIPatrolUnit": return "mantis"
		"AIFollowingUnit", "TraderUnit": return "moth"
	var source_name=str(e.get("name",""))
	if "Tank" in source_name:return "beetle"
	if "Kamikaze" in source_name or "Pyro" in source_name:return "sac"
	if "Drones" in source_name:return "moth"
	if "Shotgun" in source_name:return "mantis"
	return "grub"

static func extent(e: Dictionary) -> float:
	var radius = float(e.get("radius", 18))
	# Presentation only: ordinary radius-15 bugs gain 20% (40.5 -> 48.6).
	# The bonus tapers away before charger-sized enemies, so large insects and
	# bosses keep their scale. Never write this visual extent into hit/contact radii.
	var small_bonus = 8.1 * clampf((22.0 - radius) / 7.0, 0.0, 1.0)
	return maxf(38.0, radius * 2.7) + small_bonus
