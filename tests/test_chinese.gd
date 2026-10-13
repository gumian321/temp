extends SceneTree

const DB = preload("res://scripts/source_db.gd")
const Save = preload("res://scripts/save_store.gd")
const FIXTURE = "res://artifacts/chinese-test-save.json"
var checks: Array = []

func check(value: bool, description: String):
	checks.append({"name":description, "passed":value})
	if not value:printerr("FAIL: ", description)

func _initialize():
	call_deferred("execute")

func write_fixture(state: Dictionary):
	var file = FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()

func texts(node: Node) -> Array:
	var result: Array = []
	if node is Label or node is Button:result.append(node.text)
	for child in node.get_children():result.append_array(texts(child))
	return result

func execute():
	var db = DB.new()
	var save = Save.new(db, FIXTURE, false)
	check(db.language == "Chinese (simplified)" and save.state.settings.language == db.language, "Fresh game and database both default to Simplified Chinese")
	var legacy: Dictionary = save.state.duplicate(true)
	legacy.settings.language = "English"
	legacy.settings.erase("language_revision")
	legacy.meta = 4321
	legacy.unlocked.append("test-researched-turret")
	legacy.disabled = ["test-disabled-reward"]
	legacy.missions = ["test-mission"]
	legacy.scores = {"test-mission":12345}
	legacy.achievements = ["test-achievement"]
	legacy.blueprint = [{"core":"test-turret", "cell":[0, -1]}]
	legacy.tutorials = {"MoveTutorial":2}
	legacy.statistics = {"wins":7}
	legacy.settings.bindings = {"move_up":KEY_UP}
	# JSON numbers load as floats; compare against the serialized save shape.
	legacy = JSON.parse_string(JSON.stringify(legacy))
	write_fixture(legacy)
	var migrated = Save.new(db, FIXTURE)
	check(migrated.state.settings.language == db.DEFAULT_LANGUAGE, "Legacy English save adopts Chinese")
	var preserved = true
	for key in ["meta", "unlocked", "disabled", "missions", "scores", "achievements", "blueprint", "tutorials", "statistics"]:
		preserved = preserved and migrated.state[key] == legacy[key]
	check(preserved and migrated.state.settings.bindings == legacy.settings.bindings, "Language migration preserves progression, blueprint and controls")
	check(migrated.save(), "Migrated fixture saves successfully")
	var reloaded = Save.new(db, FIXTURE)
	check(reloaded.state.settings.language == db.DEFAULT_LANGUAGE and int(reloaded.state.settings.language_revision) == 1, "Chinese default and migration marker persist across reload")
	reloaded.state.settings.language = "English"
	check(reloaded.save(), "User-selected English setting saves successfully")
	var english = Save.new(db, FIXTURE)
	check(english.state.settings.language == "English", "Later explicit English choice survives reload")
	english.reset_progress()
	check(english.state.settings.language == "English" and english.state.settings.bindings == legacy.settings.bindings, "Resetting progression preserves language and controls")
	legacy.settings.language = "Chinese (traditional)"
	write_fixture(legacy)
	var traditional = Save.new(db, FIXTURE)
	check(traditional.state.settings.language == "Chinese (traditional)", "Existing non-English preference remains intact")
	check(db.title(db.named("Core_Gun_Gatling")) == "蜂尾针簇", "Weapon names appear in Chinese")
	check(db.text("Tutorial_Build") == "逐节装塔" and db.text("Part_HQ").contains("蜈蚣"), "Tutorial and protagonist text match the centipede design")
	check(db.text("HQ") == "蜈蚣头部" and db.text("HQ_Health") == "头部耐久" and db.text("PopUpText_HQTurret").contains("头部") and db.text("Chip_HQ") == "统御触角", "Head stats, reward popups and control chip no longer describe a mothership")
	check(db.text("Legend_Boss") == "首领" and db.text("Options_SkipBossesAnimation") == "跳过首领动画", "Boss labels are fully Chinese")
	check(db.language_name(db.DEFAULT_LANGUAGE) == "简体中文", "Language setting uses a readable native label")
	var menu = load("res://scripts/source_ui.gd").new()
	root.add_child(menu)
	menu.setup(db, "MainMenuScene/MenuCanvas", func(_m, _id, _args):pass)
	var menu_text = texts(menu)
	check("开始" in menu_text and "选项" in menu_text and "更新资讯" in menu_text, "Actual main-menu labels render in Chinese, including formerly unlocalized copy")
	var tutorial = load("res://scripts/tutorial_ui.gd").new()
	root.add_child(tutorial)
	tutorial.setup(db, save)
	check("逐节装塔" in texts(tutorial), "Actual tutorial UI contains the Chinese segment-building prompt")
	var lab = load("res://scripts/research_ui.gd").new()
	root.add_child(lab)
	lab.setup(db, save, func():pass, func():pass)
	var lab_text = texts(lab)
	check("拖动 · 缩放" in lab_text and "◈ 55" in lab_text, "Research navigation is Chinese and current research balance is displayed")
	var intro = load("res://scripts/intro_ui.gd").new()
	root.add_child(intro)
	intro.setup(db, func():pass)
	check("支持键鼠与手柄操作" in texts(intro), "Intro instruction is localized")
	tutorial.show_tip("move")
	tutorial.elapsed = 12.5
	var active_tip = tutorial.shown.get("move")
	db.language = "English"
	tutorial.refresh_language()
	check("Move" in texts(tutorial) and "移动蜈蚣" not in texts(tutorial), "Changing language refreshes existing tutorial text")
	check(tutorial.shown.get("move") == active_tip and is_equal_approx(tutorial.elapsed, 12.5) and int(save.state.tutorials.MoveTutorial) == 1 and tutorial.view.controls[tutorial.ref("move")].visible, "Tutorial language refresh preserves active tween, visibility, elapsed time and saved count")
	check(db.text("Menu_Start") == "Start" and db.ui_text("Press to continue") == "Press to continue", "English remains selectable without Chinese overrides leaking")
	for node in [menu, tutorial, lab, intro]:node.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(FIXTURE + suffix):DirAccess.remove_absolute(FIXTURE + suffix)
	var report = {"passed":checks.all(func(c):return c.passed), "checks":checks, "save_isolation":"Only res://artifacts/chinese-test-save.json is accessed."}
	FileAccess.open("res://artifacts/chinese-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
