extends RefCounted

var path = "user://centipede-save.json"
var state: Dictionary
var db
var last_error = ""

func _init(source):
	db = source
	fresh()
	load_save()

func fresh():
	state = {"version": 1, "systems": {}, "meta": 55, "unlocked": [], "disabled": [], "missions": [], "scores": {}, "achievements": [], "settings": {"volume": 0.7, "music": 0.5, "sfx": 0.8, "language": "English", "skip_boss": false,"resolution":0,"screen_mode":2,"bindings":{},"invert_x":false,"invert_y":false,"left_aim":false}, "blueprint": [],"tutorials":{},"statistics":{}}
	for id in db.stores.get("RewardDataStore", {}).get("rewardsUnlockedList", []):
		state.unlocked.append(id)

func reset_progress():
	var settings:Dictionary=state.settings.duplicate(true)
	fresh()
	for key in ["volume","music","sfx","resolution","screen_mode","skip_boss"]:state.settings[key]=settings[key]
	save()

func load_save() -> bool:
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
