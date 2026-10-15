extends SceneTree
## Controlled targets, real combat events and the production scene renderer.
const Feedback = preload("res://scripts/weapon_feedback.gd")
var game
var checks: Array=[]
var captures: Array=[]
var clip_frames=0
var shader_frames=0
const CASES=[
	["gatling","Core_Gun_Gatling"],["shotgun","Core_Gun_Shotgun"],
	["cannon","Core_Gun_Cannon"],["flak","Core_Gun_Flak"],
	["rail","Core_Gun_Sniper"],["tesla","Core_Gun_Tesla"],
	["emp","Core_Gun_EMP"],["flame","Core_Gun_Flame Thrower"],
	["rocket","Core_Gun_Rocket"],["nuke","Core_Gun_Nuke"],
	["sonic","Core_Gun_SonicWave"],["blackhole","Core_Gun_BlackHoler"],
	["mine","Core_MinesField"],["drone","Core_Drones_Attack"]]
func _initialize():call_deferred("execute")
func check(value:bool,title:String):
	checks.append({"name":title,"passed":value})
	if not value:printerr("FAIL: ",title)
func picture(path:String,small:bool=false):
	game.queue_redraw()
	await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	if game.attack_shader_layer.stats().commands>0:shader_frames+=1
	check(game.attack_shader_layer.materials.size()==game.attack_shader_layer.MODES.size(),"All attack ShaderMaterials attached")
	var img=root.get_texture().get_image()
	if small:img.resize(1080,675,Image.INTERPOLATE_LANCZOS)
	check(img.save_png(path)==OK,"Saved "+path.get_file())
func execute():
	if DisplayServer.get_name()=="headless":
		printerr("ERROR: Shader showcase requires native rendering");quit(1);return
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false)
	game.save.state.settings.skip_boss=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/round14/weapon-frames"))
	for entry in CASES:
		var family:String=entry[0]
		shader_frames=0
		game.start_run()
		game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
		game.run.rewards.queue.clear();game.run.packs=0
		game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true
		game.combat.enemies.clear();game.combat.drones.clear()
		game.combat.rng.seed=1702;game.combat.loot_rng.seed=104
		var core:Dictionary=game.db.named(entry[1])
		game.zoom=1.3
		var label=Label.new();label.text=family.to_upper()+" / PRODUCTION COMBAT";label.position=Vector2(485,140);label.add_theme_font_size_override("font_size",26);root.add_child(label)
		label.add_theme_color_override("font_color",Color("254978"))

		var target=game.player.head+Vector2(265,0)
		if family=="mine":
			game.player.install_module(core.id,1,4)
			game.combat.special.step(0.016)
			target=game.combat.special.mines[0].position
		elif family=="drone":
			game.player.install_module(core.id,1,4)
			game.combat.add_drone(1,game.db.named("Drones_Core_Attack"))
			game.combat.drones[0].ping=0.0
			target=game.player.head+Vector2(125,0)
		else:game.player.hq_weapon=core.id
		for offset in [Vector2.ZERO,Vector2(50,-62),Vector2(85,66)]:
			var enemy=game.combat.spawn(game.db.pool["250"],target+offset)
			enemy.guns=[];enemy.mission_controlled=true;enemy.hp=2500;enemy.max_hp=2500
			if family=="sonic":enemy.hp=35;enemy.max_hp=35
		var shot_at=game.player.head
		var last_shot=-10.0
		var contact_frame=-1
		var captured=false
		var animated=true
		for frame in range(150):
			var seconds=frame/60.0
			if core.has("coreProjectile"):
				if family=="flame":game.combat.special.continuous(core,shot_at,Vector2.RIGHT,true,{},0,1.0/60.0,"showcase")
				elif seconds-last_shot>=1.0/maxf(0.1,float(core.get("turretRateOfFire",1))):
					game.combat.fire(core,shot_at,Vector2.RIGHT,true)
					game.player.parts[0].recoil=Feedback.profile(family).recoil
					last_shot=seconds
			game._process(1.0/60.0)
			game.camera=game.player.head+Vector2(0,-10)
			game.mouth_activity=1.0
			if contact_frame<0 and game.combat.effects.any(func(e):return e.get("fx_family")==family and e.kind in ["hit","explosion","hole_birth"]):contact_frame=frame
			if contact_frame>=0 and frame==contact_frame+4:
				var path="res://artifacts/round14/weapon-"+family+".png"
				await picture(path);captures.append(path);captured=true
			if animated and contact_frame>=0 and frame<=contact_frame+45 and (frame-contact_frame)%3==0:
				await picture("res://artifacts/round14/weapon-frames/frame-%04d.png"%clip_frames,true)
				clip_frames+=1
			elif frame%3==0:await process_frame
			if captured and (not animated or frame>=contact_frame+45):break
		check(shader_frames>0,family+" production shader batches draw during lifetime")
		check(contact_frame>=0 and captured,family+" reaches a target through real combat and renders its feedback")
		check(game.screen=="game",family+" keeps the production scene playable")
		label.queue_free()
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear()
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(12):
		OS.delay_msec(10)
		await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"clip_frames":clip_frames,"passed":checks.all(func(c):return c.passed),"scope":"Fourteen real weapon families against stationary controlled targets in the production scene. Preview captures visual behavior; audio is validated separately."}
	FileAccess.open("res://artifacts/round14/weapon-shader-showcase-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
