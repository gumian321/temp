extends Node2D

const DB = preload("res://scripts/source_db.gd")
const Save = preload("res://scripts/save_store.gd")
const Body = preload("res://scripts/centipede.gd")
const Battle = preload("res://scripts/combat.gd")
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
var message: Label
var center = Vector2(720, 450)
var camera = Vector2.ZERO
var aim = Vector2.RIGHT
var zoom = 1.0
var selected_piece = -1
var build_action = "place"
var build_origin = Vector2(720, 440)
const AudioSystem = preload("res://scripts/audio_system.gd")
var audio_system
var music: AudioStreamPlayer
var test_mode = false
var test_time = 0.0
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

func _ready():
	db = DB.new()
	save = Save.new(db)
	if "--smoke" in OS.get_cmdline_user_args():save.path="user://smoke-isolated.json";save.fresh()
	controls=InputSystem.new(save)
	db.language = save.state.settings.language
	player = Body.new(db)
	combat = Battle.new(db, player)
	selected_mission = db.asset(db.stores.MissionDataStore.missionsList[0])
	ui = CanvasLayer.new()
	add_child(ui)
	font = load("res://assets/fonts/NotoSansSC-Light.otf")
	var theme = Theme.new()
	theme.default_font = font
	ThemeDB.fallback_font = font
	audio_system=AudioSystem.new()
	add_child(audio_system)
	audio_system.setup(db,save)
	music=audio_system.music
	tutorials=load("res://scripts/tutorial_ui.gd").new();add_child(tutorials);tutorials.setup(db,save)
	for name in ["Background Nebula BackGround.png","BackStarsMat.png","Background Nebula ForeGround.png","FrontStarsMat.png"]:background_layers.append(load("res://assets/backgrounds/"+name))
	background_palette=db.scene_config.BackgroundColorChanger.backgroundColorPresetsList[1].colorsList
	if OS.get_environment("RBPEW_BACKGROUND_ORIGINAL")!="1":
		background_renderer=load("res://scripts/background_layers.gd").new();add_child(background_renderer);background_renderer.setup(background_layers)
	cursor_system=load("res://scripts/cursor_system.gd").new();add_child(cursor_system);cursor_system.setup(db)
	menu_background=load("res://scripts/menu_background.gd").new();add_child(menu_background);menu_background.setup(db)
	particle_layer=CanvasLayer.new();particle_layer.layer=0;add_child(particle_layer)
	particle_effects=load("res://scripts/particle_effects.gd").new();particle_layer.add_child(particle_effects);particle_effects.setup(db);native_visuals.setup(db,particle_effects)
	popup_text=load("res://scripts/popup_text.gd").new();popup_text.layer=3;add_child(popup_text)
	show_intro()
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
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("focus_menu_button")

func label_at(text: String, pos: Vector2, size: int = 22, color: Color = Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
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
	label_at("RUN / BUILD / PEW!", Vector2(64, 35), 19, Color("ebaa4b"))
	label_at(title, Vector2(64, 75), 44)
	label_at(subtitle, Vector2(66, 134), 18, Color("a8acae"))

func show_intro():
	screen="intro"
	clear_ui()
	var intro=load("res://scripts/intro_ui.gd").new();panel.add_child(intro)
	intro.setup(db,func():
		if screen=="intro":show_menu())

func show_menu():
	if audio_system!=null:audio_system.sync_loops([])
	screen="home"
	audio_system.change_music("menu")
	clear_ui()
	source_ui=SourceUI.new();panel.add_child(source_ui)
	source_ui.setup(db,"MainMenuScene/MenuCanvas",source_ui_action,save.state.settings.bindings)

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
		content.text=FileAccess.get_file_as_string("res://data/changelog.txt").replace("<b>","[b]").replace("</b>","[/b]").replace("<size=50>","[font_size=30]").replace("</size>","[/font_size]")
		content.add_theme_font_size_override("normal_font_size",20);scroll.add_child(content)

func source_screen(key:String):
	clear_ui();source_ui=SourceUI.new();panel.add_child(source_ui);source_ui.setup(db,key,source_ui_action,save.state.settings.bindings);source_ui.set_binding_labels(save.state.settings.bindings,joy_ui)

func refid(config:Dictionary,key:String)->String:
	return str(int(config.get(key,{}).get("fileID",0)))

func show_missions():
	screen="menu"
	source_screen("MainMenuScene/PlayCanvas")
	var config:Dictionary=db.scene_config.PlayUIManager
	source_ui.set_text(refid(config,"missionText"),db.title(selected_mission))
	source_ui.set_text(refid(config,"missionDescText"),db.text(selected_mission.MissionDescTextID))
	source_ui.set_text(refid(config,"missionDiffecultyText"),"("+db.text(db.stores.MissionDataStore.DifficultiesList[difficulty].diffecultyTextID)+")")
	source_ui.set_image(refid(config,"missionObjectiveImage"),selected_mission.MissionsObjectiveList[difficulty].objectiveSprite)
	source_ui.show_node(refid(config,"playButton"),save.mission_unlocked(selected_mission))
	source_ui.show_node(refid(config,"researchButton"),not save.mission_unlocked(selected_mission))
	source_ui.show_node(refid(config,"demoButton"),false)
	source_ui.show_node(refid(config,"backButton"),true)
	source_ui.set_text(refid(config,"costText"),str(int(selected_mission.MissionCost)))
	for name in source_ui.nodes_by_name:
		if "LeaderBoard" in name:source_ui.nodes_by_name[name].visible=false
	# The source's IntervalSlider is a composite wrapper; bind its actual native Slider.
	for slider in source_ui.sliders.values():slider.min_value=0;slider.max_value=2;slider.step=1;slider.set_value_no_signal(difficulty)
	label_at("%d RP"%save.state.meta,Vector2(1190,40),23,Color("ebaa4b"))

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
	source_ui.set_text(refid(config,"languageText"),str(options_draft.language))
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
	var resolution:Dictionary=db.scene_config.OptionMenuManager.resolutions[int(options_draft.resolution)]
	DisplayServer.window_set_mode([DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_WINDOWED][int(options_draft.screen_mode)])
	if int(options_draft.screen_mode)==2:DisplayServer.window_set_size(Vector2i(int(resolution.width),int(resolution.height)))
	audio_system.refresh();save.save();show_options()

func show_controls():
	screen="controls"
	frame(db.text("Option_Controls"),"Select a binding, then press a key. Esc cancels rebinding.")
	var index=0
	for action in InputSystem.DEFAULTS:
		var code=int(save.state.settings.bindings.get(action,InputSystem.DEFAULTS[action]))
		button(action.replace("_"," ").capitalize()+"   ["+OS.get_keycode_string(code)+"]",Vector2(80,205+index*63),Vector2(600,50),func():rebind_action=action;message.text="Press a key for "+action)
		index+=1
	for i in range(3):
		var key=["invert_x","invert_y","left_aim"][i]
		button(key.replace("_"," ").capitalize()+": "+str(save.state.settings[key]),Vector2(800,250+i*80),Vector2(490,50),func():save.state.settings[key]=not save.state.settings[key];save.save();show_controls())
	message=label_at("",Vector2(800,535),20)
	button("Reset bindings",Vector2(800,610),Vector2(490,50),func():save.state.settings.bindings.clear();controls.apply();save.save();show_controls())
	button(db.text("Option_Back"),Vector2(80,810),Vector2(260,50),func():options_draft=save.state.settings.duplicate(true);show_options())

func start_run():
	if popup_text!=null:popup_text.clear()
	if particle_effects!=null:particle_effects.clear()
	if tutorials!=null:tutorials.reset_run()
	player = Body.new(db)
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
	for id in ["11","90","264","408","37"]:source_ui.show_node(id,false)
	for id in ["43","124"]:source_ui.show_node(id,true)
	for slider in source_ui.sliders.values():slider.editable=false
	hud=label_at("",Vector2(30,25),19)
	message=label_at("WASD · Mouse · Shift · E · Esc",Vector2(30,855),18)
	button("BUILD [E]",Vector2(1220,30),Vector2(180,45),show_build)
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

func show_build():
	audio_system.sync_loops([])
	if run == null:
		return
	if screen in ["build","rewards"] and player.pending.is_empty() and run.packs==0 and not player.actions.values().any(func(v):return v>0):show_game();return
	screen = "build"
	if player.pending.is_empty() and not player.actions.values().any(func(v):return v>0) and run.packs>0:show_rewards();return
	frame("FREE BUILD", "Choose a reward, then place each module on an adjacent cell. Layout rows become following body sections.")
	label_at("Pending parts: %d   •   Reward packs: %d" % [player.pending.size(), run.packs], Vector2(64, 195), 22, Color("ebaa4b"))
	var actions: Array = ["place", "move", "swap", "duplicate", "wall"]
	for i in range(actions.size()):
		var action: String = actions[i]
		var count: String = "" if action == "place" else " (%d)" % player.actions[action]
		button(action.to_upper() + count, Vector2(64, 255 + i * 65), Vector2(220, 50), func(): build_action = action; selected_piece = -1)
	if not player.pending.is_empty():
		label_at("PLACE: " + db.title(db.asset(player.pending[0])), Vector2(64, 615), 19, Color("e8bb66"))
	message = label_at("", Vector2(64, 760), 18, Color("e8bb66"))
	button("OPEN REWARD", Vector2(1060, 250), Vector2(300, 55), show_rewards, run.packs == 0 or not player.pending.is_empty())
	button("RESUME [E]", Vector2(1060, 650), Vector2(300, 55), show_game, not player.pending.is_empty() or run.packs>0 or player.actions.values().any(func(v):return v>0))
	var stats_ui=SourceUI.new();panel.add_child(stats_ui);stats_ui.setup(db,"GameScene/InGame Canvas",source_ui_action)
	var stats_panel=stats_ui.controls["37"]
	stats_panel.reparent(stats_ui,false)
	for child in stats_ui.get_children():child.visible=child==stats_panel
	stats_panel.position=Vector2(940,285)
	var config:Dictionary=stats_ui.components["1559"]
	var values={"shipSpeedText":11,"shipBoostText":12,"partDamageText":15,"partRangeText":3,"partRateText":2,"partHealthText":16,"hqDamageText":14}
	for key in values:stats_ui.set_text(refid(config,key),"+%d%%"%(100+int(100*float(player.stats.get(str(values[key]),0)))))


func show_rewards():
	var choices:Array=run.roll_rewards()
	if choices.is_empty():return
	screen="rewards"
	source_screen("GameScene/InGame Canvas")
	for id in ["11","43","51","5","37","21","59","470","124","408"]:source_ui.show_node(id,false)
	source_ui.set_text("293",str(run.packs))
	var manager:Dictionary=source_ui.components["1572"]
	for i in range(manager.rewardUIPanelControllersList.size()):
		var id=str(int(manager.rewardUIPanelControllersList[i].fileID))
		var config:Dictionary=source_ui.components[id]
		source_ui.show_node(id,i<choices.size())
		if i>=choices.size():continue
		var reward:Dictionary=choices[i]
		source_ui.set_text(refid(config,"rewardTitle"),db.title(reward))
		for field in ["rewardSprite","rewardSprite1","rewardSprite2","rewardOverlay","rewardOverlay1","rewardOverlay2"]:source_ui.show_node(refid(config,field),false)
		if reward.get("class")=="CrusedReward":
			for pair in [["rewardSprite1","buffRewardSprite"],["rewardSprite2","debuffRewardSprite"],["rewardOverlay1","buffRewardOverlaySprite"],["rewardOverlay2","debuffRewardOverlaySprite"]]:
				source_ui.show_node(refid(config,pair[0]),true);source_ui.set_image(refid(config,pair[0]),reward[pair[1]])
		else:
			var image_id=refid(config,"rewardSprite")
			source_ui.show_node(image_id,true)
			if source_ui.images.has(image_id):source_ui.images[image_id].texture=db.reward_sprite(reward)
			if reward.get("rewardOverlaySprite") is String:
				source_ui.show_node(refid(config,"rewardOverlay"),true);source_ui.set_image(refid(config,"rewardOverlay"),reward.rewardOverlaySprite)
		var can_select=run.can_reward(reward)
		source_ui.show_node(refid(config,"rewardLock"),not can_select)
		var select_button=source_ui.buttons.get(refid(config,"rewardSelectButton"))
		if select_button!=null:
			select_button.disabled=not can_select
			select_button.pressed.connect(func():run.take_reward(reward);show_build())
		for j in range(config.starsList.size()):source_ui.show_node(str(int(config.starsList[j].fileID)),j<int(player.levels.get(reward.id,0))+1 and "LevelUp" in reward.get("class",""))
	label_at("CHOOSE YOUR REWARD",Vector2(520,65),30)

func begin_run():
	start_run()
	show_loading()

func show_loading():
	screen="loading"
	source_screen("GameScene/InGame Canvas")
	source_ui.show_node("12",false);source_ui.show_node("11",true)
	var config:Dictionary=db.scene_config.LoadingPanelContorller
	source_ui.show_node(refid(config,"loadingObject"),false)
	source_ui.show_node(refid(config,"doneLoadingObject"),true)
	for pair in [["127","337","133","LMB"],["261","373","259","D"]]:
		source_ui.show_node(pair[0],false);source_ui.show_node(pair[1],true);source_ui.set_text(pair[2],pair[3])
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
	if run!=null and popup_text!=null:
		for notification in run.notifications:popup_text.enqueue(notification)
		run.notifications.clear()
	if particle_effects!=null:
		particle_layer.transform=Transform2D(Vector2(zoom,0),Vector2(0,zoom),center-camera*zoom)
		particle_effects.visible=screen in ["game","pause","result"]
		particle_effects.process_mode=Node.PROCESS_MODE_INHERIT if screen=="game" else Node.PROCESS_MODE_DISABLED
		if screen=="game":
			decoration_system.refresh(player)
			var engines:Array=[]
			for decoration in decoration_system.decorations:
				if decoration.type!=505:continue
				var pose:Dictionary=decoration_system.pose(decoration,player)
				var exhaust=Vector2.DOWN.rotated(pose.angle)
				engines.append({'key':str(decoration.cell),'position':pose.position,'angle':pose.angle,'active':player.velocity.dot(exhaust)<-0.001,'boost':player.boost})
			for enemy in combat.enemies:
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
		menu_background.visible=screen in ["home","menu","options","lab","controls","reward_pool","changelog"]
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
		if not camera_focus.is_empty():tick_camera_focus(dt);queue_redraw();return
		var dir:Vector2 = controls.movement()
		if test_mode:
			dir = Vector2.from_angle(test_time * 0.7)
		aim = (get_global_mouse_position() - center) / zoom + camera
		var stick:Vector2=controls.joy_aim()
		if stick!=Vector2.ZERO:aim=player.head+stick*700
		var measured=Time.get_ticks_usec()
		player.step(dt, dir, Input.is_action_pressed("boost"))
		profile_mark("body",measured);measured=Time.get_ticks_usec()
		combat.step(dt, aim, controls.shooting() or test_mode)
		for effect in combat.effects:
			if effect.get("rendered",false):continue
			effect.rendered=true
			var type=int(effect.get("particle_type",303 if effect.kind=="explosion" else (305 if effect.kind=="hit" else 0)))
			if type>0:particle_effects.play(type,effect.position,float(effect.radius)/48 if effect.kind=="explosion" else 1,float(effect.get("duration",0)),effect.get("follow",{}))
		profile_mark("combat",measured);measured=Time.get_ticks_usec()
		run.step(dt)
		profile_mark("mission",measured);measured=Time.get_ticks_usec()
		for enemy in combat.enemies:
			if enemy.kind=="AIBossUnit" and not shown_bosses.has(enemy.uid):
				shown_bosses[enemy.uid]=true
				if not save.state.settings.skip_boss:focus_camera(enemy.position,true)
				elif tutorials!=null:tutorials.show_tip("run")
		audio_system.listener=player.head
		for sound in combat.audio_events:audio_system.play(sound.type,sound.position)
		combat.audio_events.clear()
		var loop_requests:Array=[]
		if player.boost:loop_requests.append({"key":"boost","type":41,"position":player.head})
		for i in range(combat.special.black_holes.size()):loop_requests.append({"key":"hole_"+str(i),"type":23,"position":combat.special.black_holes[i].position})
		var flame_index=0
		for effect in combat.effects:
			if effect.kind=="flame":loop_requests.append({"key":"flame_"+str(flame_index),"type":7,"position":effect.position});flame_index+=1
		audio_system.sync_loops(loop_requests)
		audio_system.change_music("boss" if combat.enemies.any(func(e):return e.kind=="AIBossUnit" and e.active) else "game")
		camera = camera.lerp(player.head, minf(1, dt * 5))
		hud.text = "%s\nHQ %d/%d · FUEL %d%%"%[db.title(selected_mission),int(player.parts[0].hp),int(player.parts[0].max_hp),int(player.fuel/maxf(1,player.max_fuel)*100)]
		update_source_hud()
		profile_mark("audio_hud",measured)
		if run.packs>=6: show_build()
		if run.finished:
			show_result()
	test_time += dt
	queue_redraw()

func focus_menu_button():
	if screen=="game" or panel==null:return
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
		elif screen=="build":selected_piece=-1
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if rebind_action!="" and event is InputEventKey and event.pressed:
		if event.physical_keycode!=KEY_ESCAPE:controls.bind(rebind_action,event.physical_keycode)
		rebind_action="";show_controls();return
	if event.is_action_pressed("radar") and screen=="game":radar_mode=not radar_mode;zoom=0.25 if radar_mode else 1.0
	if event is InputEventJoypadButton and event.pressed:
		if event.is_action_pressed("build"):
			if screen=="game":show_build()
			elif screen=="build" and player.pending.is_empty() and run.packs==0 and not player.actions.values().any(func(v):return v>0):show_game()
		if event.is_action_pressed("pause"):
			if screen=="game":show_pause()
			elif screen=="pause":show_game()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("pause"):
			if screen == "game": show_pause()
			elif screen == "pause": show_game()
			elif screen in ["lab", "options", "changelog"]: show_menu()
			elif screen=="reward_pool":show_missions()
		if event.is_action_pressed("build"):
			if screen == "game": show_build()
			elif screen == "build" and player.pending.is_empty() and run.packs==0 and not player.actions.values().any(func(v):return v>0): show_game()
	if screen == "build" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = (event.position - build_origin) / 46.0
		var cell = Vector2i(roundi(local.x), -roundi(local.y))
		if abs(cell.x) > 5 or abs(cell.y) > 5:
			return
		var index = -1
		for i in range(player.parts.size()):
			if player.parts[i].cell == cell:
				index = i
		if build_action == "place" and not player.pending.is_empty():
			if player.add_piece(player.pending[0], cell):
				player.pending.pop_front()
				show_build()
			else:
				message.text = player.last_error
		elif build_action == "wall":
			player.reinforce(index)
			show_build()
		elif selected_piece < 0:
			selected_piece = index
			message.text = "Select destination" if index > 0 else "Select a built module"
		else:
			match build_action:
				"move": player.move_piece(selected_piece, cell)
				"swap": player.swap_piece(selected_piece, index)
				"duplicate": player.duplicate_piece(selected_piece, cell)
			selected_piece = -1
			show_build()

func world(p: Vector2) -> Vector2:
	return (p - camera) * zoom + center

func art(texture: Texture2D, position: Vector2, size: Vector2, rotation: float = 0.0, tint: Color = Color.WHITE):
	if texture == null:
		return
	draw_set_transform(position, rotation)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
	draw_set_transform(Vector2.ZERO)

func _draw():
	var background=Color("20222c")
	if not background_palette.is_empty():
		var progress=clampf(run.heat if run!=null and screen in ["game","pause","build","rewards","result"] else 0.0,0,1)*2
		var i=mini(1,int(progress));var from:Dictionary=background_palette[i];var to:Dictionary=background_palette[i+1]
		background=Color(from.r,from.g,from.b).lerp(Color(to.r,to.g,to.b),progress-i)
	if background_renderer!=null:background_renderer.configure(camera,background,get_viewport_rect().size)
	else:
		draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),background)
		for i in range(background_layers.size()):
			var speed=[0.02,0.01,0.02,0.06][i]
			var offset=Vector2(fposmod(-camera.x/48*speed*900,900),fposmod(-camera.y/48*speed*900,900))
			for x in range(-1,2):
				for y in range(-1,2):draw_texture_rect(background_layers[i],Rect2(Vector2(x,y)*900+offset,Vector2(900,900)),false)
	if db == null:
		return
	if screen in ["game", "pause", "result"]:
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
			draw_circle(world(player.head),8,Color("ffeabd"))
			draw_objective_arrows()
			return
		for e in combat.enemies:
			var pos = world(e.position)
			if pos.x < -250 or pos.x > 1700 or pos.y < -250 or pos.y > 1150:
				continue
			var pulse=health_pulse(e)
			for renderer in e.get("render", []):
				var texture: Texture2D = db.sprite(renderer.sprite)
				if texture == null:
					continue
				var ppu: float = db.sprites[renderer.sprite].get("ppu", 100)
				var offset = Vector2(renderer.x, renderer.y).rotated(e.angle + PI * 0.5) * 48
				var extent = texture.get_size() / ppu * Vector2(renderer.sx, renderer.sy) * 48 * zoom
				art(texture, world(e.position + offset), extent, e.angle + PI * 0.5 + RenderState.angle(renderer,e.age),RenderState.color(renderer,e.age,pulse,pulse_color(e)))
			draw_rect(Rect2(pos + Vector2(-22, -e.radius - 12), Vector2(44 * maxf(0, e.hp / e.max_hp), 3)), Color("d88760"))
			for gun in e.guns:
				var texture: Texture2D = db.core_sprite(db.asset(gun.id))
				if texture != null:
					art(texture,world(e.position+Vector2(gun.get("offset",Vector2.ZERO)).rotated(e.angle)),Vector2(42,42)*zoom,float(gun.angle))
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
		var rows: Array = player.body_rows()
		for i in range(rows.size(), 0, -1):
			var pose: Dictionary = player.path_sample(i * player.body_spacing)
			var previous: Dictionary = player.path_sample((i - 1) * player.body_spacing)
			draw_line(world(pose.point), world(previous.point), Color("708578"), 13)
			var pos = world(pose.point)
			draw_circle(pos, 23, Color("35483d"))
			for side in [-1, 1]:
				var normal: Vector2 = Vector2(pose.direction).orthogonal() * side
				var knee: Vector2 = pose.point + normal * 38 - pose.direction * 12
				var foot: Vector2 = pose.point + normal * 54 - pose.direction * (24 + sin(test_time * 10 + i) * 8)
				draw_line(pos, world(knee), Color("9baf94"), 4)
				draw_line(world(knee), world(foot), Color("9baf94"), 3)
		decoration_system.refresh(player)
		for decoration in decoration_system.decorations:
			var pose:Dictionary=decoration_system.pose(decoration,player)
			for renderer in db.prefabs[db.pool[str(decoration.type)]].get('render',[]):
				var texture=db.sprite(renderer.sprite)
				if texture!=null:
					var extent=texture.get_size()/float(db.sprites[renderer.sprite].get('ppu',100))*Vector2(renderer.sx,renderer.sy)*44*zoom
					art(texture,world(pose.position),extent,pose.angle+renderer.angle)
		for i in range(player.parts.size() - 1, -1, -1):
			var p: Dictionary = player.parts[i]
			var pos = world(p.position)
			var pulse=health_pulse(p)
			var size = Vector2(72, 72) if i == 0 else Vector2(42, 42)
			var health_sprites:Array=db.stores.CoresDataStore.mainCoreHealthSprites if i==0 else db.stores.CoresDataStore.coreHealthSprites
			art(db.sprite(health_sprites[clampi(int(p.hp/maxf(1,p.max_hp)*health_sprites.size()),0,health_sprites.size()-1)]),pos,size)
			if p.wall:art(db.sprite(db.stores.CoresDataStore.walledCoreSprite),pos,size)
			var c: Dictionary = db.asset(player.hq_weapon if i == 0 else p.id)
			art(db.core_sprite(c), pos, size * 0.9, p.angle + PI * 0.5,Color(1,1,1,0.3) if p.get("cloaked",false) else (pulse_color(p) if pulse else Color.WHITE))
			if p.shield > 0 and p.stun<=0:
				draw_arc(pos, combat.shield_range(i)*zoom, 0, TAU, 50, Color(0.3, 0.8, 1.0, 0.35), 2)
			if p.hp < p.max_hp:
				draw_rect(Rect2(pos + Vector2(-20, -29), Vector2(40 * maxf(0, p.hp / p.max_hp), 3)), Color("b7dd65"))
		for mine in combat.special.mines:
			art(db.sprite(mine.data.mineSprite),world(mine.position),Vector2(22,22)*zoom)
		for hole in combat.special.black_holes:
			draw_circle(world(hole.position),hole.radius*zoom,Color(0.04,0.01,0.09,0.8))
			draw_arc(world(hole.position),hole.radius*zoom,0,TAU,50,Color("a65ceb"),3)
		for d in combat.drones+combat.enemy_drones:
			if d.get("docked",false):continue
			native_visuals.trail(self,d,d.data.get("dronePrefab",0),test_time,zoom)
			art(db.sprite(d.data.get("droneSprite", "")), world(d.position), Vector2(18, 18))
		for b in combat.bullets:
			native_visuals.trail(self,b,b.data.get("projectilePrefab",0),test_time,zoom)
			var texture=db.sprite(b.data.get("projectileSprite",""))
			if texture!=null:
				var extent=texture.get_size()/float(db.sprites[b.data.projectileSprite].get("ppu",100))*48*zoom
				art(texture,world(b.position),extent*maxf(1,b.radius/4),Vector2(b.velocity).angle()+PI/2)
			else:draw_line(world(b.previous),world(b.position),Color("e6f3bb") if b.friendly else Color("f57562"),b.radius)
		for effect in combat.effects:
			if effect.kind in ["explosion","hit","shield_hit","pickup","emp","flame"]:continue
			if effect.kind=="chain":native_visuals.beam(self,effect,test_time,zoom)
			elif effect.kind=="flame":
				draw_line(world(effect.position), world(effect.end), Color("a6e7f0") if effect.kind=="chain" else Color("ee803d"),3 if effect.kind=="chain" else 24)
			else:
				draw_arc(world(effect.position), effect.radius * (1 - effect.life), 0, TAU, 28, Color(1, 0.75, 0.4, minf(1, effect.life * 2)), 3)
		# Radar uses actual world objects, including distant mission bosses.
		draw_rect(Rect2(1230, 665, 180, 150), Color(0.03, 0.05, 0.05, 0.9))
		for e in combat.enemies:
			var offset: Vector2 = (e.position - player.head) * 0.012
			if offset.length() < 70:
				draw_map_icon(e,Vector2(1320,740)+offset,8 if e.kind!="AIBossUnit" else 13)
		draw_circle(Vector2(1320, 740), 4, Color("e4ebbb"))
		draw_objective_arrows()
	elif screen == "build":
		for x in range(-5, 6):
			for y in range(-5, 6):
				var pos = build_origin + Vector2(x, -y) * 46
				draw_rect(Rect2(pos - Vector2(21, 21), Vector2(42, 42)), Color("293732"), false, 1)
		for i in range(player.parts.size()):
			var p: Dictionary = player.parts[i]
			var pos = build_origin + Vector2(p.cell.x, -p.cell.y) * 46
			var size = Vector2(86, 86) if i == 0 else Vector2(42, 42)
			if i == 0: pos += Vector2(23, -23)
			draw_rect(Rect2(pos - size * 0.5, size), Color("9da878") if i == selected_piece else Color("637668"))
			art(db.core_sprite(db.asset(player.hq_weapon if i == 0 else p.id)), pos, size * 0.85)

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
	var threat=int(enemy.unit.get("aIThreatLevel",0))
	var sprites:Array=db.stores.AIDataStore.threatsLevelSprites
	var texture=db.sprite(sprites[clampi(threat,0,sprites.size()-1)])
	var faction=int(enemy.unit.get("aIFaction",1))
	var value:Dictionary=db.stores.AIDataStore["BlueColor" if faction==0 else "RedColor"]
	var tint=Color(value.r,value.g,value.b)
	if enemy.role=="friendly":tint=Color("5de553")
	art(texture,at,Vector2.ONE*pixels,0,tint)

func draw_objective_arrows():
	for enemy in combat.enemies:
		if enemy.kind!="AIBossUnit" and not enemy.objective:continue
		var at=world(enemy.position)
		if Rect2(80,80,1280,740).has_point(at):continue
		var direction=(at-center).normalized()
		var extent=minf(610/maxf(0.001,absf(direction.x)),340/maxf(0.001,absf(direction.y)))
		var pos=center+direction*extent
		art(db.sprite("714f0dad9b162d542b7f9a76b5690691"),pos,Vector2(30,30),direction.angle())
		draw_map_icon(enemy,pos-direction*27,22)

func source_hit_color()->Color:
	var c:Dictionary=db.stores.PlayerDataStore.get('playerHitColor',{})
	return Color(c.get('r',1),c.get('g',1),c.get('b',1),1)
func health_pulse(entity:Dictionary)->bool:
	if entity.hp!=float(entity.get('_visual_hp',entity.hp)):
		entity._visual_hit_until=test_time+0.05
		entity._visual_repair=entity.hp>float(entity.get('_visual_hp',entity.hp))
	entity._visual_hp=entity.hp
	return test_time<float(entity.get('_visual_hit_until',0))

func pulse_color(entity:Dictionary)->Color:
	if not entity.get('_visual_repair',false):return source_hit_color()
	var c:Dictionary=db.stores.PlayerDataStore.get('playerRepairColor',{})
	return Color(c.get('r',1),c.get('g',1),c.get('b',1),1)
