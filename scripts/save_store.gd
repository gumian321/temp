extends RefCounted

const CharacterRoster = preload("res://scripts/character_roster.gd")
const FULL_UNLOCK_REQUEST = "user://unlock-all-on-next-start.request"
const DEBUG_RESEARCH_POINTS = 10000
var _character_run_active = false
var _character_run_id = "centipede"
var _character_run_support = 0

var path = "user://centipede-save.json"
var state: Dictionary
var db
var last_error = ""

func _init(source, save_path: String = "user://centipede-save.json", load_existing: bool = true):
	db = source
	path = save_path
	fresh()
	if load_existing:
		load_save()
		_apply_requested_unlock()

func unlock_all_content() -> bool:
	var previous=state.duplicate(true)
	for id in CharacterRoster.ids():
		if id not in state.roster_unlocked:state.roster_unlocked.append(id)
	for id in db.stores.MissionDataStore.missionsList:
		if id not in state.missions:state.missions.append(id)
	for node in db.research:
		for id in node.nodeRewardsList:
			if id not in state.unlocked:state.unlocked.append(id)
	for reward in db.catalog.values():
		if str(reward.get("class","")).ends_with("Reward") and not reward.get("retired",false) and reward.id not in state.unlocked:
			state.unlocked.append(reward.id)
	state.disabled=state.disabled.filter(func(id):return id not in state.unlocked)
	state.systems.ToggleResearches=true
	if save():return true
	state=previous
	return false

func reset_skill_progress() -> bool:
	var previous=state.duplicate(true)
	state.unlocked=db.stores.RewardDataStore.rewardsUnlockedList.duplicate()
	state.disabled.clear()
	state.systems.erase("ToggleResearches")
	state.meta=maxi(int(state.meta),DEBUG_RESEARCH_POINTS)
	if save():return true
	state=previous
	return false

func _apply_requested_unlock():
	# Only an explicit request for the normal player profile enables this. Other
	# save paths, new profiles and isolated tests retain the usual unlock rules.
	if path!="user://centipede-save.json" or not FileAccess.file_exists(FULL_UNLOCK_REQUEST):return
	if FileAccess.get_file_as_string(FULL_UNLOCK_REQUEST).strip_edges()!="unlock-all":return
	if unlock_all_content():DirAccess.remove_absolute(FULL_UNLOCK_REQUEST)

func fresh():
	end_character_run()
	state = {"version": 1, "roster_unlocked": ["centipede"], "selected_character": "centipede", "roster_progress": {"support_modules_best": 0, "boss_kills": 0}, "systems": {}, "meta": 55, "unlocked": [], "disabled": [], "missions": [], "scores": {}, "achievements": [], "settings": {"volume": 0.7, "music": 0.5, "sfx": 0.8, "language": db.DEFAULT_LANGUAGE, "language_revision": 1, "skip_boss": false,"resolution":0,"screen_mode":2,"bindings":{},"invert_x":false,"invert_y":false,"left_aim":false}, "blueprint": [],"tutorials":{},"statistics":{}}
	for id in db.stores.get("RewardDataStore", {}).get("rewardsUnlockedList", []):
		state.unlocked.append(id)

func reset_progress() -> bool:
	var previous = state.duplicate(true)
	var settings:Dictionary=state.settings.duplicate(true)
	fresh()
	for key in settings:state.settings[key]=settings[key]
	return _save_change(previous)

func load_save() -> bool:
	end_character_run()
	last_error = ""
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"):
		return false
	var parsed = parse_file(path) if FileAccess.file_exists(path) else null
	if not _valid_save(parsed):
		if FileAccess.file_exists(path+".bak"):
			var backup=parse_file(path+".bak")
			if _valid_save(backup):
				parsed=backup
				last_error="Recovered previous atomic backup; damaged primary file preserved."
		if not _valid_save(parsed):
			last_error = "Invalid save; new defaults retained. Original file preserved."
			return false
	for k in state:
		if parsed.has(k) and typeof(parsed[k]) == typeof(state[k]):
			if k=="settings":
				_load_settings(parsed.settings)
			else:state[k] = parsed[k]
	state.meta = maxi(0, int(parsed.meta))
	# Adopt the Chinese-first default once for old English saves. The marker is
	# persisted by normal saves, so a later explicit language choice is respected.
	var previous_settings = parsed.get("settings", {})
	var revision = previous_settings.get("language_revision", 0) if previous_settings is Dictionary else 0
	if not _finite_number(revision) or int(revision) < 1:
		if state.settings.language == "English":state.settings.language = db.DEFAULT_LANGUAGE
		state.settings.language_revision = 1
	state.unlocked=state.unlocked.filter(func(id):return not db.asset(id).get("retired",false))
	state.disabled=state.disabled.filter(func(id):return not db.asset(id).get("retired",false))
	for id in db.stores.RewardDataStore.rewardsUnlockedList:
		if id not in state.unlocked:
			state.unlocked.append(id)
			state.disabled.erase(id)
	# These dictionaries are incremented or converted to integers by settlement
	# and tutorial code. Salvage healthy entries if an individual value is bad.
	for field in ["scores", "statistics", "tutorials"]:
		for key in state[field]:
			if not _finite_number(state[field][key]):state[field][key] = 0
	_normalize_roster()
	return true

func _finite_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _valid_save(value) -> bool:
	return value is Dictionary and value.get("version") == 1 and _finite_number(value.get("meta"))

func _load_settings(settings: Dictionary):
	# Optional settings can be damaged independently of earned progress. Keep
	# defaults for wrong types, while accepting JSON's numeric representation.
	for key in state.settings:
		if not settings.has(key):continue
		var value = settings[key]
		var current = state.settings[key]
		if current is int:
			if _finite_number(value):state.settings[key] = int(value)
		elif current is float:
			if _finite_number(value):state.settings[key] = clampf(float(value), 0.0, 1.0)
		elif typeof(value) == typeof(current):state.settings[key] = value.duplicate(true) if value is Dictionary else value
	var bindings: Dictionary = state.settings.bindings
	for action in bindings.keys():
		if not _finite_number(bindings[action]) or int(bindings[action]) <= 0:
			bindings.erase(action)
	# Match the actual options arrays so old or partial settings cannot index
	# outside them when opening the settings menu.
	var scene_config = db.get("scene_config")
	var options: Dictionary = scene_config.get("OptionMenuManager", {}) if scene_config is Dictionary else {}
	for setting in ["resolution", "screen_mode"]:
		var entries: Array = options.get("resolutions" if setting == "resolution" else "screenModesList", [])
		if int(state.settings[setting]) < 0 or (not entries.is_empty() and int(state.settings[setting]) >= entries.size()):
			state.settings[setting] = 0 if setting == "resolution" else 2

# Purchases and destructive profile edits commit together with their save.
func _save_change(previous: Dictionary) -> bool:
	if save():return true
	state = previous
	return false

func save() -> bool:
	var f = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		last_error = "Cannot write save"
		return false
	f.store_string(JSON.stringify(state, "\t"))
	f.flush()
	var write_error = f.get_error()
	f.close()
	if write_error != OK:
		last_error = "Cannot finish writing save: " + error_string(write_error)
		return false
	# Never replace a known-good recovery copy with a corrupt primary file.
	if FileAccess.file_exists(path) and _valid_save(parse_file(path)):
		var backup_error = ERR_ALREADY_EXISTS if DirAccess.dir_exists_absolute(path + ".bak") else DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			last_error = "Cannot preserve save backup: " + error_string(backup_error)
			return false
	var err = DirAccess.rename_absolute(path + ".tmp", path)
	last_error = "" if err == OK else "Cannot replace save: " + error_string(err)
	return err == OK

func available(id: String) -> bool:
	return id in state.unlocked and id not in state.disabled and not db.asset(id).get("retired",false)

func mission_unlocked(m: Dictionary) -> bool:
	return int(m.get("MissionCost", 0)) == 0 or m.id in state.missions

func unlock_mission(m: Dictionary) -> bool:
	if mission_unlocked(m):
		return true
	if state.meta < m.MissionCost:
		return false
	var previous = state.duplicate(true)
	state.meta -= int(m.MissionCost)
	state.missions.append(m.id)
	return _save_change(previous)

func research_price(node: Dictionary, index: int) -> int:
	var r: Dictionary = db.asset(node.nodeRewardsList[index])
	if int(r.get("rewardOverrideCost", -1)) >= 0:
		return int(r.rewardOverrideCost)
	var d: Dictionary = db.stores.UpgradeTreeDataStore
	var rarity = 1.0
	for x in d.rarityTreeValuesList:
		if int(x.rarity) == int(r.rarity):
			rarity = float(x.rarityValue)
	var base = float(d.scrapBaseValue) * float(node.nodeBaseValue)
	return int(ceil((base * rarity + index * float(d.subRate) * base) / 5.0) * 5.0)

func research_prerequisite_met(node:Dictionary)->bool:
	var previous=str(int(node.get("previousUpgradeTreeNode",{}).get("fileID",0)))
	for parent in db.research:
		if parent.id!=previous:continue
		var required=mini(int(node.get("prerequisite_level",1)),parent.nodeRewardsList.size())
		for i in required:
			if parent.nodeRewardsList[i] not in state.unlocked:return false
	return true

func unlock_research(node: Dictionary, index: int) -> bool:
	var id: String = node.nodeRewardsList[index]
	if db.asset(id).get("retired",false):return false
	if id in state.unlocked:
		return false
	for i in range(index):
		if node.nodeRewardsList[i] not in state.unlocked:
			return false
	if not research_prerequisite_met(node):return false
	var cost = research_price(node, index)
	if state.meta < cost:
		return false
	var previous = state.duplicate(true)
	state.meta -= cost
	state.unlocked.append(id)
	check_lab_achievements()
	return _save_change(previous)

func unlock_reward_pool(cost:int)->bool:
	if state.systems.get("ToggleResearches",false):return false
	if cost<0 or state.meta<cost:return false
	var previous = state.duplicate(true)
	state.meta-=cost
	state.systems.ToggleResearches=true
	return _save_change(previous)

func apply_reward_pool(groups:Array,enabled:Dictionary)->bool:
	if not state.systems.get("ToggleResearches",false):return false
	var count=0
	for group in groups:
		if group[0] in state.unlocked and enabled.get(group[0],false):count+=1
	if count<5:return false
	var previous = state.duplicate(true)
	for group in groups:
		var active=group[0] in state.unlocked and enabled.get(group[0],false)
		for id in group:
			if active:state.disabled.erase(id)
			elif id not in state.disabled:state.disabled.append(id)
	return _save_change(previous)

func check_lab_achievements():
	var rewards:Array=[]
	for node in db.research:rewards.append_array(node.nodeRewardsList)
	var count=rewards.filter(func(id):return id in state.unlocked).size()
	var completed:Array=[]
	if count>=rewards.size()/2.0:completed.append("ACH_LAB_HALF")
	if count==rewards.size():completed.append("ACH_LAB_FULL")
	for rarity in range(4):
		var group=rewards.filter(func(id):return int(db.asset(id).rarity)==rarity)
		if not group.is_empty() and group.all(func(id):return id in state.unlocked):completed.append(["ACH_LAB_COMMON","ACH_LAB_RARE","ACH_LAB_EPIC","ACH_LAB_LEGENDARY"][rarity])
	for id in completed:
		if id not in state.achievements:state.achievements.append(id)

func parse_file(filename:String):
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(filename))!=OK:return null
	return parser.data

# Roster data is additive to save version 1, preserving all pre-roster progress.
# Retired IDs are filtered here; only their selection falls back, never the profile.
func _normalize_roster():
	var unlocked: Array = [CharacterRoster.DEFAULT_ID]
	for id in state.roster_unlocked:
		if id is String and CharacterRoster.has_character(id) and id not in unlocked:
			unlocked.append(id)
	state.roster_unlocked = unlocked
	for key in ["support_modules_best", "boss_kills"]:
		var value = state.roster_progress.get(key, 0)
		state.roster_progress[key] = maxi(0, int(value)) if value is int or value is float else 0
	# combat.gd records actual boss deaths in stat_BossesKilled;
	# achievements.finish adds that run statistic to persistent totals.
	var historical = state.statistics.get("stat_BossesKilled", 0)
	if (historical is int or historical is float) and historical > 0:
		state.roster_progress.boss_kills = maxi(state.roster_progress.boss_kills, int(historical))
	if state.roster_progress.support_modules_best >= 3 and "spider" not in unlocked:
		state.roster_unlocked.append("spider")
	if not character_unlocked(state.selected_character):
		state.selected_character = CharacterRoster.DEFAULT_ID

func character_unlocked(id: String) -> bool:
	return CharacterRoster.has_character(id) and id in state.roster_unlocked

func unlock_all_characters() -> bool:
	var previous: Array = state.roster_unlocked.duplicate()
	for id in CharacterRoster.ids():
		if id not in state.roster_unlocked:state.roster_unlocked.append(id)
	if save():return true
	state.roster_unlocked = previous
	return false

func select_character(id: String) -> bool:
	if not character_unlocked(id):return false
	if state.selected_character == id:return true
	var previous: String = state.selected_character
	state.selected_character = id
	if save():return true
	state.selected_character = previous
	return false

## Explicit opt-in prevents previews and test construction from tracking progress.
func begin_character_run(track_progress: bool = false, character_id: String = ""):
	end_character_run()
	_character_run_id = state.selected_character if character_id.is_empty() else character_id
	_character_run_active = track_progress and character_unlocked(_character_run_id)

func end_character_run():
	_character_run_active = false
	_character_run_support = 0

func character_run_support_count() -> int:
	return _character_run_support

## Call only for successful acquisition, not moving or reinstalling old modules.
func record_support_module() -> Array:
	if not _character_run_active or _character_run_id != "centipede":return []
	_character_run_support += 1
	if _character_run_support <= int(state.roster_progress.support_modules_best):return []
	var previous = state.duplicate(true)
	state.roster_progress.support_modules_best = _character_run_support
	var unlocked: Array = []
	if _character_run_support >= 3 and not character_unlocked("spider"):
		state.roster_unlocked.append("spider")
		unlocked.append("spider")
	if not save():
		state = previous
		return []
	return unlocked

func record_boss_kill() -> Array:
	if not _character_run_active:return []
	var previous = state.duplicate(true)
	state.roster_progress.boss_kills = int(state.roster_progress.boss_kills) + 1
	# Historical statistics remain compatible; bosses no longer unlock a character.
	if not save():
		state = previous
		return []
	return []
