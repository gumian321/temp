extends SceneTree
const Roster = preload("res://scripts/character_roster.gd")
const Store = preload("res://scripts/save_store.gd")
const TEST_PATH = "user://character-roster-test-isolated.json"
var checks: Array = []

class FakeSource:
	const DEFAULT_LANGUAGE = "Chinese"
	var stores = {"RewardDataStore": {"rewardsUnlockedList": ["starter-module"]}}
	func asset(id: String) -> Dictionary:
		return {"shield": {"class": "ShieldCore"}, "gun": {"class": "ProjectileCore"}, "utility": {"class": "DroneCore", "name": "Core_Drones_Engineer"}, "attack": {"class": "DroneCore", "name": "Core_Drones_Attack"}}.get(id, {})

func check(value: bool, label: String):
	checks.append({"name": label, "passed": value})

func remove_files():
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_PATH + suffix):DirAccess.remove_absolute(TEST_PATH + suffix)

func write_fixture(data: Dictionary):
	var file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _initialize():
	remove_files()
	var db = FakeSource.new()
	var save = Store.new(db, TEST_PATH, false)
	check(Roster.is_support(db, "shield") and Roster.is_support(db, "utility") and not Roster.is_support(db, "gun") and not Roster.is_support(db, "attack") and not Roster.is_support(db, "missing"), "Support classifier excludes offensive or missing modules")
	check(save.state.roster_unlocked == ["centipede"] and save.state.selected_character == "centipede", "Fresh saves start with centipede only")
	check(Roster.ids() == ["centipede", "spider", "beetle"], "Three stable character IDs")
	check(Roster.config("centipede").slot_cap == 60 and Roster.config("spider").slot_cap == 32 and Roster.config("beetle").slot_cap == 6, "Distinct equipment caps")
	var mutated = Roster.config("spider")
	mutated.slot_cap = 999
	check(Roster.config("spider").slot_cap == 32, "Config copies cannot mutate roster")
	check(Roster.config("unknown").id == "centipede", "Unknown config has safe fallback")
	check(not save.select_character("spider") and not save.select_character("unknown"), "Locked and unknown selections rejected")
	for i in range(3):save.record_support_module()
	save.record_boss_kill()
	check(save.state.roster_unlocked == ["centipede"] and not FileAccess.file_exists(TEST_PATH), "Preview construction and events cannot unlock or write")
	save.begin_character_run()
	for i in range(3):save.record_support_module()
	check(save.character_run_support_count() == 0, "Run tracking requires explicit opt-in")
	save.begin_character_run(true)
	save.record_support_module()
	save.record_support_module()
	check(not save.character_unlocked("spider") and save.state.roster_progress.support_modules_best == 2, "Two modules record progress without unlock")
	save.end_character_run()
	save.begin_character_run(true)
	save.record_support_module()
	check(not save.character_unlocked("spider") and save.character_run_support_count() == 1, "Support count cannot carry between runs")
	save.record_support_module()
	check(save.record_support_module() == ["spider"], "Third support module in one run unlocks spider")
	check(save.record_support_module().is_empty(), "Further support modules do not duplicate unlock notification")
	check(save.select_character("spider"), "Unlocked selection saves successfully")
	var reloaded = Store.new(db, TEST_PATH)
	check(reloaded.state.selected_character == "spider" and reloaded.character_unlocked("spider"), "Selection and unlock survive process reload")
	check(reloaded.record_boss_kill().is_empty() and not reloaded.character_unlocked("beetle"), "Reload never restores active run tracking")
	reloaded.begin_character_run(true)
	reloaded.record_support_module()
	check(reloaded.character_run_support_count() == 0, "Only centipede contributes to support challenge")
	check(reloaded.record_boss_kill() == ["beetle"], "First actual boss kill unlocks beetle")
	check(reloaded.record_boss_kill().is_empty() and reloaded.state.roster_progress.boss_kills == 2, "Repeated boss kills keep accurate count without duplicate unlock")
	reloaded.end_character_run()
	reloaded.record_boss_kill()
	check(reloaded.state.roster_progress.boss_kills == 2, "End of run blocks subsequent events")
	reloaded.select_character("beetle")
	var after_boss = Store.new(db, TEST_PATH)
	check(after_boss.character_unlocked("beetle") and after_boss.state.selected_character == "beetle", "Beetle survives save reload")
	var legacy = save.state.duplicate(true)
	legacy.erase("roster_unlocked")
	legacy.erase("selected_character")
	legacy.erase("roster_progress")
	legacy.meta = 321
	legacy.unlocked = ["starter-module", "earned-module"]
	legacy.achievements = ["existing-achievement"]
	legacy.settings.volume = 0.25
	legacy.statistics = {"stat_BossesKilled": 1}
	write_fixture(legacy)
	var migrated = Store.new(db, TEST_PATH)
	check(migrated.character_unlocked("beetle") and not migrated.character_unlocked("spider"), "Legacy proven boss statistic migrates beetle only")
	check(migrated.state.meta == 321 and migrated.state.unlocked == legacy.unlocked and migrated.state.achievements == legacy.achievements and migrated.state.settings.volume == 0.25, "Migration preserves currency, research, achievements, settings")
	legacy.statistics = {"stat_PacksOpened": 20}
	legacy.achievements = ["ACH_WEASEL"]
	write_fixture(legacy)
	check(Store.new(db, TEST_PATH).state.roster_unlocked == ["centipede"], "Boss hunt win without boss kill is not unlock evidence")
	legacy.roster_unlocked = ["unknown", "spider", "spider", 123]
	legacy.selected_character = "beetle"
	legacy.roster_progress = {"support_modules_best": "invalid", "boss_kills": -10}
	write_fixture(legacy)
	var repaired = Store.new(db, TEST_PATH)
	check(repaired.state.roster_unlocked == ["centipede", "spider"] and repaired.state.selected_character == "centipede", "Malformed roster IDs and locked selection sanitized")
	check(repaired.state.roster_progress == {"support_modules_best": 0, "boss_kills": 0}, "Malformed progress normalized")
	repaired.path = "user://missing-roster-test-directory/invalid.json"
	check(not repaired.select_character("spider") and repaired.state.selected_character == "centipede", "Failed selection save rolls back in-memory choice")
	repaired.begin_character_run(true)
	check(repaired.record_boss_kill().is_empty() and not repaired.character_unlocked("beetle"), "Failed persistence cannot report or retain unlock")
	repaired.path = TEST_PATH
	repaired.state.settings.volume = 0.31
	repaired.reset_progress()
	check(repaired.state.roster_unlocked == ["centipede"] and repaired.state.selected_character == "centipede" and repaired.state.settings.volume == 0.31, "Reset progress clears roster while preserving settings")
	remove_files()
	var passed = checks.all(func(c):return c.passed)
	print(JSON.stringify({"passed": passed, "checks": checks}))
	quit(0 if passed else 1)
