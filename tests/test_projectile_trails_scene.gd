extends SceneTree
## Native renderer capture of the production body/trail path; scripted flight fixture.
const FX=preload("res://scripts/weapon_fx.gd")
const Trails=preload("res://scripts/projectile_trails.gd")
const Motion=preload("res://scripts/viscous_projectile_motion.gd")
const Layer=preload("res://scripts/attack_shader_layer.gd")
const Feedback=preload("res://scripts/weapon_feedback.gd")
const Art=preload("res://scripts/insect_projectiles.gd")
class Board extends Node2D:
	var fixtures:Array=[]
	var phase=0.0
	var panel_origin=Vector2.ZERO
	var fx=FX.new()
	var layer:Node2D
	var font:Font=load("res://assets/fonts/NotoSansSC-Light.otf")
	func world(at):return panel_origin+at*1.6
	func _ready():
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		layer=Layer.new();layer.attach(self)
	func _draw():
		layer.begin_frame(phase);fx.draw_count=0
		draw_rect(Rect2(0,0,1440,900),Color("f1eee3"))
		draw_string(font,Vector2(28,40),"独立弹体 + 动态尾迹",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("213b6e"))
		draw_string(font,Vector2(28,70),"原生渲染 · 1.6 倍观察 · 轨迹采样 / 尾部流动 / 命中后余尾淡出",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("617075"))
		for i in fixtures.size():
			var f:Dictionary=fixtures[i]
			var origin=Vector2(16+(i%3)*474,92+int(i/3)*394)
			draw_style_box(panel_style(),Rect2(origin,Vector2(460,376)))
			draw_string(font,origin+Vector2(18,34),f.label,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("213b6e"))
			draw_string(font,origin+Vector2(18,62),"转弯保留经过的位置" if i>0 else "尾迹逐渐收细、淡出",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("617075"))
			panel_origin=origin+Vector2(35,138)
			for old in f.remnants:Trails.paint(Layer.route(self,f.key,not f.friendly),old,1.6,phase)
			for shot in f.shots:fx.paint_projectile(self,shot,phase,1.6)
			panel_origin=origin+Vector2(52,305)
			Art.paint(self,{"position":Vector2.ZERO,"velocity":Vector2.RIGHT*100,"friendly":f.friendly,"fx_family":f.key,"radius":4},1.6,phase)
			draw_string(font,origin+Vector2(94,311),"弹体单独显示",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("617075"))
	func panel_style()->StyleBoxFlat:
		var style=StyleBoxFlat.new();style.bg_color=Color("fbf8ed");style.border_color=Color("d8d7ca")
		style.set_border_width_all(1);style.set_corner_radius_all(12)
		return style
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	var board=Board.new()
	var keys=["cannon","nuke","rocket","emp","blackhole","gatling"]
	for i in keys.size():
		board.fixtures.append({"key":keys[i],"label":"敌方来弹" if i==5 else Feedback.profile(keys[i]).label,"friendly":i!=5,"shots":[],"remnants":[],"curve":[.0,.4,.62,-.35,.5,.4][i]})
	root.add_child(board)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/projectile-trail-frames"))
	var captures:Array=[]
	for frame in 120:
		for f in board.fixtures:
			if frame%24==0:
				var shot={"position":Vector2.ZERO,"previous":Vector2.ZERO,"origin":Vector2.ZERO,"velocity":Vector2.RIGHT*350,"age":0.0,"life":.68,"radius":4.0,"friendly":f.friendly,"fx_family":f.key}
				Motion.initialize(shot,frame/30);f.shots.append(shot)
			for shot in f.shots:
				shot.previous=shot.position;shot.age+=1.0/60.0;shot.life-=1.0/60.0
				shot.velocity=Vector2.from_angle(float(f.curve)*sin(float(shot.age)*2.5))*350
				Motion.advance(shot,1.0/60.0)
			Trails.advance(f.shots,f.remnants,1.0/60.0)
			f.shots=f.shots.filter(func(shot):return shot.life>0)
		board.phase=(frame+1)/60.0;board.queue_redraw();await process_frame
		if frame%2==1 and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var path="res://artifacts/projectile-trail-frames/frame-%03d.png"%(frame/2)
			if root.get_texture().get_image().save_png(path)!=OK:printerr("ERROR: trail frame capture failed");quit(1);return
			captures.append(path)
	var animated=true;var immutable=true;var changed=0
	if DisplayServer.get_name()!="headless":
		var shot:Dictionary=board.fixtures[0].shots[-1]
		var original=shot.duplicate(true);var pictures:Array=[]
		for phase in [2.0,2.11]:
			board.phase=phase;board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			pictures.append(root.get_texture().get_image())
		var center=Vector2(51,230)+Vector2(shot.position)*1.6
		for y in range(int(center.y)-9,int(center.y)+10):
			for x in range(int(center.x)-104,int(center.x)-41):
				var a:Color=pictures[0].get_pixel(x,y);var b:Color=pictures[1].get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.015:changed+=1
		animated=changed>4;immutable=shot==original
		if not animated or not immutable:printerr("ERROR: held tail must animate without simulation writes: ",changed)
	var report={"passed":animated and immutable,"renderer":DisplayServer.get_name(),"frames":captures,"duration":2.0,"held_tail_changed_pixels":changed,"held_shot_immutable":immutable,"scope":"Native production body/trail rendering in a scripted flight fixture at 1.6x size. Frozen-geometry tail pixels animate through the shared shader. No claim of live combat frame rate; actual fire/step and hit semantics are covered separately."}
	FileAccess.open("res://artifacts/projectile-trails-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"passed":report.passed,"renderer":report.renderer,"frames":captures.size(),"held_tail_changed_pixels":changed}));quit(0 if report.passed else 1)
