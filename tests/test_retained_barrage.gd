extends SceneTree
const Layers=preload("res://scripts/attack_shader_layer.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const Trails=preload("res://scripts/projectile_trails.gd")
const FAMILIES=["gatling","shotgun","cannon","flak","rocket","nuke","emp","blackhole","sonic"]
var checks:Array=[]
class Board extends Node2D:
	var layer=Layers.new()
	var fx=FX.new()
	var shots:Array=[]
	var clock=.4
	var zoom=1.0
	var retained=true
	func _ready():layer.attach(self)
	func world(at):return at*zoom+get_viewport_rect().size*.5
	func _draw():
		draw_rect(get_viewport_rect(),Color("383836"))
		layer.use_retained_projectiles=retained;layer.use_muzzle_batch=retained;layer.begin_frame(clock)
		layer.batch_muzzles_this_frame=retained
		fx.draw_count=0
		for shot in shots:
			if shot.friendly:fx.paint_projectile(self,shot,clock,zoom)
		for i in mini(12,shots.size()):
			fx.paint_effect(self,{"kind":"muzzle","fx_family":"gatling","position":shots[i].position,"direction":Vector2.RIGHT,"life":.08,"fx_duration":.15,"radius":4,"friendly":true},zoom)
		for shot in shots:
			if not shot.friendly:fx.paint_projectile(self,shot,clock,zoom)
		layer.end_frame()
func check(value:bool,message:String):
	checks.append({"passed":value,"name":message})
	if not value:push_error(message)
func _initialize():call_deferred("execute")
func picture(board:Board)->Image:
	board.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func execute():
	if DisplayServer.get_name()=="headless":push_error("Retained barrage check requires --render");quit(1);return
	root.size=Vector2i(1440,900)
	var board=Board.new();root.add_child(board)
	for i in 240:
		var base=Vector2(-600+i%15*84,-310+i/15*41)
		var shot={"position":base,"previous":base-Vector2(6,0),"origin":base-Vector2(70,0),"velocity":Vector2.from_angle(i*.37)*600,"radius":4.0+float(i%3),"friendly":i%2==0,"fx_family":FAMILIES[i%FAMILIES.size()],"data":{},"age":.2}
		var state=Trails.make_state(shot,0)
		for sample in 10:
			var point=base-Vector2(54-sample*6,sin(sample*.5+i)*8)
			Trails.record(state,point,sample/60.0)
		Trails.record(state,base,.2);shot.projectile_trail=state;board.shots.append(shot)
	var before=board.shots.duplicate(true);var comparisons:Array=[]
	for zoom in [.5,1.0,1.65]:
		board.zoom=zoom;board.retained=false
		var reference=await picture(board)
		board.retained=true
		var actual=await picture(board)
		var a=reference.get_data();var b=actual.get_data();var error=0;var different=0
		for i in a.size():
			var difference=absi(int(a[i])-int(b[i]));error+=difference
			if difference>24:different+=1
		var mean=float(error)/a.size();var fraction=float(different)/a.size()
		comparisons.append({"zoom":zoom,"mean_channel_error_255":mean,"channels_over_24_fraction":fraction})
		check(mean<.3 and fraction<.002,"240 curved projectiles preserve art, membranes, AA and ordering at zoom "+str(zoom))
		if zoom==1.0:
			reference.save_png("res://artifacts/barrage-legacy-dense60.png");actual.save_png("res://artifacts/barrage-retained-dense60.png")
	check(before==board.shots,"Rendering retains every simulation field and trail history")
	var builds=board.layer.projectile_geometry_builds
	for frame in 8:await picture(board)
	check(builds==board.layer.projectile_geometry_builds,"Stable poses reuse body commands and trail surfaces without rebuilding")
	board.shots.clear();await picture(board);await picture(board)
	var state=board.layer.stats()
	check(state.retained_projectiles==0,"Clearing bullets hides and releases all active retained drawings")
	check(state.pooled_projectiles<=96,"All drawing reuse pools stay bounded")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"comparisons":comparisons,"cache_stats":state}
	FileAccess.open("res://artifacts/retained-barrage-dense60.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	board.queue_free();await process_frame;quit(0 if report.passed else 1)
