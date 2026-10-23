extends RefCounted
## Presentation only. Source IDs, internal names, combat values and save keys stay stable.
const ROOT = "res://assets/ui_overhaul/"
static var catalog: Dictionary = {}
static var textures: Dictionary = {}

static func entries() -> Dictionary:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/insect_armaments.json"))
		catalog.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/expanded_armaments.json")))
	return catalog

static func variant(db, value: Dictionary) -> String:
	if value.has("insect_variant"): return str(value.insect_variant)
	if value.get("rewardTextID", "") == "Reward_WallCores": return "wall"
	for field in ["coreTurret", "coreChip", "blockCore", "core", "turretCore", "drone"]:
		if value.get(field) is String:
			var found = variant(db, db.asset(value[field]))
			if not found.is_empty(): return found
	if value.has("coresList") and not value.coresList.is_empty():
		return variant(db, db.asset(value.coresList[0]))
	return ""

static func install_art(db):
	var turrets: Dictionary = {}
	for key in entries():
		for name in catalog[key].turrets: turrets[name] = key
	for value in db.catalog.values():
		var key = str(turrets.get(value.get("name", ""), ""))
		var field = "turretSprite"
		match str(value.get("class", "")):
			"ProjectileDrone": key = "drone_unit"; field = "droneSprite"
			"EngineerDrone": key = "repair_drone"; field = "droneSprite"
			"Drone": key = "scrap_drone"; field = "droneSprite"
			"Mine": key = "mine_unit"; field = "mineSprite"
			"Chip":
				key = str({1:"chip_shrapnel",2:"chip_exploding",3:"chip_piercing",4:"chip_chain",5:"chip_mammoth",6:"chip_control"}.get(int(value.get("chipType", 0)), ""))
				field = "chipSprite"
		if key.is_empty(): continue
		value.insect_variant = key
		var id = str(value.get(field, ""))
		if not db.sprites.has(id): continue
		db.sprites[id] = db.sprites[id].duplicate()
		db.sprites[id].path = atlas_path(key)
		db.sprites[id].insect_variant = key
		db.sprites[id].erase("brood")

static func install_names(db):
	for key in entries():
		var info: Dictionary = catalog[key]
		set_text(db, info.key, info.en, info.zh)
		set_text(db, info.key + "_Desc", info.description_en, info.description_zh)
	# Shared hangar names must resolve by actual drone bay, never by a generic template.
	for value in db.catalog.values():
		if not value.has("coreTurret") and not value.has("coreChip"): continue
		var key = variant(db, value)
		if not key.is_empty(): value.coreNameID = catalog[key].key
	for value in db.catalog.values():
		if not "Reward" in str(value.get("class", "")): continue
		if value.has("mutation_branch"):continue
		var key = variant(db, value)
		if not key.is_empty(): value.rewardDesc = catalog[key].key + "_Desc"
	set_text(db, "Reward_WallCores", "Iron Elytra", "铁鞘")
	set_text(db, "Reward_WallCores_Desc", "Adds protective chitin segments.", "获得保护身体的铁鞘元素。")

static func set_text(db, key: String, english: String, chinese: String):
	var previous: Dictionary = db.localization.get(key, {})
	for old in previous.values():
		if old is String and not old.is_empty(): db.english_keys[old] = key
	db.localization[key] = previous.duplicate()
	db.localization[key]["English"] = english
	db.localization[key]["Chinese (simplified)"] = chinese
	# Keep the literal-first UI path in sync with the central localization path.
	for old in previous.values():
		if old is String and not old.is_empty(): db.chinese_ui.literal[old] = chinese

static func atlas_path(key: String) -> String:
	if entries()[key].has("atlas_path"):return str(entries()[key].atlas_path)
	return ROOT + "armaments_atlas_" + str(entries()[key].atlas) + ".png"

static func texture(key: String) -> Texture2D:
	if not entries().has(key): return null
	if entries()[key].has("atlas_path"):return preload("res://scripts/mutation_weapon_art.gd").texture(key)
	if textures.has(key): return textures[key]
	var path = atlas_path(key)
	if not ResourceLoader.exists(path): return null
	var source: Texture2D = load(path)
	if source == null: return null
	var cell = int(catalog[key].cell)
	var columns = int(catalog[key].get("columns", 3))
	var rows = int(catalog[key].get("rows", 3))
	var size = source.get_size() / Vector2(columns, rows)
	var region = Rect2(Vector2(cell % columns, cell / columns) * size, size)
	# Hand-verified UV rectangles account for generated spacing; never rewrite source art.
	if catalog[key].has("region"):
		var rect: Array = catalog[key].region
		region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	var result = AtlasTexture.new()
	result.atlas = source
	result.region = region
	result.filter_clip = true
	textures[key] = result
	return result
