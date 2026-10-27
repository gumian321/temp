extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const LANGUAGES=["Chinese (simplified)","Chinese (traditional)","English","Russian"]
var game
var checks:Array=[]
var violations:Array=[]
var audited=0
var banned=RegEx.new()
func _initialize():
	banned.compile("(?i)飞船|飛船|船只|船隻|舰|艦|空间站|空間站|小行星|太空|星际|星際|宇航|航线|航線|跃迁|躍遷|炮塔|无人机|無人機|机库|機庫|装塔|裝塔|\\b(?:ships?|spaceships?|starships?|spacecraft|motherships?|fleets?|stations?|turrets?|drones?|asteroids?|hangars?)\\b|корабл|флот|станци|дрон|ангар|астероид")
	call_deferred("execute")
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:push_error(title)
func inspect_text(value:String,where:String):
	audited+=1
	if banned.search(value)!=null:violations.append({"where":where,"text":value})
func inspect_tree(node:Node,where:String):
	if node is Control and node.is_visible_in_tree():
		inspect_text(node.tooltip_text,where+"/tooltip")
		if node is Label or node is Button or node is RichTextLabel:inspect_text(node.text,where+"/text")
	for child in node.get_children():inspect_tree(child,where+"/"+str(child.name))
func settle():
	await process_frame
	await process_frame
func show_cards(rewards:Array):
	game.run.rewards.enqueue(true);game.run.offers=rewards.duplicate();game.show_rewards();await settle()
func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.fresh();game.save.unlock_all_content()
	var db=game.db
	var cards=[db.named("Reward_Cursed_Runner"),db.named("Reward_Cursed_Shotgun"),db.named("Reward_Cursed_Skirmish")]
	for language in LANGUAGES:
		db.language=language
		for key in db.localization:inspect_text(db.text(key),language+"/localization/"+key)
		for source_text in db.chinese_ui.get("aliases",{}):inspect_text(db.ui_text(source_text),language+"/source-literal")
		for value in db.catalog.values():
			if "Reward" in str(value.get("class","")) and not value.get("retired",false):
				inspect_text(db.title(value),language+"/reward/"+value.name)
		for method in ["show_menu","show_characters","show_options","show_controls","show_lab","show_reward_pool","show_changelog"]:
			game.call(method);await settle();inspect_tree(game.panel,language+"/"+method)
		for mission in db.stores.MissionDataStore.missionsList:
			game.selected_mission=db.asset(mission);game.show_missions();await settle();inspect_tree(game.panel,language+"/mission")
		game.start_run();await settle()
		for method in ["show_game","show_build_ui","show_pause","show_loading"]:
			game.call(method);await settle();inspect_tree(game.panel,language+"/"+method)
		game.show_game();await show_cards(cards)
		inspect_tree(game.panel,language+"/screenshot-rewards")
		for value in db.kind("CrusedReward"):
			inspect_text(game.reward_ui.reward_title(value),language+"/tradeoff-title")
			inspect_text(game.reward_ui.effect_text(value),language+"/tradeoff-tooltip")
			inspect_text(game.reward_ui.progress_info(value).tooltip,language+"/tradeoff-progress")
		if language==db.DEFAULT_LANGUAGE:
			check(db.title(cards[2])=="移动速度 +20%\n武器伤害 -20%","Screenshot reward names movement speed and weapon damage correctly")
			check(db.title(cards[0])=="移动速度 +20%\n武器射程 -20%","Screenshot range penalty describes weapon range")
			check(db.title(cards[1])=="武器伤害 +20%\n武器射程 -20%","Damage bonus is not described as damage to the body")
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/insect-copy-rewards-20261026.png")
		game.run.finish(false);game.show_result();await settle();inspect_tree(game.panel,language+"/result")
	for path in ["res://data/changelog.txt","res://data/changelog_zh.txt"]:inspect_text(FileAccess.get_file_as_string(path),path)
	for path in ["centipede","main","mission_select","battle_hud","escort_guidance","reward_choice","passive_feedback"]:
		var code=FileAccess.get_file_as_string("res://scripts/"+path+".gd")
		var chinese=RegEx.new();chinese.compile("飞船|飛船|舰|艦|空间站|空間站|炮塔|无人机|無人機|机库|機庫|小行星|装塔|裝塔|一艘")
		check(chinese.search(code)==null,"Runtime wording is biological: "+path)
	check(violations.is_empty(),"All selectable languages, source literals and actual interface text exclude legacy space-combat terms")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"audited_strings":audited,"violations":violations,"languages":LANGUAGES,"renderer":DisplayServer.get_name()}
	FileAccess.open("res://artifacts/insect-copy-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
	quit(0 if report.passed else 1)
