extends SceneTree
const Art=preload("res://scripts/insect_projectiles.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const DB=preload("res://scripts/source_db.gd")
const Feedback=preload("res://scripts/weapon_feedback.gd")
const KEYS=["gatling","shotgun","cannon","flak","rocket","nuke","emp","blackhole","sonic"]
var checks:Array=[]
class Board extends Node2D:
	var fx=FX.new()
	var font:Font=load("res://assets/fonts/NotoSansSC-Light.otf")
	func world(at:Vector2)->Vector2:return at
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("eee9d9"))
		draw_string(font,Vector2(35,55),"虫群弹体 · 甲刺 / 颚片 / 酸囊 / 刺荚 / 追蛹 / 王卵 / 鸣珠 / 螺孢 / 翅籽",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("213b6e"))
		for i in KEYS.size():
			var origin=Vector2(40+i%3*465,95+i/3*260)
			draw_rect(Rect2(origin,Vector2(440,240)),Color("c8c8b8"),false,1)
			draw_string(font,origin+Vector2(18,31),Feedback.profile(KEYS[i]).label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("213b6e"))
			var texture=Art.texture(KEYS[i]);var size=texture.get_size();var extent=size*minf(120/size.x,105/size.y)
			draw_texture_rect(texture,Rect2(origin+Vector2(95,115)-extent/2,extent),false)
			for j in range(4):
				var point=origin+Vector2(210+(j%2)*120,88+(j/2)*85)
				var direction=Vector2.RIGHT if j<2 else Vector2.UP
				var bullet={"position":point,"previous":point-direction*50,"origin":point-direction*50,"velocity":direction*600,"radius":4.0,"friendly":j%2==0,"fx_family":KEYS[i],"data":{}}
				fx.paint_projectile(self,bullet,1.5,1.0)
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func _initialize():call_deferred("execute")
func execute():
	var raw=Art.load_atlas(true)
	check(raw is ImageTexture and raw.get_size()==Vector2(1254,1254),"Fresh source checkout loads PNG without imported cache")
	var db=DB.new()
	var seen:Dictionary={}
	for data in db.catalog.values():
		if not data.has("projectileSprite"):continue
		var family=Art.family({"data":data})
		check(Art.texture(family)!=null,"Organic body resolves for source projectile "+str(data.get("name","")))
		seen[family]=true
	for key in KEYS:
		var tex=Art.texture(key)
		check(tex is AtlasTexture and tex.atlas!=null and tex.region==Art.REGIONS[Art.CELLS[key]],key+" uses the generated organic atlas")
		var image=tex.get_image()
		check(image.get_pixel(0,0).a<0.01 and image.get_used_rect().get_area()>0,key+" is nonempty with genuine transparent surroundings")
		var border_alpha=0.0
		for x in image.get_width():border_alpha=maxf(border_alpha,maxf(image.get_pixel(x,0).a,image.get_pixel(x,image.get_height()-1).a))
		for y in image.get_height():border_alpha=maxf(border_alpha,maxf(image.get_pixel(0,y).a,image.get_pixel(image.get_width()-1,y).a))
		check(border_alpha<0.02,key+" region preserves the entire silhouette without clipping")
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
		check(Vector2.from_angle(Art.angle({"velocity":direction*500})).dot(direction)>0.999,"Generated right-facing sprite follows launch velocity "+str(direction))
	check(is_equal_approx(Art.angle({"velocity":Vector2.ZERO,"direction":Vector2.UP}),-PI/2),"Zero-speed shot preserves its launch heading")
	check(Art.family({"fx_family":"unknown","data":{}})=="gatling" and Art.texture("unknown")==Art.texture("gatling"),"Unknown families safely use chitin stinger art")
	check(Art.CELLS.rocket!=Art.CELLS.nuke and Art.CELLS.rocket!=Art.CELLS.cannon,"Seeking grub, queen egg and acid bladder have distinct silhouettes")
	var main=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(not 'db.sprite(b.data.get("projectileSprite"' in main,"Live bullet renderer cannot overlay factory missiles")
	var board=Board.new();root.add_child(board)
	await process_frame;await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/insect-projectile-lineup.png")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"families":seen.keys()}
	FileAccess.open("res://artifacts/insect-projectile-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
