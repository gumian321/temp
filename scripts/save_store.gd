extends RefCounted

const CharacterRoster = preload("res://scripts/character_roster.gd")
const FULL_UNLOCK_REQUEST = "user://unlock-all-on-next-start.request"
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
	for id in CharacterRoster.ids():
		if id not in state.roster_unlocked:state.roster_unlocked.append(id)
	for id in db.stores.MissionDataStore.missionsList:
		if id not in state.missions:state.missions.append(id)
	for node in db.research:
		for id in node.nodeRewardsList:
			if id not in state.unlocked:state.unlocked.append(id)
	for reward in db.catalog.values():
		if str(reward.get("class","")).ends_with("Reward") and reward.id not in state.unlocked:
			state.unlocked.append(reward.id)
	state.disabled=state.disabled.filter(func(id):return id not in state.unlocked)
	state.systems.ToggleResearches=true
	return save()

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

func reset_progress():
	var settings:Dictionary=state.settings.duplicate(true)
	fresh()
	for key in settings:state.settings[key]=settings[key]
	save()

func load_save() -> bool:
	end_character_run()
	if not FileAccess.file_exists(path):
		return false
	var parsed = parse_file(path)
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("meta") is float:
		if FileAccess.file_exists(path+".bak"):
			var backup=parse_file(path+".bak")
			if backup is Dictionary and backup.get("version")==1 and backup.get("meta") is float:
				parsed=backup
				last_error="Recovered previous atomic backup; damaged primary file preserved."
		if not parsed is Dictionary or parsed.get("version")!=1 or not parsed.get("meta") is float:
			last_error = "Invalid save; new defaults retained. Original file preserved."
			return false
	for k in state:
		if parsed.has(k) and typeof(parsed[k]) == typeof(state[k]):
			if k=="settings":
				for setting in state.settings:
					if parsed.settings.has(setting):state.settings[setting]=parsed.settings[setting]
			else:state[k] = parsed[k]
	state.meta = int(parsed.meta)
	# Adopt the Chinese-first default once for old English saves. The marker is
	# persisted by normal saves, so a later explicit language choice is respected.
	var previous_settings: Dictionary = parsed.get("settings", {})
	if int(previous_settings.get("language_revision", 0)) < 1:
		if state.settings.language == "English":state.settings.language = db.DEFAULT_LANGUAGE
		state.settings.language_revision = 1
	_normalize_roster()
	return true

func save() -> bool:
	var f = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		last_error = "Cannot write save"
		return false
	f.store_string(JSON.stringify(state, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var err = DirAccess.rename_absolute(path + ".tmp", path)
	return err == OK

func available(id: String) -> bool:
	return id in state.unlocked and id not in state.disabled

func mission_unlocked(m: Dictionary) -> bool:
	return int(m.get("MissionCost", 0)) == 0 or m.id in state.missions

func unlock_mission(m: Dictionary) -> bool:
	if mission_unlocked(m):
		return true
	if state.meta < m.MissionCost:
		return false
	state.meta -= int(m.MissionCost)
	state.missions.append(m.id)
	return save()

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

func unlock_research(node: Dictionary, index: int) -> bool:
	var id: String = node.nodeRewardsList[index]
	if id in state.unlocked:
		return false
	for i in range(index):
		if node.nodeRewardsList[i] not in state.unlocked:
			return false
	var previous = str(int(node.get("previousUpgradeTreeNode", {}).get("fileID", 0)))
	for n in db.research:
		if n.id == previous and n.nodeRewardsList[0] not in state.unlocked:
			return false
	var cost = research_price(node, index)
	if state.meta < cost:
		return false
	state.meta -= cost
	state.unlocked.append(id)
	check_lab_achievements()
	return save()

func unlock_reward_pool(cost:int)->bool:
	if state.systems.get("ToggleResearches",false):return false
	if state.meta<cost:return false
	state.meta-=cost
	state.systems.ToggleResearches=true
	return save()

func apply_reward_pool(groups:Array,enabled:Dictionary)->bool:
	if not state.systems.get("ToggleResearches",false):return false
	var count=0
	for group in groups:
		if group[0] in state.unlocked and enabled.get(group[0],false):count+=1
	if count<5:return false
	for group in groups:
		var active=group[0] in state.unlocked and enabled.get(group[0],false)
		for id in group:
			if active:state.disabled.erase(id)
			elif id not in state.disabled:state.disabled.append(id)
	return save()

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
	if state.roster_progress.boss_kills > 0 and "beetle" not in unlocked:
		state.roster_unlocked.append("beetle")
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
	var unlocked: Array = []
	if not character_unlocked("beetle"):
		state.roster_unlocked.append("beetle")
		unlocked.append("beetle")
	if not save():
		state = previous
		return []
	return unlocked
