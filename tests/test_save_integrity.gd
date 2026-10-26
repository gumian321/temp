extends SceneTree

const DB = preload("res://scripts/source_db.gd")
const Store = preload("res://scripts/save_store.gd")
const InputSystem = preload("res://scripts/input_system.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Run = preload("res://scripts/run_state.gd")
const Tutorial = preload("res://scripts/tutorial_ui.gd")
var checks: Array = []

func check(value: bool, title: String):
	checks.append({"name": title, "passed": value})
	if not value:printerr("FAIL: ", title)

func write_fixture(path: String, data: Dictionary):
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _initialize():
	var db = DB.new()
	var store = Store.new(db, "user://missing-save-integrity-directory/save.json", false)
	store.state.meta = 100000
	var before = store.state.duplicate(true)
	var mission = db.kind("Mission").filter(func(m):return int(m.MissionCost) > 0)[0]
	check(not store.unlock_mission(mission) and store.state == before, "Failed mission purchase preserves currency and locked status")
	store.state = before.duplicate(true)
	var node = db.research.filter(func(n):return n.nodeRewardsList[0] not in store.state.unlocked and store.research_prerequisite_met(n))[0]
	check(not store.unlock_research(node, 0) and store.state == before, "Failed research purchase preserves currency, unlocks and achievements")
	store.state = before.duplicate(true)
	check(not store.unlock_reward_pool(100) and store.state == before, "Failed reward-pool purchase preserves currency and system state")
	store.state = before.duplicate(true)
	store.state.systems.ToggleResearches = true
	var groups: Array = []
	var enabled: Dictionary = {}
	for id in store.state.unlocked:
		groups.append([id]);enabled[id] = groups.size() <= 5
	before = store.state.duplicate(true)
	check(not store.apply_reward_pool(groups, enabled) and store.state == before, "Failed reward-pool update preserves every enabled reward")
	check(not store.reset_progress() and store.state == before, "Failed progress reset preserves the existing profile")
	store.path = "user://save-integrity.json"
	store.fresh()
	store.state.meta = 4321
	var fixture = store.state.duplicate(true)
	fixture.settings = {"bindings": null, "language": {}, "volume": "broken", "resolution": 99999, "screen_mode": -9, "language_revision": []}
	write_fixture(store.path, fixture)
	check(store.load_save() and store.state.meta == 4321, "Malformed optional settings do not discard earned progress")
	check(store.state.settings.bindings is Dictionary and store.state.settings.language is String and store.state.settings.volume is float, "Malformed setting types fall back to valid defaults")
	check(store.state.settings.resolution == 0 and store.state.settings.screen_mode == 2, "Invalid display indices fall back before menu array indexing")
	var controls = InputSystem.new(store)
	check(InputMap.action_get_events("move_left")[0].physical_keycode == KEY_A, "Malformed bindings still allow normal keyboard input")
	fixture.settings = []
	write_fixture(store.path, fixture)
	check(store.load_save() and store.state.settings.bindings is Dictionary, "A non-object settings entry cannot interrupt loading")
	fixture.settings = {"bindings": {"move_left": [], "move_right": KEY_L, "boost": 0}, "volume": 4.0, "music": -2.0, "language": "English", "language_revision": 1}
	write_fixture(store.path, fixture)
	check(store.load_save(), "Partially valid settings can be loaded")
	controls.apply()
	check(InputMap.action_get_events("move_left")[0].physical_keycode == KEY_A and InputMap.action_get_events("move_right")[0].physical_keycode == KEY_L and InputMap.action_get_events("boost")[0].physical_keycode == KEY_SHIFT, "Valid custom keys survive while invalid bindings use defaults")
	check(store.state.settings.volume == 1.0 and store.state.settings.music == 0.0 and store.state.settings.language == "English", "Audio is bounded and an explicit language choice survives")
	var played_mission = db.kind("Mission")[0]
	fixture.scores = {played_mission.id: [], "valid-score": 912}
	fixture.statistics = {"stat_PacksOpened": {}, "stat_ScrapsCollected": [], "stat_BossesKilled": [], "valid-stat": 57}
	fixture.tutorials = {"MoveTutorial": [], "ShootTutorial": 3}
	fixture.roster_progress = {"support_modules_best": [], "boss_kills": {}}
	fixture.unlocked.append({"bad": "id"});fixture.disabled = [[], 9];fixture.missions = [null, {}]
	write_fixture(store.path, fixture)
	check(store.load_save(), "Malformed nested progress and mixed ID arrays still allow profile loading")
	var player = Body.new(db)
	var battle = Battle.new(db, player)
	var run = Run.new(db, store, player, battle, played_mission, 0)
	run.achievements.finish(run)
	run.finish(false)
	check(store.state.scores[played_mission.id] is int and store.state.statistics.stat_PacksOpened is int and store.state.statistics.stat_ScrapsCollected is int, "Damaged score and statistic values cannot interrupt end-of-run settlement")
	var tutorial = Tutorial.new()
	tutorial.save = store;tutorial.config = {"tutorialShowCount": 0}
	tutorial.show_tip("move")
	check(store.state.tutorials.MoveTutorial is int and store.state.tutorials.MoveTutorial == 1, "Damaged tutorial counters cannot interrupt first-time movement tips")
	tutorial.free()
	check(store.state.scores["valid-score"] == 912 and store.state.statistics["valid-stat"] == 57 and store.state.tutorials.ShootTutorial == 3 and store.state.roster_progress.support_modules_best == 0 and store.state.roster_progress.boss_kills == 0, "Repair preserves healthy progress while sanitizing malformed roster counters")
	store.state.meta = 71;check(store.save(), "Valid profile saves after earlier write failures")
	store.state.meta = 72;check(store.save(), "Second save creates a recoverable backup")
	DirAccess.remove_absolute(store.path)
	store.fresh()
	check(store.load_save() and store.state.meta == 71, "A missing primary file recovers the existing backup")
	check(store.save() and store.last_error.is_empty(), "A successful save clears a stale persistence error")
	FileAccess.open(store.path, FileAccess.WRITE).store_string("{damaged")
	store.state.meta = 81
	check(store.save() and store.parse_file(store.path + ".bak").meta == 71, "Saving after corruption preserves the last valid recovery copy")
	store.path = "user://save-replacement-blocked.json"
	DirAccess.make_dir_absolute(store.path)
	before = store.state.duplicate(true)
	check(not store.unlock_mission(mission) and store.state == before and not store.last_error.is_empty(), "Failure to replace the destination rolls back purchases and reports the error")
	store.path = "user://save-backup-blocked.json"
	check(store.save(), "Backup-failure fixture has a valid primary save")
	DirAccess.make_dir_absolute(store.path + ".bak")
	before = store.state.duplicate(true)
	check(not store.unlock_mission(mission) and store.state == before and store.last_error.begins_with("Cannot preserve save backup"), "Failure to create a backup preserves the saved profile and rolls back purchases")
	var report = {"passed": checks.all(func(c):return c.passed), "checks": checks}
	FileAccess.open("res://artifacts/save-integrity-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
