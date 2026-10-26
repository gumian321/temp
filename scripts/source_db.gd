extends RefCounted

var catalog: Dictionary
var stores: Dictionary
var research: Array
var prefabs: Dictionary
var pool: Dictionary
var sprites: Dictionary
var localization: Dictionary
var entities: Dictionary
var prefab_transforms: Dictionary
var scene_config: Dictionary
var textures: Dictionary = {}
const Armaments = preload("res://scripts/insect_armaments.gd")
const STARTER_WEAPONS = ["Gatling", "Shotgun", "Cannon", "Tesla", "Rocket"]
const DEFAULT_LANGUAGE = "Chinese (simplified)"
var language = DEFAULT_LANGUAGE
var chinese_ui: Dictionary
var english_keys: Dictionary = {}
var names:Dictionary={}
var classes:Dictionary={}

func _init():
	catalog = read_json("catalog")
	stores = read_json("stores")
	research = read_json("research")
	prefabs = read_json("prefabs")
	pool = read_json("pool")
	entities = read_json("entities")
	prefab_transforms = read_json("prefab_transforms")
	scene_config = read_json("scene_config")
	sprites = read_json("sprites")
	preload("res://scripts/expanded_armaments.gd").install(self)
	preload("res://scripts/mutation_branches.gd").install(self)
	apply_progression_rules()
	preload("res://scripts/brood_theme.gd").install(self)
	localization = read_json("localization")
	chinese_ui = read_json("chinese_ui")
	for key in chinese_ui.localization:
		if localization.has(key):localization[key][DEFAULT_LANGUAGE] = chinese_ui.localization[key]
	Armaments.install_names(self)
	preload("res://scripts/mutation_branches.gd").install_names(self)
	for key in localization:
		english_keys[str(localization[key].get("English", ""))] = key
	# Source layouts retain their original literal strings. Resolve those through
	# the same reviewed wording as localized labels in every selectable language.
	for source_text in chinese_ui.get("aliases", {}):
		english_keys[source_text] = chinese_ui.aliases[source_text]
	for value in catalog.values():
		if not names.has(value.name):names[value.name]=value
		if not classes.has(value["class"]):classes[value["class"]]=[]
		classes[value["class"]].append(value)

func apply_progression_rules():
	# Keep legacy IDs readable while retiring paid rearrangement from progression.
	var starter_names=STARTER_WEAPONS.map(func(weapon):return "Reward_Block_Gun_"+weapon)
	for reward in catalog.values():
		if reward.get("class")=="CountBasicReward" and int(reward.get("rewardType",-1)) in [8,20]:
			reward.retired=true
		if reward.get("name","") in starter_names:
			if reward.id not in stores.RewardDataStore.rewardsUnlockedList:
				stores.RewardDataStore.rewardsUnlockedList.append(reward.id)
	for pack_id in stores.RewardDataStore.allRewardPacksList:
		var pack:Dictionary=catalog[pack_id]
		pack.packRewardsList=pack.packRewardsList.filter(func(id):return not catalog[id].get("retired",false))
	var nodes:Dictionary={}
	for node in research:
		nodes[node.id]=node
		node.nodeRewardsList=node.nodeRewardsList.filter(func(id):return not catalog[id].get("retired",false))
	research=research.filter(func(node):return not node.nodeRewardsList.is_empty())
	for node in research:
		var parent=str(int(node.get("previousUpgradeTreeNode",{}).get("fileID",0)))
		while nodes.has(parent) and nodes[parent].nodeRewardsList.is_empty():
			parent=str(int(nodes[parent].get("previousUpgradeTreeNode",{}).get("fileID",0)))
		node.previousUpgradeTreeNode={"fileID":int(parent)}

func read_json(name: String):
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/" + name + ".json"))

func asset(id) -> Dictionary:
	return catalog.get(id if id is String else str(id), {})

func named(name: String) -> Dictionary:
	return names.get(name,{})

func kind(type: String) -> Array:
	return classes.get(type,[]).duplicate()

func text(key) -> String:
	if key == null:
		return ""
	var entry:Dictionary=localization.get(str(key), {})
	return str(entry.get(language, entry.get("English", key)))

func ui(english: String, chinese: String) -> String:
	return chinese if language.begins_with("Chinese") else english

func ui_text(content: String) -> String:
	var stripped = content.strip_edges()
	if language.begins_with("Chinese") and chinese_ui.literal.has(stripped):
		return str(chinese_ui.literal[stripped])
	return text(english_keys[stripped]) if english_keys.has(stripped) else content

func language_name(value: String) -> String:
	return {"English":"English", "Chinese (simplified)":"简体中文", "Chinese (traditional)":"繁體中文", "Russian":"Русский"}.get(value, value)

func title(v: Dictionary) -> String:
	if v.has("mutation_branch"):return text(v.rewardTextID)
	if v.has("insect_variant"): return text(Armaments.entries()[v.insect_variant].key)
	if v.has("coresList") and "LevelUp" in str(v.get("class","")):return text("PopUpText_LevelUp").replace("{0}",title(asset(v.coresList[0])))
	if v.get("class")=="CrusedReward":return "%s +%d%%\n%s %d%%"%[text(v.buffRewardPopUpText),v.buffPercent*100,text(v.debuffRewardPopUpText),v.debuffPercent*100]
	if v.get("class")=="CountBasicReward":return ("×%d "%int(v.rewardCount) if int(v.rewardCount)>1 else "")+text(v.rewardTextID)
	for key in ["coreNameID", "rewardTextID", "droneNameID", "MissionNameTextID"]:
		if v.has(key):
			return text(v[key]).replace("{0}",title(asset(v.coreDrone))) if v.has("coreDrone") else text(v[key])
	if v.has("blockCore"):
		return "%s ×%d" % [title(asset(v.blockCore)), v.get("coresCount", 1)]
	if v.has("core") and v.core is String:
		return ui("Head · ", "头部 · ") + title(asset(v.core))
	if v.has("drone"):
		return title(asset(v.drone)) + " ×" + str(int(v.get("dronesCount", 1)))
	if v.has("turretCore"):
		return title(asset(v.turretCore))
	if english_keys.has(str(v.get("name", ""))):return text(english_keys[str(v.name)])
	return str(v.get("name", "" )).replace("Reward_", "").replace("_", " ")

func sprite(id) -> Texture2D:
	id = str(id)
	if not sprites.has(str(id)):
		return null
	if sprites[id].has("insect_variant"):
		return Armaments.texture(str(sprites[id].insect_variant))
	if not textures.has(id):
		textures[id] = preload("res://scripts/brood_theme.gd").texture(str(sprites[id].path).get_file().get_basename()) if sprites[id].get("brood",false) else load(sprites[id].path)
	return textures[id]

func core_sprite(c: Dictionary) -> Texture2D:
	if c.has("coreTurret"):
		return sprite(asset(c.coreTurret).get("turretSprite", ""))
	if c.has("coreChip"):
		return sprite(asset(c.coreChip).get("chipSprite", ""))
	return sprite(c.get("coreSprite", ""))

func packed(value) -> Array:
	if value is Array:
		return value
	if value == null:
		return []
	var s = str(value)
	var bytes = s.hex_decode()
	var result = []
	for i in range(0, bytes.size() - 3, 4):
		result.append(bytes.decode_s32(i))
	return result

func component(prefab: String, type: String) -> Dictionary:
	for c in prefabs.get(prefab, {}).get("components", []):
		if c["class"] == type:
			return c
	return {}

func range_units(value) -> float:
	return [5.0, 9.0, 12.0, 15.0, 20.0, 7.0][clampi(int(value), 0, 5)]

func reward_sprite(reward:Dictionary)->Texture2D:
	if reward.has("mutation_branch"):return preload("res://scripts/mutation_branches.gd").texture(reward.mutation_branch)
	var variant = armament_variant(reward)
	if not variant.is_empty(): return Armaments.texture(variant)
	for field in ["blockCore","core","turretCore"]:
		if reward.get(field) is String:return core_sprite(asset(reward[field]))
	if reward.has("coresList") and not reward.coresList.is_empty():return core_sprite(asset(reward.coresList[0]))
	if reward.has("drone"):return sprite(asset(reward.drone).get("droneSprite",""))
	return sprite(reward.get("rewardSprite",""))

func armament_variant(value: Dictionary) -> String:
	return Armaments.variant(self, value)

func armament_description(value: Dictionary) -> String:
	var variant = armament_variant(value)
	return text(Armaments.entries()[variant].key + "_Desc") if not variant.is_empty() else ""
