extends SceneTree
## Regressions for the reported square blast, delayed steering and segmented art.
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Art = preload("res://scripts/centipede_art.gd")
const Ink = preload("res://scripts/blue_ink.gd")
var checks: Array = []

func check(value: bool, description: String):
	checks.append({"name":description,"passed":value})
	if not value: printerr("FAIL: ",description)

func _initialize(): call_deferred("execute")

func execute():
	root.size = Vector2i(1440,900)
	var db = DB.new()
	var body = Body.new(db)
	body.step(1.0,Vector2.UP,false)
	check(body.velocity.is_equal_approx(Vector2(0,-108)),"Source axis acceleration moves vertically from an east-facing start without a steering arc")
	body.step(0.1,Vector2.RIGHT,false)
	check(body.velocity.is_equal_approx(Vector2(10.8,-86.4)),"Changing input accelerates the new axis and brakes the released axis independently")
	body.step(0.5,Vector2.ZERO,false)
	check(body.velocity.is_zero_approx(),"Releasing both directions settles the source acceleration without coasting in the facing direction")
	body.reset()
	var battle = Battle.new(db,body)
	body.hq_weapon = db.named("Core_Gun_Gatling").id
	battle.step(0.001,Vector2(1000,0),true)
	check(float(body.parts[0].recoil)>0 and int(body.parts[0].barrel_index)==1,"Firing starts weapon recoil and advances the muzzle index")
	check(battle.effects.any(func(e):return e.kind=="muzzle"),"Every projectile shot produces a visible muzzle event")
	battle.audio_events.clear()
	for radius in [24.0,48.0,49.0,96.0,97.0]: battle.explosion(Vector2.ZERO,radius)
	check(battle.audio_events.map(func(e):return e.type)==[20,20,21,21,22],"Explosion recordings use the source tiny, small and big radius boundaries")
	Art.prepare()
	check(Art.BODY_SIZE.x==Art.BODY_SIZE.y,"Turret-bearing shell is drawn square")
	check(Art.pieces.upper_jaw.region!=Art.pieces.lower_jaw.region and Art.pieces.head.region!=Art.pieces.upper_jaw.region,"Head and both jaw sprites are independent atlas regions")
	check(absf(Art.jaw_angle(0.04,1,-1)-Art.jaw_angle(0.22,1,-1))>0.1,"Mouth animation changes while the head and body pose remain fixed")
	check(is_equal_approx(Art.jaw_angle(0.04,1,-1),-Art.jaw_angle(0.04,1,1)),"Jaw pivots open in opposite directions")
	var fx = load("res://scripts/particle_effects.gd").new()
	root.add_child(fx)
	fx.setup(db)
	check(fx.definitions["303"][0]._material.get_shader_parameter("single_channel")==true,"Explosion star reads its source red-channel coverage")
	check(fx.definitions["303"][1]._material.get_shader_parameter("single_channel")==true,"Stretched explosion sparks also read red-channel coverage")
	check(fx.definitions["303"][4]._material.get_shader_parameter("frames")==Vector2(2,2),"Smoke retains its 2 by 2 animation sheet")
	check(fx.definitions["302"][0]._material.get_shader_parameter("blue_ink")==false and fx.definitions["flame"][0]._material.get_shader_parameter("blue_ink")==false,"EMP and flame abilities retain their source colors")
	check(fx.definitions["307"][0]._material.get_shader_parameter("blue_ink")==false and fx.definitions["303"][0]._material.get_shader_parameter("blue_ink")==true,"Shield feedback is colored while general impact explosions retain blue ink")
	if DisplayServer.get_name()!="headless": await check_particle_pixels(fx)
	fx.queue_free()
	await process_frame
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed),"renderer":DisplayServer.get_name()}
	var report_path="res://artifacts/blue-ink-regression-report.json" if DisplayServer.get_name()=="headless" else "res://artifacts/blue-ink-regression-render-report.json"
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)

func check_particle_pixels(fx):
	var viewport=SubViewport.new()
	viewport.size=Vector2i(320,240)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var paper=ColorRect.new()
	paper.color=Ink.PAPER;paper.size=viewport.size;viewport.add_child(paper)
	var sprite=Sprite2D.new()
	sprite.texture=fx.definitions["303"][0]._texture
	sprite.material=fx.definitions["303"][0]._material
	sprite.position=Vector2(160,120)
	sprite.scale=Vector2(160,160)/sprite.texture.get_size()
	viewport.add_child(sprite)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result=viewport.get_texture().get_image()
	result.save_png("res://artifacts/blue-ink-particle-mask.png")
	var background=result.get_pixel(10,10)
	var clear_corners=true
	for point in [Vector2i(81,41),Vector2i(238,41),Vector2i(81,198),Vector2i(238,198)]:
		var sample=result.get_pixelv(point)
		clear_corners=clear_corners and Vector3(sample.r-background.r,sample.g-background.g,sample.b-background.b).length()<0.035
	check(clear_corners,"Rendered explosion-mask corners show the paper, with no black or blue rectangle")
	var ink_pixels=0
	for y in range(40,200,2):
		for x in range(80,240,2):
			var pixel=result.get_pixel(x,y)
			if pixel.b>pixel.r+0.12 and pixel.r<0.3: ink_pixels+=1
	check(ink_pixels>100,"The explosion mask produces visible blue ink around its paper flash")
	viewport.queue_free()
	await process_frame
