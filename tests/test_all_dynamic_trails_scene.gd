extends SceneTree
## Native production routes, fixed-anchor animation checks and a short flight fixture.
const FX=preload("res://scripts/weapon_fx.gd")
const Layer=preload("res://scripts/attack_shader_layer.gd")
const Trails=preload("res://scripts/projectile_trails.gd")
const Motion=preload("res://scripts/viscous_projectile_motion.gd")
const Native=preload("res://scripts/native_visuals.gd")
const Death=preload("res://scripts/enemy_death_splatter.gd")
const DB=preload("res://scripts/source_db.gd")
const Ink=preload("res://scripts/blue_ink.gd")
class Board extends Node2D:
	var fx=FX.new()
	var native=Native.new()
	var layer:Node2D
	var phase=0.0
	var held=false
	var offset=Vector2.ZERO
	var world_scale=1.0
	var reds:Array=[]
	var remnants:Array=[]
	var drones:Array=[]
	var textures:Array=[]
	var font:Font=load("res://assets/fonts/NotoSansSC-Light.otf")
	const TITLES=["G 雷须 · 连续流动的电束","H 穿喙 · 柔性束体与压力波","O 死亡喷溅 · 喷流与独立液滴","红色敌弹 · 弯曲、流动、渐隐","蜂群 · 实际飞行轨迹","兼容长束入口 · 双方颜色"]
	const NOTES=["束体单独变化，接触端点保持准确","不再拉长旧尾丝贴图","液滴走弧线，尾巴沿过去的位置消散","保留危险色，尾部不再像硬三角","攻击 / 修补 / 采集，各自保留颜色","旧接口也使用动态束体"]
	func world(p):return offset+Vector2(p)*world_scale
	func _ready():
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		layer=Layer.new();layer.attach(self)
		var db=DB.new()
		for name in ["Drones_HQ_Attack","Drones_HQ_Engineer","Drones_HQ_Scrapper"]:
			var data=db.named(name);textures.append(db.sprite(data.droneSprite))
			drones.append({"position":Vector2(35,60+drones.size()*65),"data":data,"friendly":true})
	func _draw():
		layer.begin_frame(phase);fx.clock=phase;fx.draw_count=0
		draw_rect(Rect2(0,0,1440,900),Color("f1eee3"))
		draw_string(font,Vector2(24,36),"剩余拖尾动态化 · G / H / O / 红色来弹 / 蜂群",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("213b6e"))
		draw_string(font,Vector2(24,65),"原生渲染与正式绘制路径 · 放大观察；不代表实战帧率",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("637075"))
		for i in 6:
			var origin=Vector2(14+(i%3)*476,86+int(i/3)*400)
			var style=StyleBoxFlat.new();style.bg_color=Color("fbf8ed");style.border_color=Color("d8d7ca");style.set_border_width_all(1);style.set_corner_radius_all(12)
			draw_style_box(style,Rect2(origin,Vector2(460,386)))
			draw_string(font,origin+Vector2(16,33),TITLES[i],HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("213b6e"))
			draw_string(font,origin+Vector2(16,361),NOTES[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("637075"))
			offset=origin;world_scale=1.0
			if i in [0,1]:
				var progress=.24 if held else fposmod(phase,.8)/.8
				fx.paint_effect(self,{"position":Vector2(40,185),"end":Vector2(410,185),"kind":"chain","fx_family":"tesla" if i==0 else "rail","life":.32*(1.0-progress),"fx_duration":.32,"friendly":true},1.8)
			elif i==2:
				var age=.15 if held else fposmod(phase,1.2)
				Death.paint(self,{"position":Vector2(220,195),"radius":40.0,"direction":Vector2.RIGHT,"life":1.25-age,"fx_duration":1.25,"seed":13,"boss":false},1.05,true)
			elif i==3:
				offset=origin+Vector2(30,85);world_scale=1.4
				for old in remnants:Trails.paint(Layer.route(self,"gatling",true),old,1.4,phase)
				for shot in reds:fx.paint_projectile(self,shot,phase,1.4)
			elif i==4:
				offset=origin+Vector2(25,30);world_scale=1.4
				for n in drones.size():
					var drone=drones[n];var family=Trails.actor_family(drone)
					native.trail(self,drone,drone.data.dronePrefab,phase,1.4)
					var painter=Layer.route(self,family);var size=Ink.fitted_size(textures[n],Vector2(38,38))
					painter.draw_set_transform(world(drone.position));painter.draw_texture_rect(textures[n],Rect2(-size*.5,size),false);painter.draw_set_transform(Vector2.ZERO)
			else:
				for friendly in [true,false]:native.beam(self,{"position":Vector2(40,150 if friendly else 235),"end":Vector2(410,150 if friendly else 235),"friendly":friendly},phase,1.5)
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	var board=Board.new();root.add_child(board)
	var captures:Array=[]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/all-trails-frames"))
	for frame in 144:
		if frame%24==0:
			var shot={"position":Vector2(20,80),"previous":Vector2(20,80),"origin":Vector2(20,80),"velocity":Vector2(330,0),"age":0.0,"life":.72,"radius":4.0,"friendly":false,"fx_family":"gatling"}
			Motion.initialize(shot,frame/24);board.reds.append(shot)
		for shot in board.reds:
			shot.previous=shot.position;shot.age+=1.0/60;shot.life-=1.0/60
			shot.velocity=Vector2.from_angle(sin(shot.age*4.0)*.7)*330;Motion.advance(shot,1.0/60)
		Trails.advance(board.reds,board.remnants,1.0/60);board.reds=board.reds.filter(func(s):return s.life>0)
		for n in board.drones.size():
			var t=fposmod(frame/60.0,.9)
			board.drones[n].position=Vector2(35+t*230,60+n*65+sin(t*4)*11)
			if frame%54==0:board.drones[n].erase("flight_trail")
		Trails.advance_actors(board.drones,1.0/60)
		board.phase=(frame+1)/60.0;board.queue_redraw();await process_frame
		if frame%2==1 and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var path="res://artifacts/all-trails-frames/frame-%03d.png"%(frame/2)
			if root.get_texture().get_image().save_png(path)!=OK:printerr("ERROR: dynamic trail preview capture failed");quit(1);return
			captures.append(path)
	var changes:Array=[];var unchanged=true
	if DisplayServer.get_name()!="headless":
		board.held=true
		var snapshots:Array=[];var before=board.reds.duplicate(true);var drone_before=board.drones.duplicate(true)
		for time in [2.4,2.53]:
			board.phase=time;board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			snapshots.append(root.get_texture().get_image())
		unchanged=before==board.reds and drone_before==board.drones
		for panel in 6:
			var origin=Vector2i(14+(panel%3)*476,86+int(panel/3)*400);var changed=0
			for y in range(origin.y+65,origin.y+330):
				for x in range(origin.x+25,origin.x+435):
					var a:Color=snapshots[0].get_pixel(x,y);var b:Color=snapshots[1].get_pixel(x,y)
					if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.025:changed+=1
			changes.append(changed)
		var path="res://artifacts/all-trails-held.png";snapshots[1].save_png(path)
	var passed=unchanged and (changes.is_empty() or changes.all(func(n):return n>8))
	if not passed:printerr("ERROR: fixed histories must keep flowing without writes: ",changes)
	var report={"passed":passed,"renderer":DisplayServer.get_name(),"frames":captures,"duration":2.4,"frozen_panel_changed_pixels":changes,"simulation_unchanged":unchanged,"scope":"Native production G/H/O, hostile projectile, all three drone families and compatibility beams. Fixed geometry/simulation with advancing shared shader time must change native pixels; not a full-game FPS test."}
	FileAccess.open("res://artifacts/all-dynamic-trails-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"passed":passed,"frames":captures.size(),"frozen_panel_changed_pixels":changes}));quit(0 if passed else 1)
