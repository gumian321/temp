extends SceneTree
## Main-scene layout acceptance: actual small viewports and stretched windows.
var game
var checks: Array = []
var captures: Array = []
var issues: Array = []
var measurements: Array = []

func _initialize(): call_deferred("execute")
func settle():
	for i in 4: await process_frame
func check(ok: bool, title: String):
	checks.append({"name": title, "passed": ok})
	if not ok: printerr("FAIL: ", title)

func label_text(control: Control) -> String:
	return str(control.text).replace("\n", " / ").left(70) if control is Label or control is Button else str(control.name)

func clipped_by_view(control: Control) -> bool:
	var ancestor = control.get_parent()
	while ancestor != null and ancestor != game.panel:
		if ancestor is ScrollContainer or (ancestor is Control and ancestor.clip_contents): return true
		ancestor = ancestor.get_parent()
	return false

func body_hotspot(control: Control) -> bool:
	var ancestor = control.get_parent()
	while ancestor != null:
		if ancestor.has_method("world_to_view"): return true
		ancestor = ancestor.get_parent()
	return false

func collect(node: Node, buttons: Array, labels: Array):
	if node is Control and not node.is_visible_in_tree(): return
	if node is Button and not body_hotspot(node): buttons.append(node)
	if node is Label and not node.text.is_empty() and not body_hotspot(node): labels.append(node)
	for child in node.get_children(): collect(child, buttons, labels)

func audit(tag: String, target: Control):
	var buttons: Array = []; var labels: Array = []
	collect(target, buttons, labels)
	if tag.begins_with("game"):collect(game.tutorials.view,buttons,labels)
	var viewport = root.get_visible_rect().grow(1)
	var found: Array = []
	for button in buttons:
		if not clipped_by_view(button) and not viewport.encloses(button.get_global_rect()):
			found.append("button outside: " + label_text(button))
		if not button.text.is_empty() and not button.text.contains("\n"):
			var font=button.get_theme_font("font");var px=button.get_theme_font_size("font_size")
			var available=button.size.x-button.get_theme_stylebox("normal").get_minimum_size().x
			if font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x>available+1:
				found.append("button text cramped: "+label_text(button))
	for label in labels:
		if not clipped_by_view(label) and not viewport.encloses(label.get_global_rect()):
			found.append("text outside: " + label_text(label))
		var ancestor=label.get_parent()
		while ancestor!=null and ancestor!=target:
			if ancestor is Button and not clipped_by_view(ancestor):
				if not ancestor.get_global_rect().grow(1).encloses(label.get_global_rect()): found.append("card text outside: "+label_text(label))
				break
			ancestor=ancestor.get_parent()
	if tag.begins_with("rewards") or tag.begins_with("branch-rewards"):
		if not viewport.encloses(game.reward_ui.board.get_global_rect()): found.append("reward board outside viewport")
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			var a: Button = buttons[i]; var b: Button = buttons[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			if clipped_by_view(a) or clipped_by_view(b): continue
			if a.get_global_rect().grow(-1).intersects(b.get_global_rect().grow(-1)):
				found.append("buttons overlap: " + label_text(a) + " / " + label_text(b))
	for i in labels.size():
		var a:Label=labels[i]
		if clipped_by_view(a): continue
		if a.size.x<2 or a.size.y<2:continue
		for j in range(i+1,labels.size()):
			var b:Label=labels[j]
			if a.get_parent()!=b.get_parent() or clipped_by_view(b): continue
			if b.size.x<2 or b.size.y<2:continue
			if a.get_global_rect().grow(-1).intersects(b.get_global_rect().grow(-1)):
				found.append("text lanes overlap: "+label_text(a)+" / "+label_text(b))
	if tag.begins_with("game"):
		var skill:Rect2=game.battle_hud.skill_panel_rect()
		var hint=Rect2(game.cave_terrain.hint_position,Vector2(440,34))
		if game.cave_terrain.hints.visible and hint.intersects(skill):found.append("Mining hint overlaps character skill")
		for card in game.tutorials.cards.values():
			if not card.is_visible_in_tree():continue
			if not viewport.encloses(card.get_global_rect()):found.append("Tutorial outside viewport")
			if card.get_global_rect().intersects(skill) or card.get_global_rect().intersects(hint):found.append("Tutorial overlaps bottom HUD")
	if game.performance_overlay.display.visible:
		var plate: Rect2 = game.performance_overlay.plate.get_global_rect()
		for button in buttons:
			if clipped_by_view(button): continue
			if plate.intersects(button.get_global_rect()): found.append("FPS covers: " + label_text(button))
		if tag.begins_with("game") and plate.intersects(game.battle_hud.skill_panel_rect()):found.append("FPS overlaps skill panel")
	measurements.append({"case": tag, "buttons": buttons.size(), "labels": labels.size(), "issues": found})
	for issue in found: issues.append({"case": tag, "issue": issue})
	check(found.is_empty(), "Unobstructed controls and bounded text: " + tag)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path = "res://artifacts/ui-small-" + tag + ".png"
		check(root.get_texture().get_image().save_png(path) == OK, "Capture " + tag)
		captures.append(path)

func show_case(id: String):
	game.tutorials.reset_run()
	game.tutorials.visible=id.begins_with("game")
	match id:
		"home": game.show_menu()
		"characters": game.show_characters()
		"missions", "mission-escort":
			game.show_missions()
			if id=="mission-escort":game.mission_ui.select_mission(3)
		"game", "game-busy", "game-tutorials":
			game.show_game()
			if id=="game-busy":
				game.combat.momentum.chain=25;game.combat.momentum.burst_left=3
				game.run.encounters.event_type="treasure";game.run.encounters.phase="warning";game.run.encounters.notice_left=3
				game.run.encounters.notice="击败守卫，夺取补给与进化奖励"
				game.run.packs=99;game.run.scraps=1234567
				game.battle_hud.refresh()
			if id=="game-tutorials":
				game.save.state.tutorials.clear()
				for key in ["move","shoot","build"]:
					game.tutorials.show_tip(key)
					game.tutorials.shown[key].pause();game.tutorials.cards[key].scale=Vector2.ONE
		"research": game.show_lab()
		"research-detail":
			game.show_lab()
			var lab = game.panel.get_child(0)
			lab.show_detail(game.db.research.filter(func(n): return n.nodeRewardsList.size() >= 3)[0], 1)
		"branch-detail":
			game.show_lab()
			var lab = game.panel.get_child(0)
			lab.show_detail(game.db.research.filter(func(n): return n.has("mutation_branch"))[0], 0)
		"codex", "codex-locked":
			game.save.state.systems.ToggleResearches=id!="codex-locked"
			game.show_reward_pool()
		"options": game.show_options()
		"controls": game.show_controls()
		"changelog": game.show_changelog()
		"build", "build-spider", "build-full":
			game.player.configure_character("spider" if id == "build-spider" else "centipede")
			game.player.pending.clear()
			if id=="build-full":
				for i in 60:game.player.append_segment(game.db.named("Core_Gun_Gatling").id)
				game.player.pending=["expanded_parasite_core","expanded_toxin_core","expanded_boneblade_core"]
			game.show_build_ui()
		"rewards", "branch-rewards":
			game.player.pending.clear(); game.run.packs = 2
			game.run.offers = []
			if id == "branch-rewards":
				game.player.configure_character("centipede")
				for key in ["toxin_spread", "boneblade_recall", "parasite_hunter"]:
					var reward=game.db.asset("expanded_" + key + "_branch")
					var weapon=str(reward.mutation_weapon)
					game.player.append_segment("expanded_"+weapon+"_core")
					game.player.levels["expanded_"+weapon+"_upgrade"]=1
					game.save.state.unlocked.append(reward.id)
					game.run.offers.append(reward)
			else:
				for name in ["Core_Gun_Cannon", "Core_Gun_Gatling", "Core_Gun_Rocket"]:
					var core = game.db.named(name)
					var reward=game.db.kind("BlockReward").filter(func(r): return r.blockCore == core.id)[0]
					if reward.id not in game.save.state.unlocked:game.save.state.unlocked.append(reward.id)
					game.run.offers.append(reward)
			game.show_rewards()
		"pause": game.show_pause()
		"manual": game.show_loading()
		"deployment":
			game.screen="deploying";game.clear_ui()
			var loading=load("res://scripts/deployment_screen.gd").new();game.panel.add_child(loading)
			loading.set_progress(73,"生成岩层 998 / 1024")
		"result":
			game.run.result = {"grade": "SSS+", "score": 123456789, "meta": 1200, "time": 5400, "kills": 99999, "breakdown": {1: 1000000, 3: 5000, 4: 3000, 6: 25000, 9: 8000, 10: 9000}}
			game.run.won = true; game.show_result()
	await settle()

func click_control(control: Control):
	var point=root.get_final_transform()*control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
	await process_frame
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=point;press.global_position=point;press.pressed=true
	Input.parse_input_event(press);await process_frame
	press=press.duplicate();press.pressed=false;Input.parse_input_event(press);await settle()

func button_named(text: String) -> Button:
	var buttons:Array=[];game.collect_focus_buttons(game.panel,buttons)
	for button in buttons:
		if button.text==text:return button
	return null

func verify_small_window_input():
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(800,600);await settle()
	await show_case("home");await click_control(button_named("虫巢"))
	check(game.screen=="characters","800x600: native click opens the roster")
	await click_control(button_named("前往远征  →"))
	check(game.screen=="menu","800x600: native click reaches mission selection")
	await click_control(game.mission_ui.back_button)
	check(game.screen=="home","800x600: native Back button returns home")
	await show_case("options");await click_control(button_named("按键"))
	check(game.screen=="controls","800x600: native click opens key bindings")
	await show_case("research")
	var lab=game.panel.get_child(0);await click_control(lab.section_buttons.sustain)
	check(lab.magnification==lab.DEFAULT_ZOOM,"800x600: evolution category tab remains clickable")
	var node=game.db.research.filter(func(n):return n.get("mutation_branch","")=="toxin_spread")[0]
	await click_control(lab.node_buttons[node.id])
	check(is_instance_valid(lab.detail),"800x600: native click opens a branch detail")
	if is_instance_valid(lab.detail):
		var close_button=lab.detail.get_children().filter(func(n):return n is Button and n.text.is_empty())[0]
		await click_control(close_button)
		check(not is_instance_valid(lab.detail),"800x600: modal Back button dismisses the detail")
	await show_case("rewards")
	var opened=game.run.opened
	var reward_disabled=game.reward_ui.buttons[0].disabled
	await click_control(game.reward_ui.buttons[0])
	if game.screen!="build" or game.run.opened!=opened+1:printerr("REWARD_CLICK_STATE=",JSON.stringify({"disabled":reward_disabled,"screen":game.screen,"before":opened,"after":game.run.opened,"parts":game.player.parts.size(),"pending":game.player.pending.size(),"finished":game.run.finished,"hp":game.player.parts[0].hp}))
	check(game.screen=="build" and game.run.opened==opened+1,"800x600: native reward click opens placement exactly once")
	# The empty assembly state exposes its normal deploy button.
	game.player.pending.clear();game.run.packs=0;game.reward_flow_active=false;game.show_build_ui();await settle()
	await click_control(game.build_ui.return_button)
	check(game.screen=="game","800x600: unobstructed Deploy button resumes gameplay")

func execute():
	root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate(); root.add_child(game); await settle()
	game.set_process(false); game.test_mode = true; game.save.fresh(); game.save.state.settings.skip_boss = true
	game.save.state.meta = 1234567; game.save.state.systems.ToggleResearches = true
	game.start_run(); game.set_process(false)
	var cases = ["home", "characters", "missions", "mission-escort", "research", "research-detail", "branch-detail", "codex", "codex-locked", "options", "controls", "changelog", "game", "game-busy", "game-tutorials", "build", "build-spider", "build-full", "rewards", "branch-rewards", "pause", "manual", "deployment", "result"]
	for extent in [Vector2i(960, 600), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(800, 600)]:
		root.size = extent; await settle()
		for id in cases:
			await show_case(id)
			var target: Control = game.panel
			if id.ends_with("detail"): target = game.panel.get_child(0).detail
			if id.begins_with("game"):target=game.battle_hud
			await audit(id + "-%dx%d" % [extent.x, extent.y], target)
	game.db.language="English";root.size=Vector2i(960,600);await settle()
	for id in ["home","characters","missions","research-detail","branch-detail","codex","options","controls","branch-rewards","pause","result"]:
		await show_case(id)
		await audit(id+"-english-960x600",game.panel.get_child(0).detail if id.ends_with("detail") else game.panel)
	game.db.language=game.db.DEFAULT_LANGUAGE
	# Repeat window scaling with the project's normal logical canvas.
	root.content_scale_size = Vector2i(1440, 900)
	for extent in [Vector2i(960, 600), Vector2i(1024, 768)]:
		root.size = extent; await settle()
		for id in ["home", "options", "controls", "rewards", "branch-rewards", "build", "pause", "result"]:
			await show_case(id); await audit(id + "-scaled-%dx%d" % [extent.x, extent.y], game.panel)
	await verify_small_window_input()
	game.cursor_system.shutdown(); game.audio_system.shutdown(); game.particle_effects.clear(); game.queue_free(); await settle()
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "issues": issues, "measurements": measurements, "captures": captures}
	FileAccess.open("res://artifacts/ui-small-windows-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify({"passed": report.passed, "cases": measurements.size(), "issues": issues}))
	quit(0 if report.passed else 1)
