extends Node2D

const DB = preload("res://scripts/source_db.gd")
const Save = preload("res://scripts/save_store.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const CentipedeArt = preload("res://scripts/centipede_art.gd")
const Ink = preload("res://scripts/blue_ink.gd")
const Brood = preload("res://scripts/brood_theme.gd")
const Battle = preload("res://scripts/combat.gd")
const Feedback = preload("res://scripts/weapon_feedback.gd")
var weapon_fx = preload("res://scripts/weapon_fx.gd").new()
var hit_pause_left = 0.0
var hit_pause_cooldown = 0.0
var camera_recoil = Vector2.ZERO
const Run = preload("res://scripts/run_state.gd")
var db
var save
var player
var combat
var run
var screen = "menu"
var selected_mission: Dictionary
var difficulty = 0
var ui: CanvasLayer
var panel: Control
var hud: Label
var run_hud: Label
var equipment_hud: Label
var message: Label
var center = Vector2(720, 450)
var camera = Vector2.ZERO
var aim = Vector2.RIGHT
var zoom = 1.0
const AudioSystem = preload("res://scripts/audio_system.gd")
var audio_system
var music: AudioStreamPlayer
var test_mode = false
var test_time = 0.0
var leg_phase = 0.0
var player_legs=preload("res://scripts/centipede_legs.gd").new()
var capture_stage = 0
const InputSystem=preload("res://scripts/input_system.gd")
var controls
var rebind_action=""
var radar_mode=false
var reset_pending=false
var options_draft:Dictionary={}
const SourceUI=preload("res://scripts/source_ui.gd")
var source_ui
var font: Font
var probe_time=0.0
var camera_focus:Dictionary={}
var shown_bosses:Dictionary={}
var background_renderer
var background_layers:Array=[]
var background_palette:Array=[]
var controller_pointer=Vector2(720,440)
var tip_index=0
var tip_video:VideoStreamPlayer
var joy_ui=false
var controller_trigger_down=false
var tip_stick_down=false
var virtual_pointer_time=0
var tutorials
var cursor_system
var menu_background
var decoration_system=preload("res://scripts/player_decorations.gd").new()
const RenderState=preload("res://scripts/render_state.gd")
var particle_effects
var particle_layer:CanvasLayer
var native_visuals=preload("res://scripts/native_visuals.gd").new()
var popup_text
var camera_kick = Vector2.ZERO
var camera_impact = 0.0
var mouth_activity = 0.0
var ink_world
var insect_layer
var build_ui
var mission_ui
var battle_hud
var reward_ui
var reward_flow_active=false
var reward_epoch=0
var reward_choice_busy=false
var reward_snoozed=false
var reward_snooze_count=0
var build_selected_segment = 1

func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	get_tree().node_added.connect(ink_node_added)
	db = DB.new()
	Ink.register_game_colors(db)
	ink_world = preload("res://scripts/blue_ink_layer.gd").new()
	ink_world.show_behind_parent = true
	ink_world.material = Ink.illustration()
	add_child(ink_world)
	insect_layer=preload("res://scripts/soft_insect_layer.gd").new()
	insect_layer.z_index=-1
	add_child(insect_layer)
	var isolated = Array(OS.get_cmdline_user_args()).any(func(arg):return arg in ["--smoke","--operations-input-fixture","--build-input-fixture"])
	save = Save.new(db, "user://preview-isolated.json" if isolated else "user://centipede-save.json", not isolated)
	controls=InputSystem.new(save)
	db.language = save.state.settings.language
	DisplayServer.window_set_title(db.ui("Centipede · Run Build Pew!", "蜈蚣：逐节武装"))
	player = Body.new(db)
	combat = Battle.new(db, player)
	selected_mission = db.asset(db.stores.MissionDataStore.missionsList[0])
	ui = CanvasLayer.new()
	add_child(ui)
	font = load("res://assets/fonts/NotoSansSC-Light.otf")
	ThemeDB.fallback_font = font
	audio_system=AudioSystem.new()
	add_child(audio_system)
	audio_system.setup(db,save)
	music=audio_system.music
	tutorials=load("res://scripts/tutorial_ui.gd").new();add_child(tutorials);tutorials.setup(db,save)
	for name in ["Background Nebula BackGround.png","BackStarsMat.png","Background Nebula ForeGround.png","FrontStarsMat.png"]:background_layers.append(load("res://assets/backgrounds/"+name))
	background_palette=db.scene_config.BackgroundColorChanger.backgroundColorPresetsList[1].colorsList
	background_renderer=load("res://scripts/background_layers.gd").new();add_child(background_renderer);background_renderer.setup(background_layers)
	cursor_system=load("res://scripts/cursor_system.gd").new();add_child(cursor_system);cursor_system.setup(db)
	menu_background=load("res://scripts/menu_background.gd").new();add_child(menu_background);menu_background.setup(db)
	menu_background.material=Ink.illustration()
	particle_layer=CanvasLayer.new();particle_layer.layer=0;add_child(particle_layer)
	particle_effects=load("res://scripts/particle_effects.gd").new();particle_layer.add_child(particle_effects);particle_effects.setup(db);native_visuals.setup(db,particle_effects)
	popup_text=load("res://scripts/popup_text.gd").new();popup_text.layer=3;add_child(popup_text)
	show_menu()
	if "--smoke" in OS.get_cmdline_user_args():
		test_mode = true
		call_deferred("automated_flow")
	elif "--operations-input-fixture" in OS.get_cmdline_user_args():
		test_mode=true;save.fresh();save.path="user://operations-input-isolated.json";start_run()
		player.add_piece(db.named("Core_Gun_Gatling").id,Vector2i(-1,0));player.add_piece(db.named("Core_Gun_Shotgun").id,Vector2i(-1,1))
		player.actions={"move":1,"swap":1,"duplicate":1,"wall":1};show_build()
	elif "--build-input-fixture" in OS.get_cmdline_user_args():
		test_mode=true;save.fresh();save.path="user://build-input-isolated.json";start_run();run.rewards.enqueue(true);show_rewards()

func clear_ui():
	if cursor_system!=null:cursor_system.set_cursor(2 if screen=="game" else 1)
	for child in ui.get_children():
		child.queue_free()
	panel = Control.new()
	panel.theme = Ink.theme()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("focus_menu_button")

func ink_node_added(node: Node):
	if node is Control and is_ancestor_of(node):
		# Defer until the creating screen has finished setting local styles.
		ink_style_later.call_deferred(weakref(node))

func ink_style_later(reference: WeakRef):
	var node = reference.get_ref()
	if node == null or not is_ancestor_of(node):return
	if screen=="menu" and is_instance_valid(mission_ui) and (node==mission_ui or mission_ui.is_ancestor_of(node)):return
	if screen=="game" and is_instance_valid(battle_hud) and (node==battle_hud or battle_hud.is_ancestor_of(node)):return
	if screen=="rewards" and is_instance_valid(reward_ui) and (node==reward_ui or reward_ui.is_ancestor_of(node)):return
	Ink.style_item(node)

func label_at(text: String, pos: Vector2, size: int = 22, color: Color = Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(Ink.INK, color.a))
	panel.add_child(label)
	return label

func button(text: String, pos: Vector2, extent: Vector2, fn: Callable, disabled: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = extent
	b.add_theme_font_size_override("font_size", 19)
	b.disabled = disabled
	b.pressed.connect(func(): audio_system.play(70); fn.call())
	panel.add_child(b)
	return b

func frame(title: String, subtitle: String):
	clear_ui()
	label_at(db.ui("CENTIPEDE / ARM EACH SEGMENT", "蜈蚣 / 逐节武装"), Vector2(64, 35), 19, Color("ebaa4b"))
	label_at(title, Vector2(64, 75), 44)
	label_at(subtitle, Vector2(66, 134), 18, Color("a8acae"))

func show_intro():
	show_menu()

func show_menu():
	if audio_system!=null:audio_system.sync_loops([])
	screen="home"
	audio_system.change_music("menu")
	frame(db.ui("CENTIPEDE", "蜈蚣：逐节武装"),db.ui("Grow your body. Arm every segment. Survive together.", "长出身体，逐节装塔，带着整条蜈蚣一起战斗。"))
	button(db.ui("PLAY", "开始游戏"),Vector2(90,290),Vector2(300,65),show_missions)
	button(db.ui("RESEARCH", "研究与升级"),Vector2(90,375),Vector2(300,65),show_lab)
	button(db.ui("OPTIONS", "游戏设置"),Vector2(90,460),Vector2(300,65),show_options)
	button(db.ui("WHAT'S NEW", "更新说明"),Vector2(90,545),Vector2(300,65),show_changelog)
	button(db.ui("EXIT", "退出游戏"),Vector2(90,630),Vector2(300,65),safe_shutdown)
	label_at(db.ui("ONE SEGMENT · ONE MODULE", "一节身体 · 一个模块"),Vector2(675,270),30,Color("d8ebd5"))
	label_at(db.ui("Turrets ride on the shell. Every leg follows the head.", "炮塔装在背上，身体跟着头部蜿蜒前进。"),Vector2(675,320),20,Color("a9c5ba"))
	label_at(db.ui("WASD move · Mouse fire · E build", "WASD 移动 · 鼠标瞄准射击 · E 逐节装塔"),Vector2(90,795),20,Color("ebc584"))
	label_at(db.ui("Research points: %d", "可用研究点：%d")%save.state.meta,Vector2(1030,795),20,Color("ebc584"))

func source_ui_action(method:String,_id:String,_args:Dictionary):
	if method=="HoverFeedback":audio_system.play(int(_args.get("type",72)));return
	audio_system.play(70)
	if method=="SliderChanged":
		if screen=="menu":difficulty=clampi(int(_args.value),0,2);show_missions()
		elif screen in ["options","pause"]:
			var config:Dictionary=db.scene_config.OptionMenuManager if screen=="options" else db.scene_config.PauseMenuManager
			for key in ["MasterAudioSlider","MusicAudioSlider","SFXAudioSlider"]:
				var reference=refid(config,key)
				if source_ui.controls.get(reference)==source_ui.controls.get(_id):
					var setting={"MasterAudioSlider":"volume","MusicAudioSlider":"music","SFXAudioSlider":"sfx"}[key]
					save.state.settings[setting]=_args.value
					if screen=="options":options_draft[setting]=_args.value
					audio_system.refresh();save.save()
		return
	match method:
		"RecyclePack":run.rewards.recycle();show_build()
		"NextMission","PreviousMission":
			var ids:Array=db.stores.MissionDataStore.missionsList
			selected_mission=db.asset(ids[posmod(ids.find(selected_mission.id)+(1 if method=="NextMission" else -1),ids.size())]);show_missions()
		"PlayButton":
			if save.mission_unlocked(selected_mission):begin_run()
		"ResearchMission":save.unlock_mission(selected_mission);show_missions()
		"ResetModifiers":save.state.disabled.clear();save.save();show_missions()
		"ShowMenu":show_reward_pool()
		"LeftResolution","RightResolution":options_draft.resolution=clampi(int(options_draft.resolution)+(1 if method=="RightResolution" else -1),0,db.scene_config.OptionMenuManager.resolutions.size()-1);show_options()
		"LefScreenMode","RighScreenMode":options_draft.screen_mode=posmod(int(options_draft.screen_mode)+(1 if method=="RighScreenMode" else -1),3);show_options()
		"LeftLanguage","RightLanguage":
			var languages=["English","Chinese (simplified)","Chinese (traditional)","Russian"]
			options_draft.language=languages[posmod(languages.find(options_draft.language)+(1 if method=="RightLanguage" else -1),4)];show_options()
		"ActivateSkipBoss","DeActivateSkipBoss":options_draft.skip_boss=method=="ActivateSkipBoss";save.state.settings.skip_boss=options_draft.skip_boss;save.save();show_options()
		"ResettButton":reset_pending=true;show_options()
		"ApplyResettButton":save.reset_progress();options_draft.clear();reset_pending=false;show_menu()
		"ApplySettingsButton":apply_options()
		"ShowControlsMenu":show_controls()
		"unPauseGame":show_game()
		"RestartGame":begin_run()
		"GoToMainMenu":show_menu()
		"GoToLab":show_lab()
		"ShowPlayMenu":show_missions()
		"ShowTree":show_lab()
		"ShowOptionMenu":show_options()
		"ExitApplication":safe_shutdown()
		"ShowChangeLog":show_changelog()
		"BackButton","ShowMainMenu":
			if screen=="reward_pool":show_missions()
			else:show_menu()
		"OpenWishListButton":OS.shell_open("https://store.steampowered.com/app/1980350/Run_Build_Pew/")
		"OpenDiscordButton":OS.shell_open("https://discord.com/invite/nW2Tc4ShSf")
		"OpenNewsletter":OS.shell_open("http://eepurl.com/ijWdjn")
		"OpenGameButton":OS.shell_open("https://store.steampowered.com/app/2928690/Wandness/")

func show_changelog():
	screen="changelog"
	source_screen("MainMenuScene/ChangeLogCanvas")
	var source_label=source_ui.labels.get("17898")
	if source_label!=null:
		var container=source_label.get_parent()
		source_label.hide()
		var scroll=ScrollContainer.new();scroll.size=container.size;container.add_child(scroll)
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		var content=RichTextLabel.new();content.bbcode_enabled=true;content.fit_content=true;content.scroll_active=false
		content.custom_minimum_size.x=maxf(400,container.size.x-25)
		content.text=FileAccess.get_file_as_string("res://data/changelog_zh.txt" if db.language.begins_with("Chinese") else "res://data/changelog.txt").replace("<b>","[b]").replace("</b>","[/b]").replace("<size=50>","[font_size=30]").replace("</size>","[/font_size]")
		content.add_theme_font_size_override("normal_font_size",20);scroll.add_child(content)

func source_screen(key:String):
	clear_ui();source_ui=SourceUI.new();panel.add_child(source_ui);source_ui.setup(db,key,source_ui_action,save.state.settings.bindings);source_ui.set_binding_labels(save.state.settings.bindings,joy_ui)

func refid(config:Dictionary,key:String)->String:
	return str(int(config.get(key,{}).get("fileID",0)))

func show_missions():
	screen="menu"
	clear_ui()
	source_ui=null
	mission_ui=preload("res://scripts/mission_select.gd").new()
	panel.add_child(mission_ui)
	mission_ui.setup(self)

func show_lab():
	screen="lab"
	clear_ui()
	var research=load("res://scripts/research_ui.gd").new()
	panel.add_child(research)
	research.controller_navigation=joy_ui
	research.setup(db,save,show_menu,func():audio_system.play(70))

func show_reward_pool():
	screen="reward_pool"
	clear_ui()
	var pool=load("res://scripts/reward_pool_ui.gd").new()
	panel.add_child(pool)
	pool.setup(db,save,show_missions,func():audio_system.play(70))

func show_options():
	screen="options"
	if options_draft.is_empty():options_draft=save.state.settings.duplicate(true)
	source_screen("MainMenuScene/OptionsCanvas")
	var config:Dictionary=db.scene_config.OptionMenuManager
	var resolution:Dictionary=config.resolutions[int(options_draft.resolution)]
	source_ui.set_text(refid(config,"resolutionText"),"%d X %d"%[resolution.width,resolution.height])
	source_ui.set_text(refid(config,"screenModeText"),db.text(str(config.screenModesList[int(options_draft.screen_mode)].Text).strip_edges()))
	source_ui.set_text(refid(config,"languageText"),db.language_name(str(options_draft.language)))
	source_ui.show_node(refid(config,"backButton"),true)
	source_ui.show_node(refid(config,"activateSkipBossButton"),not options_draft.skip_boss)
	source_ui.show_node(refid(config,"deactivateSkipBossButton"),options_draft.skip_boss)
	source_ui.show_node(refid(config,"ResetButton"),not reset_pending)
	source_ui.show_node(refid(config,"ApplyResetButton"),reset_pending)
	for key in ["MasterAudioSlider","MusicAudioSlider","SFXAudioSlider"]:
		var setting={"MasterAudioSlider":"volume","MusicAudioSlider":"music","SFXAudioSlider":"sfx"}[key]
		source_ui.set_slider(refid(config,key),options_draft[setting])

func apply_options():
	save.state.settings=options_draft.duplicate(true)
	db.language=save.state.settings.language
	if tutorials!=null:tutorials.refresh_language()
	DisplayServer.window_set_title(db.ui("Centipede · Run Build Pew!", "蜈蚣：逐节武装"))
	var resolution:Dictionary=db.scene_config.OptionMenuManager.resolutions[int(options_draft.resolution)]
	DisplayServer.window_set_mode([DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_WINDOWED][int(options_draft.screen_mode)])
	if int(options_draft.screen_mode)==2:DisplayServer.window_set_size(Vector2i(int(resolution.width),int(resolution.height)))
	audio_system.refresh();save.save();show_options()

func show_controls():
	screen="controls"
	frame(db.text("Option_Controls"),db.ui("Select a binding, then press a key. Esc cancels rebinding.", "点击要修改的操作，再按新按键。按 Esc 取消。"))
	var index=0
	for action in InputSystem.DEFAULTS:
		var code=int(save.state.settings.bindings.get(action,InputSystem.DEFAULTS[action]))
		button(control_title(action)+"   ["+OS.get_keycode_string(code)+"]",Vector2(80,205+index*63),Vector2(600,50),func():rebind_action=action;message.text=db.ui("Press a key for ", "请按新按键：")+control_title(action))
		index+=1
	for i in range(3):
		var key=["invert_x","invert_y","left_aim"][i]
		button(control_title(key)+"："+db.ui("On" if save.state.settings[key] else "Off", "开启" if save.state.settings[key] else "关闭"),Vector2(800,250+i*80),Vector2(490,50),func():save.state.settings[key]=not save.state.settings[key];save.save();show_controls())
	message=label_at("",Vector2(800,535),20)
	button(db.ui("Reset bindings", "恢复默认按键"),Vector2(800,610),Vector2(490,50),func():save.state.settings.bindings.clear();controls.apply();save.save();show_controls())
	button(db.text("Option_Back"),Vector2(80,810),Vector2(260,50),func():options_draft=save.state.settings.duplicate(true);show_options())

func start_run():
	reward_flow_active=false;reward_choice_busy=false;reward_snoozed=false;reward_epoch+=1
	hit_pause_left=0.0; hit_pause_cooldown=0.0; camera_recoil=Vector2.ZERO; camera_impact=0.0
	if popup_text!=null:popup_text.clear()
	if particle_effects!=null:particle_effects.clear()
	if tutorials!=null:tutorials.reset_run()
	player = Body.new(db)
	leg_phase=0.0;player_legs.reset()
	build_selected_segment=1
	combat = Battle.new(db, player)
	run = Run.new(db, save, player, combat, selected_mission, difficulty)
	camera_focus.clear();shown_bosses.clear()
	if not test_mode:run.rng.randomize();combat.rng.randomize()
	audio_system.change_music("game")
	camera = player.head
	show_game()
	if not save.state.settings.skip_boss and run.mode.get("class") in ["BHModeManager","GAModeManager","SProtectModeManager","SDestroyModeManager"]:focus_camera(run.director.fleet_position if run.mode.get("class") in ["BHModeManager","GAModeManager"] else Vector2.ZERO)

func focus_camera(target:Vector2,boss:bool=false):
	camera_focus={"target":target,"stage":0,"remaining":2.0,"boss":boss}

func tick_camera_focus(dt:float):
	var target:Vector2=camera_focus.target if int(camera_focus.stage)<2 else player.head
	camera=camera.lerp(target,minf(1,dt*float(db.scene_config.CameraManager.lerpingSpeed)))
	if int(camera_focus.stage)==0 and camera.distance_to(target)<20:camera_focus.stage=1
	elif int(camera_focus.stage)==1:
		camera_focus.remaining-=dt
		if camera_focus.remaining<=0:camera_focus.stage=2
	elif int(camera_focus.stage)==2 and camera.distance_to(player.head)<20:
		var boss=bool(camera_focus.get("boss",false));camera_focus.clear()
		if tutorials!=null and boss:tutorials.show_tip("run")

func show_game():
	screen = "game"
	source_screen("GameScene/InGame Canvas")
	source_ui.hide()
	for id in ["11","90","264","408","37"]:source_ui.show_node(id,false)
	for id in ["43","124"]:source_ui.show_node(id,true)
	for slider in source_ui.sliders.values():slider.editable=false
	battle_hud=preload("res://scripts/battle_hud.gd").new()
	panel.add_child(battle_hud)
	battle_hud.setup(self)
	update_source_hud()

func boss_timer_progress()->float:
	var milestones:Array=[]
	for fleet in run.mode.get("BossesFleetsList",[]):milestones.append(float(fleet.fleetPercent))
	for key in ["MiniBossFleet","MidBossFleet"]:
		if run.mode.has(key):milestones.append(float(run.mode[key].fleetPercent))
	if run.mode.has("bossesSpawnPercent"):
		for value in run.mode.bossesSpawnPercent:milestones.append(floorf(run.heat)+float(value))
	milestones.sort()
	var previous=0.0
	for next in milestones:
		if next>run.heat:return (run.heat-previous)/maxf(0.001,next-previous)
		previous=next
	return 1.0 if run.director.end_spawned else run.heat

func update_source_hud():
	if is_instance_valid(battle_hud) and screen=="game":battle_hud.refresh()
	source_ui.set_fill("1889",run.heat)
	source_ui.set_fill("1614",boss_timer_progress())
	var timer=maxf(0,run.duration-run.elapsed) if selected_mission.get("isTimerCountingDown",false) else run.elapsed
	source_ui.set_text("80","%02d:%02d"%[int(timer)/60,int(timer)%60])
	var mission_ui:Dictionary=db.scene_config.GameMissionManager
	source_ui.show_node(refid(mission_ui,"gameTimer"),bool(selected_mission.hasTimer))
	source_ui.show_node(refid(mission_ui,"gameBossTimer"),bool(selected_mission.hasBossBars))
	source_ui.set_text("9","%d/%d"%[player.parts.size()-1,int(db.stores.PlayerDataStore.maxBuiltCores)])
	source_ui.set_text("293",str(run.packs))
	source_ui.set_text("124","E · "+str(run.packs))
	var hq_drones=combat.drones.filter(func(d):return d.owner==0)
	source_ui.set_text("44","%d/%d"%[hq_drones.size(),int(db.stores.PlayerDataStore.get("maxHQDronesCount",30))])
	for i in range(3):
		var classes=["Drone","EngineerDrone","ProjectileDrone"]
		source_ui.set_text(["263","197","198"][i],str(hq_drones.filter(func(d):return d.data.get("class")==classes[i]).size()))
	var cost=maxf(1,float(db.stores.RewardDataStore.ScrapsPerRewardPack)*maxi(1,player.parts.size()-1+run.packs))
	source_ui.set_slider("1806",float(run.scraps)/cost)
	source_ui.show_node("69",run.mode.get("class") in ["BHModeManager","GAModeManager"])
	var distance=player.head.distance_to(run.director.fleet_position)/48
	source_ui.set_text("99",str(roundi(distance)))
	source_ui.show_node("100",run.director.end_spawned or run.mode.get("class")=="EndlessModeManager")

func control_title(action:String)->String:
	var names={"move_up":"向上移动","move_down":"向下移动","move_left":"向左移动","move_right":"向右移动","boost":"加速","build":"逐节装塔","pause":"暂停","radar":"雷达","shoot":"射击","invert_x":"反转横向瞄准","invert_y":"反转纵向瞄准","left_aim":"左摇杆瞄准"}
	return db.ui(action.replace("_"," ").capitalize(),names.get(action,action))

func show_build():
	if reward_waiting():
		reward_snoozed=false;advance_reward_flow();return
	show_build_ui()

func show_build_ui():
	audio_system.sync_loops([])
	if run == null:return
	screen = "build"
	clear_ui()
	build_ui = preload("res://scripts/build_chain_ui.gd").new()
	panel.add_child(build_ui)
	build_ui.setup(self)
	queue_redraw()
	return

func reward_waiting()->bool:
	return run!=null and (not player.pending.is_empty() or run.packs>0)

func auto_reward_ready()->bool:
	return reward_waiting() and (not reward_snoozed or run.packs>reward_snooze_count)

func advance_reward_flow():
	if run==null or run.finished or player.parts[0].hp<=0:return
	reward_choice_busy=false;reward_snoozed=false
	if not player.pending.is_empty():
		reward_flow_active=true;show_build_ui()
	elif run.packs>0:show_rewards()
	else:
		reward_flow_active=false;show_game()

func show_rewards():
	if run==null or run.finished or player.parts[0].hp<=0:return
	if not player.pending.is_empty():advance_reward_flow();return
	if run.packs<=0:reward_flow_active=false;show_game();return
	reward_flow_active=true;reward_choice_busy=false;reward_epoch+=1
	screen="rewards";audio_system.sync_loops([]);clear_ui();source_ui=null
	reward_ui=preload("res://scripts/reward_choice.gd").new();panel.add_child(reward_ui)
	reward_ui.setup(self,run.roll_rewards(),reward_epoch)

func choose_reward(reward:Dictionary,token:int):
	if screen!="rewards" or token!=reward_epoch or reward_choice_busy or run.finished or player.parts[0].hp<=0:return
	reward_choice_busy=true
	if not run.take_reward(reward):reward_choice_busy=false;return
	reward_epoch+=1
	advance_reward_flow.call_deferred()

func recycle_reward(token:int):
	if screen!="rewards" or token!=reward_epoch or reward_choice_busy or run.finished or player.parts[0].hp<=0:return
	reward_choice_busy=true;reward_epoch+=1
	run.rewards.recycle();advance_reward_flow.call_deferred()

func postpone_rewards():
	reward_epoch+=1;reward_choice_busy=false;reward_flow_active=false
	reward_snoozed=true;reward_snooze_count=run.packs
	show_game()

func finish_building():
	if screen!="build" or not player.pending.is_empty():return
	postpone_rewards()

func reward_placement_changed():
	if screen!="build" or not reward_flow_active or not is_instance_valid(build_ui):return
	if player.pending.is_empty():
		reward_flow_active=false
		build_ui.selected_data={}
	else:build_ui.selected_data={"kind":"inventory","index":0,"id":player.pending[0]}
	build_ui.rebuild()

func begin_run():
	# Tips remain available in show_loading(), but no longer interrupt deployment.
	start_run()

func show_loading():
	screen="loading"
	source_screen("GameScene/InGame Canvas")
	source_ui.show_node("12",false);source_ui.show_node("11",true)
	var config:Dictionary=db.scene_config.LoadingPanelContorller
	source_ui.show_node(refid(config,"loadingObject"),false)
	source_ui.show_node(refid(config,"doneLoadingObject"),true)
	for pair in [["127","337","133","LMB"],["261","373","259","D"]]:
		source_ui.show_node(pair[0],false);source_ui.show_node(pair[1],true);source_ui.set_text(pair[2],db.ui("LMB","左键") if pair[3]=="LMB" else pair[3])
	tip_index=randi()%config.tipsList.size()
	var video_container=source_ui.controls.get(refid(config,"panelVideoPlayer"))
	if video_container!=null:
		for child in video_container.get_children():child.hide()
		tip_video=VideoStreamPlayer.new();tip_video.expand=true;tip_video.size=video_container.size;tip_video.loop=true;video_container.add_child(tip_video)
	next_loading_tip()

func next_loading_tip():
	var config:Dictionary=db.scene_config.LoadingPanelContorller
	var tip:Dictionary=db.asset(config.tipsList[tip_index])
	source_ui.set_text(refid(config,"tipsText"),db.text(tip.name))
	var videos:Dictionary=db.read_json("videos")
	var path=videos.get(tip.get("tipVideoClip",""),"")
	if is_instance_valid(tip_video):
		tip_video.stop();tip_video.visible=not str(path).is_empty()
		if not str(path).is_empty():tip_video.stream=load(path);tip_video.play()
	tip_index=(tip_index+1)%config.tipsList.size()

func show_pause():
	audio_system.sync_loops([])
	screen="pause"
	source_screen("GameScene/Pause Canvas")
	source_ui.show_all_panels()
	var config:Dictionary=db.scene_config.PauseMenuManager
	for key in ["MasterAudioSlider","MusicAudioSlider","SFXAudioSlider"]:
		var setting={"MasterAudioSlider":"volume","MusicAudioSlider":"music","SFXAudioSlider":"sfx"}[key]
		source_ui.set_slider(refid(config,key),save.state.settings[setting])

func show_result():
	screen="result"
	source_screen("GameScene/Game Over Canvas")
	source_ui.show_all_panels()
	var config:Dictionary=db.scene_config.GameOverMenuManager
	source_ui.set_text(refid(config,"ratingText"),str(run.result.grade))
	source_ui.set_text(refid(config,"GameOverText"),db.text("GameOver_Won" if run.won else "GameOver_Lost"))
	source_ui.show_node(refid(config,"NewRankObject"),false)
	var rows:Array=[]
	for rating in db.stores.RatingDataStore.RatingTypesList:
		var value=int(run.result.breakdown.get(int(rating.ratingType),0))
		if value!=0:rows.append({"title":db.text(rating.title),"value":value})
	for i in range(config.socrePanelControllersList.size()):
		var id=str(int(config.socrePanelControllersList[i].fileID))
		source_ui.show_node(id,i<rows.size())
		if i<rows.size():set_score_row(id,rows[i].title,rows[i].value)
	set_score_row(refid(config,"socreScorePanelController"),db.text("GameOver_Score"),run.result.score)
	set_score_row(refid(config,"metaScorePanelController"),db.text("GameOver_Scraps"),run.result.meta)

func set_score_row(id:String,title:String,value:int):
	var row:Dictionary=source_ui.components.get(id,{})
	for key in ["scorePanelTitleText","scorePanelTitleBackground"]:source_ui.set_text(refid(row,key),title)
	for key in ["scorePanelValueText","scorePanelValueBackground"]:source_ui.set_text(refid(row,key),str(value))

var performance_samples:Dictionary={}
func profile_mark(key:String,started:int):
	if OS.get_environment("RBPEW_PROFILE")=="1":
		var sample=performance_samples.get(key,{"microseconds":0,"calls":0})
		sample.microseconds+=Time.get_ticks_usec()-started;sample.calls+=1;performance_samples[key]=sample

func _process(dt: float):
	if run!=null and screen in ["rewards","build"] and (run.finished or player.parts[0].hp<=0):
		if not run.finished:run.finish(false)
		reward_flow_active=false;show_result();return
	var combat_dt=Feedback.combat_delta(dt,hit_pause_left)
	hit_pause_left=maxf(0,hit_pause_left-dt)
	hit_pause_cooldown=maxf(0,hit_pause_cooldown-dt)
	camera_recoil=camera_recoil.lerp(Vector2.ZERO,1-exp(-22*dt))
	camera_impact = maxf(0.0, camera_impact - dt * 22.0)
	camera_kick = Vector2(sin(test_time * 91.0), cos(test_time * 73.0)) * camera_impact + camera_recoil
	mouth_activity = move_toward(mouth_activity, 1.0 if screen == "game" and (controls.shooting() or test_mode) else 0.0, dt * 8.0)
	if run!=null and popup_text!=null:
		for notification in run.notifications:popup_text.enqueue(notification)
		run.notifications.clear()
	if particle_effects!=null:
		particle_layer.transform=Transform2D(Vector2(zoom,0),Vector2(0,zoom),center-camera*zoom+camera_kick)
		particle_effects.visible=screen in ["game","pause","result"]
		particle_effects.process_mode=Node.PROCESS_MODE_INHERIT if screen=="game" else Node.PROCESS_MODE_DISABLED
		if screen=="game":
			var engines:Array=[]
			for enemy in combat.enemies:
				if Brood.eligible(enemy):continue
				var motion:Vector2=enemy.position-Vector2(enemy.get('_engine_previous',enemy.position));enemy._engine_previous=enemy.position
				for engine in particle_effects.engine_definitions.get(enemy.prefab,[]):
					if engine.owner!=str(enemy.source_id):continue
					var active=engine.automatic
					match engine.direction:
						'left':active=motion.x>0
						'right':active=motion.x<0
						'up':active=motion.y>0
						'down':active=motion.y<0
					var angle=float(enemy.angle)+PI/2
					var local_angle=float(particle_effects.definitions[engine.key][0].get('angle',0))
					engines.append({'key':str(enemy.uid)+engine.key,'effect':engine.key,'position':enemy.position+Vector2(engine.x,engine.y).rotated(angle)*48,'angle':angle+float(engine.angle)-local_angle,'active':active,'boost':float(enemy.get('boost_left',0))>0})
			particle_effects.sync_engines(engines,dt)
			particle_effects.sync_flames(combat.effects)
	if screen=="build" and run!=null:run.step_recycled_packs(dt)
	if menu_background!=null:
		menu_background.visible=screen in ["menu","options","lab","controls","reward_pool","changelog"]
		menu_background.set_menu(screen)
	if "--ui-probe" in OS.get_cmdline_user_args():
		probe_time+=dt
		if probe_time>0.2:
			probe_time=0
			var report={"screen":screen,"buttons":[],"head":[player.head.x,player.head.y],"meta":save.state.meta,"unlocked":save.state.unlocked.size(),"volume":save.state.settings.volume,"parts":player.parts.size(),"pending":player.pending.size(),"actions":player.actions,"packs":run.packs if run!=null else 0,"layout":player.blueprint()}
			report.window_position=[DisplayServer.window_get_position().x,DisplayServer.window_get_position().y]
			report.window_size=[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y]
			collect_buttons(panel,report.buttons)
			var file=FileAccess.open("res://artifacts/ui-probe.json",FileAccess.WRITE)
			file.store_string(JSON.stringify(report))

	if screen=="build" and controls.joy_device()>=0:
		var pointer_motion=controls.movement()
		if pointer_motion.length()>0.15:
			controller_pointer=(get_viewport().get_mouse_position()+pointer_motion*450*dt).clamp(Vector2.ZERO,get_viewport_rect().size)
			virtual_pointer_time=Time.get_ticks_msec()
			Input.warp_mouse(controller_pointer)
	if tutorials!=null:
		tutorials.visible=screen=="game"
		tutorials.tick(dt,screen=="game" and camera_focus.is_empty(),player,run)
	center = get_viewport_rect().size * 0.5
	if screen == "game":
		if auto_reward_ready() and not run.finished and player.parts[0].hp>0:advance_reward_flow();queue_redraw();return
		if not camera_focus.is_empty():tick_camera_focus(dt);insect_layer.sync(self,0);queue_redraw();return
		var dir:Vector2 = controls.movement(true)
		if test_mode:
			dir = Vector2.from_angle(test_time * 0.7)
		aim = (get_global_mouse_position() - center) / zoom + camera
		var stick:Vector2=controls.joy_aim()
		if stick!=Vector2.ZERO:aim=player.head+stick*700
		var measured=Time.get_ticks_usec()
		player.step(dt, dir, Input.is_action_pressed("boost"))
		leg_phase+=player.velocity.length()*dt*0.075
		player_legs.step(player,dt)
		profile_mark("body",measured);measured=Time.get_ticks_usec()
		# Confirmed heavy hits briefly hold combat motion; steering and UI remain
		# responsive and repeated volleys cannot chain the hold indefinitely.
		combat.step(combat_dt, aim, controls.shooting() or test_mode)
		var particle_bursts=0
		for effect in combat.effects:
			if effect.get("rendered",false):continue
			effect.rendered=true
			var distance=Vector2(effect.position).distance_to(player.head)
			var style=Feedback.profile(str(effect.get("fx_family","impact")))
			if effect.get("friendly",true) and distance<700:
				if effect.kind=="muzzle" and distance<180:
					camera_recoil=(-Vector2(effect.direction)*style.kick*0.6).limit_length(3.0)
				if float(effect.get("hit_pause",0))>0 and hit_pause_cooldown<=0:
					hit_pause_left=float(effect.hit_pause)
					hit_pause_cooldown=0.16
					camera_impact=maxf(camera_impact,style.kick*clampf(1-distance/900.0,0,1))
			if effect.kind=="explosion":
				camera_impact=maxf(camera_impact,clampf(float(effect.radius)/48.0-0.4,0.0,7.0)*clampf(1.0-distance/900.0,0.0,1.0))
			elif effect.get("player_hit",false):camera_impact=maxf(camera_impact,3.5)
			var type=int(effect.get("particle_type",303 if effect.kind=="explosion" else (305 if effect.kind=="hit" else 0)))
			# The layered weapon blast already includes its flash and fragments.
			# Stacking the old opaque ink burst on top hides its color and targets.
			if effect.kind=="explosion" and effect.has("fx_family"):type=0
			if type>0 and particle_bursts<12 and particle_effects.get_child_count()<200 and weapon_fx.visible(self,effect.position,440):
				particle_effects.play(type,effect.position,float(effect.radius)/48 if effect.kind=="explosion" else 1,float(effect.get("duration",0)),effect.get("follow",{}))
				particle_bursts+=1
		profile_mark("combat",measured);measured=Time.get_ticks_usec()
		run.step(dt)
		profile_mark("mission",measured);measured=Time.get_ticks_usec()
		for enemy in combat.enemies:
			if enemy.kind=="AIBossUnit" and not shown_bosses.has(enemy.uid):
				shown_bosses[enemy.uid]=true
				if not save.state.settings.skip_boss:focus_camera(enemy.position,true)
				elif tutorials!=null:tutorials.show_tip("run")
		audio_system.listener=player.head
		for sound in combat.audio_events:audio_system.play_event(sound)
		combat.audio_events.clear()
		var loop_requests:Array=[]
		if player.boost:loop_requests.append({"key":"boost","type":41,"position":player.head})
		for i in range(combat.special.black_holes.size()):loop_requests.append({"key":"hole_"+str(i),"type":23,"position":combat.special.black_holes[i].position})
		var flame_index=0
		for effect in combat.effects:
			if effect.kind=="flame":loop_requests.append({"key":"flame_"+str(flame_index),"type":7,"position":effect.position});flame_index+=1
		audio_system.sync_loops(loop_requests)
		audio_system.change_music("boss" if combat.enemies.any(func(e):return e.kind=="AIBossUnit" and e.active) else "game")
		camera = camera.lerp(player.head, 1.0 - exp(-8.0 * dt))
		update_source_hud()
		profile_mark("audio_hud",measured)
		if run.finished:
			show_result()
		elif auto_reward_ready():advance_reward_flow()
	test_time += dt
	insect_layer.sync(self,dt if screen=="game" else 0.0)
	queue_redraw()

func focus_menu_button():
	if screen=="game" or panel==null:return
	if screen=="menu" and is_instance_valid(mission_ui):mission_ui.focus_selection();return
	if screen=="rewards" and is_instance_valid(reward_ui):reward_ui.focus_first();return
	var candidates:Array=[]
	collect_focus_buttons(panel,candidates)
	if not candidates.is_empty():candidates[0].grab_focus()

func collect_focus_buttons(node:Node,result:Array):
	if node is Button and node.is_visible_in_tree() and not node.disabled:result.append(node)
	for child in node.get_children():collect_focus_buttons(child,result)

func _notification(what):
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and screen=="game" and not test_mode and is_instance_valid(ui):show_pause()

func _input(event):
	if controls!=null:controls.observe(event)
	var using_joy=event is InputEventJoypadButton or event is InputEventJoypadMotion
	if (using_joy and not joy_ui) or (event is InputEventMouseMotion and joy_ui and Time.get_ticks_msec()-virtual_pointer_time>120):
		joy_ui=using_joy
		if is_instance_valid(source_ui):source_ui.set_binding_labels(save.state.settings.bindings,joy_ui)
		if tutorials!=null:tutorials.view.set_binding_labels(save.state.settings.bindings,joy_ui)
	if screen=="intro" and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
		show_menu();get_viewport().set_input_as_handled();return
	if screen=="build" and event is InputEventJoypadMotion and event.axis==JOY_AXIS_TRIGGER_RIGHT:
		var down=event.axis_value>0.5
		if down!=controller_trigger_down:
			controller_trigger_down=down
			var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down;click.position=get_viewport().get_mouse_position();click.global_position=click.position;Input.parse_input_event(click)
		get_viewport().set_input_as_handled();return
	if screen=="loading" and event is InputEventJoypadMotion and event.axis==JOY_AXIS_LEFT_X:
		var down=event.axis_value>0.5
		if down and not tip_stick_down:next_loading_tip()
		tip_stick_down=down;get_viewport().set_input_as_handled();return
	if screen=="loading":
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventJoypadMotion and event.axis==JOY_AXIS_TRIGGER_RIGHT and event.axis_value>0.5):show_game();get_viewport().set_input_as_handled()
		elif event.is_action_pressed("radar") or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_N,KEY_D]):next_loading_tip();get_viewport().set_input_as_handled()
		return
	if screen=="build" and event is InputEventKey and event.physical_keycode==KEY_SPACE:
		var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=event.pressed;click.position=get_viewport().get_mouse_position();click.global_position=click.position;Input.parse_input_event(click);get_viewport().set_input_as_handled();return
	if not event is InputEventJoypadButton:return
	if event.button_index==JOY_BUTTON_A and screen=="build":
		var click=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT;click.pressed=event.pressed;click.position=get_viewport().get_mouse_position();click.global_position=click.position
		Input.parse_input_event(click)
		get_viewport().set_input_as_handled()
	elif event.button_index==JOY_BUTTON_B and event.pressed:
		if screen=="game":show_build()
		elif screen=="reward_pool" or screen=="menu":show_missions() if screen=="reward_pool" else show_menu()
		elif screen in ["lab","options","controls"]:show_menu()
		elif screen=="pause":show_game()
		elif screen in ["rewards","build"]:postpone_rewards()
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if event.is_action_pressed("pause") and screen in ["rewards","build"]:
		postpone_rewards();get_viewport().set_input_as_handled();return
	if rebind_action!="" and event is InputEventKey and event.pressed:
		if event.physical_keycode!=KEY_ESCAPE:controls.bind(rebind_action,event.physical_keycode)
		rebind_action="";show_controls();return
	if event.is_action_pressed("radar") and screen=="game":radar_mode=not radar_mode;zoom=0.25 if radar_mode else 1.0
	if event is InputEventJoypadButton and event.pressed:
		if event.is_action_pressed("build"):
			if screen=="game":show_build()
			elif screen=="build" and player.pending.is_empty():finish_building()
		if event.is_action_pressed("pause"):
			if screen=="game":show_pause()
			elif screen=="pause":show_game()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("pause"):
			if screen == "game": show_pause()
			elif screen == "pause": show_game()
			elif screen in ["menu", "lab", "options", "changelog"]: show_menu()
			elif screen=="reward_pool":show_missions()
		if event.is_action_pressed("build"):
			if screen == "game": show_build()
			elif screen == "build" and player.pending.is_empty(): finish_building()

func world(p: Vector2) -> Vector2:
	return (p - camera) * zoom + center + camera_kick

func art(texture: Texture2D, position: Vector2, size: Vector2, rotation: float = 0.0, tint: Color = Color.WHITE, colored: bool = false):
	if texture == null:
		return
	if not colored and not Ink.keeps_color(texture):
		ink_world.paint(texture, position, size, rotation, tint)
		return
	draw_set_transform(position, rotation)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
	draw_set_transform(Vector2.ZERO)

func module_art(texture: Texture2D, position: Vector2, bounds: Vector2, rotation: float = 0.0, tint: Color = Color.WHITE):
	# Mounts are square; their weapons retain the original sprite proportions.
	art(texture, position, Ink.fitted_size(texture, bounds), rotation, tint, true)

func draw_weapon_neck(anchor: Vector2, tip: Vector2, radius: float, alpha: float = 1.0):
	var bend = (tip - anchor).orthogonal().normalized() * minf(5.0 * zoom, anchor.distance_to(tip) * 0.22)
	var curve = PackedVector2Array()
	for step in range(9):
		var t = float(step) / 8.0
		curve.append(anchor.lerp(tip, t) + bend * sin(t * PI))
	draw_circle(anchor, radius, Color(Ink.INK, alpha * 0.7), true, -1, true)
	draw_polyline(curve, Color(Ink.INK, alpha * 0.8), 6.0 * zoom, true)
	draw_polyline(curve, Color(Ink.WASH, alpha), 3.0 * zoom, true)

func _draw():
	if ink_world != null: ink_world.begin_frame()
	var background=Color("20222c")
	if not background_palette.is_empty():
		var progress=clampf(run.heat if run!=null and screen in ["game","pause","build","rewards","result"] else 0.0,0,1)*2
		var i=mini(1,int(progress));var from:Dictionary=background_palette[i];var to:Dictionary=background_palette[i+1]
		background=Color(from.r,from.g,from.b).lerp(Color(to.r,to.g,to.b),progress-i)
	if background_renderer!=null:background_renderer.configure(camera,background,get_viewport_rect().size,zoom,camera_kick,screen in ["game","pause","result","rewards"])
	else:
		draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),background)
		for i in range(background_layers.size()):
			var speed=[0.02,0.01,0.02,0.06][i]
			var offset=Vector2(fposmod(-camera.x/48*speed*900,900),fposmod(-camera.y/48*speed*900,900))
			for x in range(-1,2):
				for y in range(-1,2):draw_texture_rect(background_layers[i],Rect2(Vector2(x,y)*900+offset,Vector2(900,900)),false)
	if db == null:
		return
	if screen=="home":
		CentipedeArt.tail(self,Vector2(1120-8*55,520+sin(8*0.5+test_time*0.5)*50),0.0,1.0)
		for segment in range(8,-1,-1):
			var pos=Vector2(1120-segment*55,520+sin(segment*0.5+test_time*0.5)*50)
			var ahead=Vector2(1120-(segment-1)*55,520+sin((segment-1)*0.5+test_time*0.5)*50)
			if segment>0:draw_line(pos,ahead,Color("173b70"),23,true)
			CentipedeArt.segment(self,pos,(ahead-pos).angle(),1.0,test_time*3-segment*0.8,segment==0,segment>3)
			if segment in [1,2,3]:module_art(db.core_sprite(db.named(["Core_Gun_Gatling","Core_Gun_Shotgun","Core_Gun_Cannon"][segment-1])),pos,Vector2(35,35),-PI/2)
	if screen in ["game", "pause", "result", "rewards"]:
		for node in run.map_director.nodes.values():
			if node.has("center_sprite"):art(db.sprite(node.center_sprite),world(node.position),Vector2(180,180)*zoom)
		if run.mode.get("class") in ["SDestroyModeManager","SProtectModeManager"]:
			for renderer in db.prefabs[run.objective.objectivePrefab].get("render",[]):
				if "RadarIcons" in db.sprites.get(renderer.sprite,{}).get("name",""):continue
				var texture=db.sprite(renderer.sprite)
				if texture!=null:art(texture,world(Vector2(renderer.x,renderer.y)*48),texture.get_size()/float(db.sprites[renderer.sprite].get("ppu",100))*Vector2(renderer.sx,renderer.sy)*48*zoom)
		if radar_mode:
			for e in combat.enemies:
				var at=world(e.position)
				if Rect2(0,0,1440,900).has_point(at):draw_map_icon(e,at,20)
			draw_circle(world(player.head),8,Color("2f60a0"))
			draw_objective_arrows()
			return
		for e in combat.enemies:
			var hit_flash=clampf(float(e.get("feedback_left",0))/0.095,0,1)
			var visual_position=Vector2(e.position)+Vector2(e.get("feedback_kick",Vector2.ZERO))*hit_flash
			var pos = world(visual_position)
			if pos.x < -250 or pos.x > 1700 or pos.y < -250 or pos.y > 1150:
				continue
			var pulse=health_pulse(e)
			if Brood.eligible(e):
				draw_rect(Rect2(pos+Vector2(-18,-float(e.radius)*zoom-10),Vector2(36*maxf(0,e.hp/e.max_hp),2)),Color("173b70"))
				continue
			for renderer in e.get("render", []):
				var texture: Texture2D = db.sprite(renderer.sprite)
				if texture == null:
					continue
				var ppu: float = db.sprites[renderer.sprite].get("ppu", 100)
				var offset = Vector2(renderer.x, renderer.y).rotated(e.angle + PI * 0.5) * 48
				var extent = texture.get_size() / ppu * Vector2(renderer.sx, renderer.sy) * 48 * zoom
				var tint=RenderState.color(renderer,e.age,pulse,pulse_color(e))
				if hit_flash>0: tint=tint.lerp(Color(2.7,2.7,2.7,tint.a),hit_flash*0.9)
				art(texture, world(visual_position + offset), extent, e.angle + PI * 0.5 + RenderState.angle(renderer,e.age),tint)
			draw_rect(Rect2(pos + Vector2(-22, -e.radius - 12), Vector2(44 * maxf(0, e.hp / e.max_hp), 3)), Color("173b70"))
			for gun in e.guns:
				var texture: Texture2D = db.core_sprite(db.asset(gun.id))
				if texture != null:
					module_art(texture,world(visual_position+Vector2(gun.get("offset",Vector2.ZERO)).rotated(e.angle)),Vector2(42,42)*zoom,float(gun.angle)+PI/2)
		for pack in run.recycled_packs:
			for renderer in db.prefabs[db.pool['203']].get('render',[]):
				var texture=db.sprite(renderer.sprite)
				if texture!=null:
					var factor=0.75*(1-clampf((float(pack.age)-1)/0.25,0,1))
					art(texture,world(pack.position),texture.get_size()/float(db.sprites[renderer.sprite].get('ppu',100))*48*zoom*factor,deg_to_rad(float(pack.age)*-50))
		for drop in combat.loot:
			if not drop.has('_render'):
				var prefab=db.pool['200' if drop.pack else '21']
				drop._render=RenderState.instantiate(db.prefabs[prefab].get('render',[]),int(drop.position.x*13+drop.position.y*17))
			for renderer in drop._render:
				var texture=db.sprite(renderer.sprite)
				if texture!=null:
					var extent=texture.get_size()/float(db.sprites[renderer.sprite].get('ppu',100))*Vector2(renderer.sx,renderer.sy)*48*zoom
					art(texture,world(drop.position),extent,RenderState.angle(renderer,test_time),RenderState.color(renderer,test_time))
		# Continuous insect silhouette; turrets sit on the carapace of each segment.
		var last_pose:Dictionary=player.segment_pose(player.segment_count())
		CentipedeArt.tail(self,world(last_pose.point),Vector2(last_pose.direction).angle(),zoom,player.segment_count()==0)
		for segment in range(player.segment_count(),0,-1):
			var pose:Dictionary=player.segment_pose(segment)
			var previous:Dictionary=player.segment_pose(segment-1)
			draw_line(world(pose.point),world(previous.point),Color("173b70"),22*zoom,true)
			CentipedeArt.segment(self,world(pose.point),Vector2(pose.direction).angle(),zoom,leg_phase-segment*0.8,false,player.parts_on_segment(segment).is_empty(),false,0,-1,player_legs.poses(segment))
		CentipedeArt.segment(self,world(player.head),player.facing.angle(),zoom,leg_phase,true,false,false,mouth_activity,test_time)
		for i in range(player.parts.size()-1,-1,-1):
			var p:Dictionary=player.parts[i]
			var pos=world(player.weapon_origin(i))
			if i>0:draw_weapon_neck(world(p.position),pos,4.0*zoom,0.3 if p.get("cloaked",false) else 1.0)
			var pulse=health_pulse(p)
			var size=Vector2.ONE*player.module_size(i)*zoom
			if p.wall:draw_arc(pos,(player.module_size(i)*0.5+2)*zoom,0,TAU,24,Color("2f60a0"),1.5*zoom,true)
			var c:Dictionary=db.asset(player.hq_weapon if i==0 else p.id)
			var recoil=Vector2.from_angle(p.angle)*float(p.get("recoil",0))*zoom*minf(1,player.module_size(i)/35.0)
			module_art(db.core_sprite(c),pos-recoil,size,p.angle+PI*0.5,Color(1,1,1,0.3) if p.get("cloaked",false) else (pulse_color(p) if pulse else Color.WHITE))
			if p.shield>0 and p.stun<=0:draw_arc(world(p.position),combat.shield_range(i)*zoom,0,TAU,50,Color(0.3,0.8,1.0,0.35),2)
			if i>0:
				var health_at=world(p.position)+Vector2(-20,35)*zoom
				draw_rect(Rect2(health_at,Vector2(40,3)*zoom),Ink.WASH)
				draw_rect(Rect2(health_at,Vector2(40*clampf(p.hp/maxf(1,p.max_hp),0,1),3)*zoom),Ink.BLUE)
		for mine in combat.special.mines:
			module_art(db.sprite(mine.data.mineSprite),world(mine.position),Vector2(22,22)*zoom)
		for d in combat.drones+combat.enemy_drones:
			if d.get("docked",false):continue
			native_visuals.trail(self,d,d.data.get("dronePrefab",0),test_time,zoom)
			var drone_angle=float(d.get("angle",0))+PI/2 if d.data.get("class","")=="ProjectileDrone" else 0.0
			module_art(db.sprite(d.data.get("droneSprite", "")), world(d.position), Vector2(18, 18)*zoom,drone_angle)
		weapon_fx.draw_count=0
		for b in combat.bullets:
			weapon_fx.paint_projectile(self,b,test_time,zoom)
			var texture=db.sprite(b.data.get("projectileSprite",""))
			if texture!=null:
				var extent=texture.get_size()/float(db.sprites[b.data.projectileSprite].get("ppu",100))*48*zoom
				art(texture,world(b.position),extent*maxf(1,b.radius/4),Vector2(b.velocity).angle()+PI/2)
			else:draw_line(world(b.previous),world(b.position),Color("173b70") if b.friendly else Color("6984a4"),b.radius)
		weapon_fx.paint(self,combat,test_time,zoom)
		# Radar uses actual world objects, including distant mission bosses.
		var radar_origin=get_viewport_rect().size-Vector2(210,235)
		draw_rect(Rect2(radar_origin,Vector2(180,150)), Color("d8e3ec"))
		draw_rect(Rect2(radar_origin,Vector2(180,150)),Ink.MUTED,false,1.0)
		for e in combat.enemies:
			var offset: Vector2 = (e.position - player.head) * 0.012
			if offset.length() < 70:
				draw_map_icon(e,radar_origin+Vector2(90,75)+offset,8 if e.kind!="AIBossUnit" else 13)
		draw_circle(radar_origin+Vector2(90,75), 4, Color("173b70"))
		draw_objective_arrows()

func automated_flow():
	await get_tree().process_frame
	await get_tree().create_timer(0.9).timeout
	await capture("00-intro")
	show_menu()
	await capture("01-menu")
	show_missions()
	await capture("05-missions")
	show_options()
	await capture("06-options")
	show_changelog()
	await capture("15-changelog")
	show_reward_pool()
	await capture("11-reward-pool-locked")
	save.state.meta=200
	save.unlock_reward_pool(150)
	show_reward_pool()
	await capture("12-reward-pool")
	begin_run()
	await capture("13-loading-tips")
	show_game()
	var ids: Array = [db.named("Core_Gun_Gatling").id, db.named("Core_Gun_Shotgun").id, db.named("Core_Gun_Tesla").id]
	for i in range(3):
		player.add_piece(ids[i], Vector2i(0, -i - 1))
	player.add_piece(db.named("Core_Shield").id, Vector2i(1, -2))
	combat.spawn(db.pool["250"], Vector2(500, 50))
	await get_tree().create_timer(3.0).timeout
	await capture("02-live-centipede")
	show_pause()
	await capture("07-pause")
	show_build()
	await get_tree().process_frame
	await capture("03-free-build")
	run.rewards.enqueue(true)
	show_rewards()
	await capture("10-rewards")
	show_lab()
	await get_tree().process_frame
	await capture("04-research")
	panel.get_child(0).show_detail(db.research[0],0)
	await get_tree().create_timer(1.0).timeout
	await capture("08-research-video")
	run.finish(false)
	show_result()
	await capture("09-result")
	print("SMOKE_FLOW_COMPLETE")
	await safe_shutdown()

func capture(name: String):
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		var destination = OS.get_environment("RBPEW_CAPTURE_DIR")
		if destination.is_empty(): destination = "user://screenshots"
		DirAccess.make_dir_recursive_absolute(destination)
		image.save_png(destination + "/" + name + ".png")

func safe_shutdown():
	if cursor_system!=null:cursor_system.shutdown()
	if audio_system != null:audio_system.shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func collect_buttons(node:Node,result:Array):
	if node is Button and node.is_visible_in_tree() and not node.disabled:
		var rect=node.get_global_rect()
		result.append({"name":str(node.get_parent().name),"text":node.text,"x":rect.get_center().x,"y":rect.get_center().y})
	for child in node.get_children():collect_buttons(child,result)

func draw_map_icon(enemy:Dictionary,at:Vector2,pixels:float):
	if Brood.eligible(enemy):
		var insect=Brood.texture("enemy_"+Brood.species(enemy))
		art(insect,at,Ink.fitted_size(insect,Vector2.ONE*pixels),0,Color.WHITE,true)
		return
	var threat=int(enemy.unit.get("aIThreatLevel",0))
	var sprites:Array=db.stores.AIDataStore.threatsLevelSprites
	var texture=db.sprite(sprites[clampi(threat,0,sprites.size()-1)])
	art(texture,at,Ink.fitted_size(texture,Vector2.ONE*pixels),0,Ink.MUTED if enemy.role=="friendly" else Ink.INK,true)

func draw_objective_arrows():
	for enemy in combat.enemies:
		if enemy.kind!="AIBossUnit" and not enemy.objective:continue
		var at=world(enemy.position)
		if Rect2(80,80,1280,740).has_point(at):continue
		var direction=(at-center).normalized()
		var extent=minf(610/maxf(0.001,absf(direction.x)),340/maxf(0.001,absf(direction.y)))
		var pos=center+direction*extent
		art(db.sprite("714f0dad9b162d542b7f9a76b5690691"),pos,Vector2(30,30),direction.angle(),Ink.INK,true)
		draw_map_icon(enemy,pos-direction*27,22)

func source_hit_color()->Color:
	var c:Dictionary=db.stores.PlayerDataStore.get('playerHitColor',{})
	return Color(c.get('r',1),c.get('g',1),c.get('b',1),1)
func health_pulse(entity:Dictionary)->bool:
	if entity.hp!=float(entity.get('_visual_hp',entity.hp)):
		entity._visual_hit_until=test_time+0.10
		entity._visual_repair=entity.hp>float(entity.get('_visual_hp',entity.hp))
	entity._visual_hp=entity.hp
	return test_time<float(entity.get('_visual_hit_until',0)) or float(entity.get("impact_left",0))>0

func pulse_color(entity:Dictionary)->Color:
	if not entity.get('_visual_repair',false):return source_hit_color()
	var c:Dictionary=db.stores.PlayerDataStore.get('playerRepairColor',{})
	return Color(c.get('r',1),c.get('g',1),c.get('b',1),1)
