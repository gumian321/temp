extends SceneTree
const Trails=preload("res://scripts/projectile_trails.gd")
const Motion=preload("res://scripts/viscous_projectile_motion.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const Layer=preload("res://scripts/attack_shader_layer.gd")
const Wet=preload("res://scripts/viscous_projectiles.gd")
var checks:Array=[]
class Board extends Node2D:
	func world(at):return at
class Probe extends RefCounted:
	var polygons:Array=[]
	var textures=0
	func world(at):return at
	func get_viewport_rect():return Rect2(0,0,1440,900)
	func draw_set_transform(_at,_angle=0):pass
	func draw_colored_polygon(points,_color):polygons.append(points)
	func draw_texture_rect(_a,_b,_c,_d):textures+=1
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func _initialize():call_deferred("run")
func shot_at(at:Vector2,key:String="rocket")->Dictionary:
	var shot={"position":at,"previous":at,"origin":at,"age":0.0,"life":2.0,"velocity":Vector2(300,0),"fx_family":key,"friendly":true,"radius":4.0,"damage":7.0,"shield_damage":3.0,"pierce":1}
	Motion.initialize(shot,3)
	return shot
func move(shot:Dictionary,to:Vector2,remnants:Array,dt:float=1.0/60.0):
	shot.previous=shot.position;shot.position=to;shot.age+=dt
	Trails.advance([shot],remnants,dt)
func run():
	var remnants:Array=[];var shot=shot_at(Vector2(280,200))
	move(shot,Vector2(300,200),remnants);move(shot,Vector2(320,200),remnants);move(shot,Vector2(320,220),remnants)
	var path=Trails.path(shot.projectile_trail)
	check(path.points[0]==shot.position and Vector2(320,200) in path.points and Vector2(300,200) in path.points,"Turn retains actual past positions instead of rotating the whole trail behind velocity")
	var before=shot.duplicate(true);var probe=Probe.new();var fx=FX.new()
	fx.paint_projectile(probe,shot,.1,1)
	var first:PackedVector2Array=probe.polygons[0]
	probe=Probe.new();fx.paint_projectile(probe,shot,.2,1)
	check(first!=probe.polygons[0] and probe.textures==1,"Independent tail deforms over time while the body is drawn exactly once")
	check(shot==before,"Tail rendering never writes to shot position, velocity, damage, collision radius or history")
	var stopped=shot.duplicate(true)
	for frame in 20:
		stopped.previous=stopped.position;stopped.age+=1.0/60.0;Trails.advance([stopped],[],1.0/60.0)
	check(Trails.path(stopped.projectile_trail).length==0.0,"A stationary projectile stops emitting and its old trail disappears completely")
	var clone=shot.duplicate(true);Motion.initialize(clone,4)
	check(not clone.has("projectile_trail"),"Chain and shrapnel initialization discards the parent flight history")
	for hz in [30,60,120,600]:
		shot=shot_at(Vector2.ZERO)
		for i in hz:
			shot.previous=shot.position;shot.age+=1.0/hz
			shot.velocity=Vector2.from_angle(sin(shot.age*2.0)*.7)*600
			Motion.advance(shot,1.0/hz);Trails.advance([shot],remnants,1.0/hz)
		path=Trails.path(shot.projectile_trail)
		check(shot.projectile_trail.count<=Trails.MAX_POINTS and path.length<=Trails.MAX_DISTANCE+.01 and path.ages[-1]<=Trails.RETENTION+.001,"History has bounded point count, arc length and age at %d Hz"%hz)
		check(shot.damage==7.0 and shot.shield_damage==3.0 and shot.radius==4.0 and shot.pierce==1,"Visual recording preserves damage and collision semantics at %d Hz"%hz)
	shot.life=0;shot.trail_contact=shot.position-Vector2(4,0)
	Trails.advance([shot],remnants,1.0/60.0)
	check(remnants.size()==1 and remnants[0].position==shot.trail_contact and not shot.has("projectile_trail"),"Expired body leaves an independent remnant ending at the impact surface")
	var old_head=remnants[0].position;var old_life=remnants[0].life
	shot.position+=Vector2(50,0);Trails.advance([],remnants,.04)
	check(remnants[0].position==old_head and remnants[0].life<old_life,"Detached trail stays in world space and fades after the projectile is gone")
	Trails.advance([],remnants,.3)
	check(remnants.is_empty(),"Remnants release after their short fade without spawning new effects")
	var db=load("res://scripts/source_db.gd").new()
	var body=load("res://scripts/grid_centipede.gd").new(db)
	var battle=load("res://scripts/combat.gd").new(db,body)
	var target=battle.spawn(db.pool["250"],Vector2(110,0))
	target.guns=[];target.hp=1000;target.max_hp=1000;target.kind="ContainerObject";target.unit={};target.radius=22.0
	shot=shot_at(Vector2.ZERO,"cannon");shot.data={"class":"BasicProjectile"};shot.hit=[];shot.chips={};shot.velocity=Vector2(600,0)
	battle.bullets.append(shot)
	for frame in 30:
		battle.step(1.0/60.0,Vector2(1000,0),false,false)
		if battle.bullets.is_empty():break
	check(battle.bullets.is_empty() and target.hp==993.0 and battle.hit_count==1,"Actual combat collision still deals one original hit and recycles the body")
	check(battle.projectile_trails.size()==1 and absf(Vector2(battle.projectile_trails[0].position).distance_to(target.position)-target.radius)<.01,"Actual combat remnant terminates at the swept surface contact")
	battle.projectile_trails.clear()
	shot=shot_at(Vector2.ZERO,"cannon");shot.data={"class":"BasicProjectile"};shot.hit=[];shot.chips={};shot.velocity=Vector2(600,0);shot.pierce=3;shot.life=.3
	battle.bullets.append(shot)
	for frame in 30:
		battle.step(1.0/60.0,Vector2(1000,0),false,false)
		if battle.bullets.is_empty():break
	check(battle.projectile_trails.size()==1 and battle.projectile_trails[0].position==shot.position and shot.position.x>150,"Piercing round expiring later cannot snap its remnant back to an earlier contact")
	var dense:Array=[]
	for i in 900:
		var s=shot_at(Vector2(100,100));s.position+=Vector2(20,0);s.life=0;dense.append(s)
	Trails.advance(dense,remnants,1.0/60.0)
	check(remnants.size()==Trails.MAX_REMNANTS and dense[Trails.MAX_TRACKED].get("projectile_trail",{}).is_empty(),"Dense bursts obey both the global history cap and remnant cap")
	var board=Board.new();root.add_child(board);var layer=Layer.new();layer.trace_commands=true;layer.attach(board);layer.begin_frame(.3)
	shot=shot_at(Vector2(280,200));move(shot,Vector2(310,200),[],1.0/60.0);move(shot,Vector2(320,220),[],1.0/60.0)
	Trails.paint_shot(Layer.route(board,"rocket"),shot,1.0,.3)
	check(layer.stats().commands==1 and layer.friendly_batches.rocket.batch.commands[0][0]==&"draw_triangle_array","All taper, fade and pigment bands use one indexed native strip with no per-shot nodes")
	layer.begin_frame(.4);fx.draw_count=FX.MAX_DETAILED_TRAILS
	fx.paint_projectile(board,shot,.4,1.0)
	check(layer.friendly_batches.rocket.batch.commands.any(func(command):return command[0]==&"draw_polyline_colors"),"Dense friendly volleys retain a curved fading trail after the detailed strip budget")
	for i in Trails.MAX_TRACKED+Trails.MAX_REMNANTS+8:
		var temporary=shot_at(Vector2(280,200));move(temporary,Vector2(310,200),[])
		Trails.paint_shot(Layer.route(board,"rocket"),temporary,1.0,.4)
	check(Trails.mesh_cache.size()<=Trails.MAX_TRACKED+Trails.MAX_REMNANTS,"Native strip cache stays bounded across many newly fired shots")
	for asset_path in [Wet.BODY_ATLAS_PATH,Wet.SPECIAL_BODY_ATLAS_PATH]:
		var config=ConfigFile.new()
		check(config.load(asset_path+".import")==OK and bool(config.get_value("params","mipmaps/generate",false)),"Standalone body import retains mipmaps: "+asset_path.get_file())
	for key in Wet.BODY_REGIONS:
		check(Wet.texture(key).atlas==Wet.body_atlas and Wet.texture(key).atlas!=Wet.texture("wet_trail").atlas,"Closed standalone body is separate from legacy impact/beam art: "+key)
	for key in Wet.SPECIAL_BODY_KEYS:
		var texture=Wet.texture(key)
		check(texture.atlas==Wet.special_body_atlas and texture.atlas!=Wet.texture("wet_trail").atlas,"Special spore projectile uses a closed body without baked feelers: "+key)
		var image=texture.get_image();var edge=0.0
		for x in image.get_width():edge=maxf(edge,maxf(image.get_pixel(x,0).a,image.get_pixel(x,image.get_height()-1).a))
		for y in image.get_height():edge=maxf(edge,maxf(image.get_pixel(0,y).a,image.get_pixel(image.get_width()-1,y).a))
		check(edge<.02,"Special body crop preserves the entire silhouette with transparent margins: "+key)
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/projectile-trails-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
