extends SceneTree
const FX=preload("res://scripts/weapon_fx.gd")
const Motion=preload("res://scripts/viscous_projectile_motion.gd")
class Board extends Node2D:
	var fx=FX.new()
	var phase=0.0
	var font:Font=load("res://assets/fonts/NotoSansSC-Light.otf")
	func world(p:Vector2)->Vector2:return p
	func label(at:Vector2,text:String):draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("213b6e"))
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("f5f2e7"))
		label(Vector2(35,45),"黏液 / 虫卵 / 幼虫 / 舌刺 · 实际弹体绘制路径")
		for row in 3:
			var zoom=[0.6,1.0,2.5][row]
			label(Vector2(35,100+row*190),"缩放 %.1f"%zoom)
			for col in 4:
				var kind=["gatling","flak","rocket","sonic"][col]
				var at=Vector2(260+col*320,125+row*190)
				label(at+Vector2(-65,-30),["黏液弹","虫卵弹","活体幼虫","舌刺"][col])
				for friendly in [true,false]:
					var point=at+Vector2(0,0 if friendly else 66)
					var shot={"position":point,"previous":point-Vector2(20,0),"origin":point-Vector2(90,0),"velocity":Vector2(600,0),"radius":4.0,"fx_family":kind,"friendly":friendly,"data":{}}
					Motion.initialize(shot,col);fx.paint_projectile(self,shot,phase,zoom)
		label(Vector2(35,690),"贴附与破裂 · 接触点；舌刺收缩")
		for col in 4:
			var at=Vector2(220+col*310,760)
			draw_circle(at+Vector2(18,0),32,Color("ddcbb1"))
			var kind=["mucus","egg","larva","egg"][col]
			var effect={"kind":"egg_burst" if col==3 or (col==1 and phase>=0.75) else "viscous_contact","organic_family":kind,"fx_family":"flak" if kind=="egg" else "cannon","friendly":true,"position":at,"direction":Vector2.RIGHT,"normal":Vector2.LEFT,"radius":9.0,"life":0.18*(1.0-phase) if col==3 else (0.72 if kind=="egg" else 0.34)*(1.0-phase),"fx_duration":0.72 if kind=="egg" else 0.34}
			fx.paint_effect(self,effect,2.0)
		fx.paint_effect(self,{"kind":"chain","position":Vector2(250,850),"end":Vector2(1000,850),"life":0.22*(1.0-phase),"fx_duration":0.22,"fx_family":"tesla","friendly":true},1)
func _initialize():call_deferred("execute")
func execute():
	root.size=Vector2i(1440,900)
	var board=Board.new();root.add_child(board)
	for phase in [0.12,0.5,0.85]:
		board.phase=phase;board.queue_redraw();await process_frame;await process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var path="res://artifacts/viscous-lineup-%02d.png"%int(phase*100)
			var result=root.get_texture().get_image().save_png(path)
			if result!=OK:printerr("ERROR: capture failed ",path);quit(1);return
	print("VISCOUS_SCENE_OK renderer=",DisplayServer.get_name());quit(0)
