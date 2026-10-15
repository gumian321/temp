extends SceneTree
## Native production shaders on parchment, paired friendly/hostile skill samples.
const Layer=preload("res://scripts/attack_shader_layer.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const Controls=preload("res://scripts/insect_attack_fx.gd")
class Canvas extends Node2D:
	func world(point):return point
var checks=[]
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func _initialize():call_deferred("execute")
func execute():
	if DisplayServer.get_name()=="headless":quit(1);return
	root.size=Vector2i(1440,900)
	var canvas=Canvas.new();root.add_child(canvas)
	var paper=ColorRect.new();paper.color=Color("f5f2e7");paper.size=Vector2(1440,900);paper.z_index=-1;canvas.add_child(paper)
	var layer=Layer.new();layer.attach(canvas);layer.begin_frame(0)
	var fx=FX.new();fx.clock=.33
	var db=load("res://scripts/source_db.gd").new()
	var keys=Layer.MODES.keys()
	for i in keys.size():
		var key=keys[i];var at=Vector2(145+(i%5)*280,125+(i/5)*205)
		var label=Label.new();label.text=key.to_upper()+"  /  FRIENDLY + HOSTILE";label.position=at+Vector2(-125,-70);label.add_theme_color_override("font_color",Color("173b70"));label.add_theme_font_size_override("font_size",13);canvas.add_child(label)
		for hostile in [false,true]:
			var point=at+Vector2(0,58 if hostile else 0)
			if key in ["repair_drone","scrap_drone"]:
				var painter=Layer.route(canvas,key,hostile)
				painter.draw_set_transform(point)
				painter.draw_texture_rect(db.sprite(db.named("Drones_Core_Engineer" if key=="repair_drone" else "Drones_Core_Scrapper").droneSprite),Rect2(-25,-18,50,36),false)
			elif key in ["silk","tendril"]:
				Controls.paint(canvas,[{"kind":key,"origin":point-Vector2(95,0),"target":{"position":point+Vector2(90,0),"hp":100,"radius":13},"life":.65,"duration":1.0,"friendly":not hostile}],1)
			elif key=="blackhole":fx.paint_hole(canvas,{"position":point,"radius":24,"friendly":not hostile},1)
			elif key in ["rail","tesla","sonic","flame"]:
				fx.paint_effect(canvas,{"kind":"flame" if key=="flame" else "chain","position":point-Vector2(100,0),"end":point+Vector2(100,0),"fx_family":key,"life":.65,"fx_duration":1.0,"friendly":not hostile},.9)
			elif key=="impact":fx.paint_effect(canvas,{"kind":"explosion","position":point,"radius":36,"fx_family":key,"life":.65,"fx_duration":1.0,"friendly":not hostile},1)
			else:fx.paint_projectile(canvas,{"position":point,"origin":point-Vector2(110,0),"previous":point-Vector2(5,0),"velocity":Vector2(300,0),"age":.33,"radius":7,"fx_family":key,"friendly":not hostile},.33,1.4)
	var commands=layer.stats().commands
	var images=[]
	for phase in [0.0,.8]:
		for mat in layer.materials.values():mat.set_shader_parameter("clock",phase)
		await process_frame;await RenderingServer.frame_post_draw
		var img=root.get_texture().get_image();images.append(img)
		check(img.save_png("res://artifacts/organic-skills-"+str(phase)+".png")==OK,"Saved native both-side preview")
	for i in keys.size():
		var at=Vector2i(145+(i%5)*280,125+(i/5)*205)
		for hostile in [false,true]:
			var changed=0
			var row=at.y+(58 if hostile else 0)
			for y in range(row-25,row+25):
				for x in range(at.x-115,at.x+115):
					if images[0].get_pixel(x,y)!=images[1].get_pixel(x,y):changed+=1
			check(changed>5,"%s %s material visibly animates on parchment"%[keys[i],"hostile" if hostile else "friendly"])
	check(commands==layer.stats().commands,"Shader animation reuses all submitted geometry")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"stats":layer.stats()}
	FileAccess.open("res://artifacts/organic-skill-readability-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	canvas.queue_free();await process_frame;quit(0 if report.passed else 1)
