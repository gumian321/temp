extends SceneTree
## Art routing, alpha, color and unchanged sprite proportions at actual mount sizes.
const Art=preload("res://scripts/insect_armaments.gd")
const DB=preload("res://scripts/source_db.gd")
const Brood=preload("res://scripts/brood_theme.gd")
const Ink=preload("res://scripts/blue_ink.gd")
const ITEMS=[
	["gatling","蜂尾针簇","Core_Gun_Gatling"],["shotgun","裂颚","Core_Gun_Shotgun"],
	["cannon","爆腹","Core_Gun_Cannon"],["flak","刺冠","Core_Gun_Flak"],
	["sniper","穿喙","Core_Gun_Sniper"],["tesla","雷须","Core_Gun_Tesla"],
	["emp","缄鸣","Core_Gun_EMP"],["flame","炽嗉","Core_Gun_Flame Thrower"],
	["rocket","追蛹","Core_Gun_Rocket"],["nuke","王卵","Core_Gun_Nuke"],
	["sonic","振翅","Core_Gun_SonicWave"],["blackhole","螳涡","Core_Gun_BlackHoler"],
	["mine","卵环","Core_MinesField"],["mine_spawner","播卵","Core_MineSpawner"],
	["drone_bay","猎蜂巢","Core_Drones_Attack"]]
var checks:Array=[]
class Board extends Node2D:
	var font:Font=load("res://assets/fonts/NotoSansSC-Light.otf")
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Ink.PAPER)
		draw_string(font,Vector2(32,49),"蜈蚣武装 · 哑色贴图 / 轻微阴影",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Ink.INK)
		draw_string(font,Vector2(33,82),"15 种武器与装置 · 下方为头部 / 体节 / 待装图标：42 / 56 / 78 像素",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Ink.MUTED)
		for i in ITEMS.size():
			var cell=Vector2(30+i%5*282,110+i/5*245)
			draw_rect(Rect2(cell,Vector2(264,224)),Color("ccd8df"),false,1)
			draw_string(font,cell+Vector2(16,28),ITEMS[i][1],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Ink.INK)
			var texture=Brood.weapon_texture(ITEMS[i][0])
			var extent=Ink.fitted_size(texture,Vector2(120,98))
			draw_texture_rect(texture,Rect2(cell+Vector2(132,95)-extent/2,extent),false)
			for j in range(3):
				var size=[42,56,78][j]
				var small=Ink.fitted_size(texture,Vector2.ONE*size)
				draw_texture_rect(texture,Rect2(cell+Vector2(55+j*71,185)-small/2,small),false)
		draw_string(font,Vector2(34,883),"透明图集 · 装配 / 奖励 / 战斗共用 · 全部等比缩放",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Ink.MUTED)
		for extra in [["mine_unit","孢雷实体",970],["drone_unit","猎蜂",1200]]:
			var texture=Brood.weapon_texture(extra[0])
			var extent=Ink.fitted_size(texture,Vector2(32,32))
			draw_texture_rect(texture,Rect2(Vector2(extra[2],873)-extent/2,extent),false)
			draw_string(font,Vector2(extra[2]+25,881),extra[1],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Ink.INK)
func _initialize():call_deferred("execute")
func check(value:bool,title:String):
	checks.append({"name":title,"passed":value})
	if not value:printerr("FAIL: ",title)
func capture(path:String):
	await process_frame;await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path)==OK,"Captured "+path.get_file())
func execute():
	root.size=Vector2i(1440,900)
	var db=DB.new()
	Ink.register_game_colors(db)
	var distinct:Dictionary={}
	for entry in ITEMS:
		var texture=db.core_sprite(db.named(entry[2]))
		var path=texture.atlas.resource_path if texture is AtlasTexture else ""
		check(path == Art.atlas_path(entry[0]) and db.armament_variant(db.named(entry[2])) == entry[0],"Production core resolves to new art: "+entry[0])
		distinct[path+str(texture.region)]=true
		var fit_ok=Ink.keeps_color(texture)
		for size in [28,36,42,44,56,96]:
			var extent=Ink.fitted_size(texture,Vector2.ONE*size)
			fit_ok=fit_ok and is_equal_approx(extent.x/texture.get_width(),extent.y/texture.get_height()) and maxf(extent.x,extent.y)<=size+0.001
		check(fit_ok,"Color and proportions survive all mount/UI sizes: "+entry[0])
		var pixels=texture.atlas.get_image()
		var edge_clear=true
		for point in [Vector2i(0,0),Vector2i(pixels.get_width()-1,0),Vector2i(0,pixels.get_height()-1),Vector2i(pixels.get_width()-1,pixels.get_height()-1)]:
			edge_clear=edge_clear and pixels.get_pixelv(point).a<0.03
		check(edge_clear and pixels.detect_alpha()!=Image.ALPHA_NONE,"Transparent background survives import: "+entry[0])
	check(distinct.size()==15,"Every weapon and both mine devices have distinct art")
	var routed=0
	for core in db.catalog.values():
		if not core.has("coreProjectile"):continue
		routed+=1
		check(db.core_sprite(core).atlas.resource_path == Art.atlas_path(db.armament_variant(core)),"HQ/player/enemy weapon shares current art: "+core.name)
	check(routed==38,"All 32 source gun cores and six mutation gun cores are themed")
	for drone in db.kind("ProjectileDrone"):
		check(db.sprite(drone.droneSprite) == Art.texture("drone_unit"),"Attack drone entity is themed: "+drone.name)
	check(db.sprite(db.named("Projectile_Core_Mine").mineSprite) == Art.texture("mine_unit"),"Deployed mine entity is themed")
	var board=Board.new();board.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;root.add_child(board)
	await capture("res://artifacts/armament-v2-lineup.png")
	board.queue_free();await process_frame
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	check(game.material==null,"Approved atlas colours render without a global darkening filter")
	game.performance_overlay.visible=false
	game.set_process(false);game.save.state.settings.skip_boss=true;game.start_run()
	game.combat.enemies.clear();game.combat.drones.clear()
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
	game.run.rewards.queue.clear();game.run.packs=0
	game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true
	for i in ITEMS.size():
		game.player.install_module(db.named(ITEMS[i][2]).id,i+1,4)
	check(game.player.segment_count()==ITEMS.size() and game.player.parts_on_segment(1).size()==1,"Each weapon device occupies its own complete segment")
	game.build_selected_segment=1;game.show_build()
	await capture("res://artifacts/armament-v2-build.png")
	check(game.build_ui.segment_buttons.size()==ITEMS.size() and game.build_ui.segment_buttons.values().all(func(s):return s.get_parent()==game.build_ui.body_canvas and db.core_sprite(db.asset(s.payload.part.id)) is AtlasTexture and db.armament_variant(db.asset(s.payload.part.id)) in ITEMS.map(func(item):return item[0])),"Direct body assembly routes every mounted physical element to its generated weapon image")
	game.show_game();game.camera=game.player.head-Vector2(540,0);game.zoom=1.0
	game.label_at("生体武装 · 哑色与浅阴影",Vector2(455,145),27)
	game.label_at("保留造型、简化纹理；装配与战斗共用",Vector2(390,189),19)
	game.queue_redraw();await capture("res://artifacts/armament-v2-mounted.png")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(12):OS.delay_msec(10);await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed),"renderer":DisplayServer.get_name(),"new_textures":17,"weapon_devices":15}
	FileAccess.open("res://artifacts/armament-v2-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
