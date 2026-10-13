extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Art = preload("res://scripts/insect_armaments.gd")
var checks: Array = []
func check(ok: bool, label: String):
	checks.append({"name":label, "passed":ok})
	if not ok: printerr("FAIL: ", label)
func _initialize():
	var db = DB.new()
	var original: Dictionary = db.read_json("catalog")
	check(Art.entries().size() == 33, "33 distinct anatomical equipment and entity identities")
	var total_guns = 0
	var total_devices = 0
	for value in db.catalog.values():
		var unchanged = value.duplicate(true)
		unchanged.erase("insect_variant")
		if original[value.id].has("coreNameID"): unchanged.coreNameID = original[value.id].coreNameID
		else: unchanged.erase("coreNameID")
		if original[value.id].has("rewardDesc"): unchanged.rewardDesc = original[value.id].rewardDesc
		else: unchanged.erase("rewardDesc")
		check(unchanged == original[value.id], "Stable IDs, internal names and mechanics: " + str(value.name))
		if value.has("coreProjectile"): total_guns += 1
		if value.has("coreTurret") or value.has("coreChip"):
			total_devices += 1
			var key = db.armament_variant(value)
			check(not key.is_empty(), "Every mounted core has anatomical identity: " + value.name)
			if key.is_empty(): continue
			check(db.title(value) == Art.entries()[key].zh, "Chinese core title: " + value.name)
			check(not db.armament_description(value).is_empty(), "Factual description: " + value.name)
			db.language = "English"
			check(db.title(value) == Art.entries()[key].en, "English core title: " + value.name)
			db.language = db.DEFAULT_LANGUAGE
		if "Reward" in str(value.get("class", "")):
			var key = db.armament_variant(value)
			if not key.is_empty(): check(db.text(value.rewardDesc) == Art.entries()[key].description_zh, "Reward/research description shares current identity: " + value.name)
	check(total_guns == 32, "All 32 player, HQ and enemy gun cores covered")
	check(db.title(db.named("Core_Drones_Attack")) == "猎蜂巢", "Drone bay name is distinct from deployed hunter wasp")
	check(db.ui_text("Gatling Gun") == "蜂尾针簇", "Legacy literal name resolves to new display name")
	check(db.title(db.named("Reward_LevelUP_Gun_Gatling")).contains("蜂尾针簇"), "Level-up title uses new family name")
	var report = {"checks":checks,"passed":checks.all(func(c):return c.passed),"gun_cores":total_guns,"mounted_cores":total_devices,"scope":"Names, description coverage, stable IDs and unchanged combat data; image QA is a separate render check."}
	FileAccess.open("res://artifacts/insect-armaments-catalog-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("INSECT_ARMAMENTS ",checks.size()," ",report.passed)
	quit(0 if report.passed else 1)
