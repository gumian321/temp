extends SceneTree
const Layers=preload("res://scripts/attack_shader_layer.gd")
const FX=preload("res://scripts/weapon_fx.gd")
var checks:Array=[]
class Board extends Node2D:
	var layer=Layers.new()
	var fx=FX.new()
	var batched=false
	var enabled=true
	func _ready():layer.attach(self)
	func world(at):return at
	func _draw():
		draw_rect(get_viewport_rect(),Color("383836"));layer.use_muzzle_batch=batched;layer.begin_frame(.7)
		layer.batch_muzzles_this_frame=batched
		if enabled:
			for row in 6:
				for col in 9:
					var age=[.0,.025,.06,.095,.12,.142][row]
					var family=["gatling","shotgun","cannon","flak","rocket","nuke","emp","blackhole","sonic"][col]
					fx.paint_effect(self,{"kind":"muzzle","fx_family":family,"position":Vector2(90+col*155,80+row*140),"direction":Vector2.from_angle(float(row%3-1)*.45),"life":.15-age,"fx_duration":.15,"radius":5,"friendly":col%2==0,"visual_scale":.55 if row==5 else 1.0},2.2)
		layer.end_frame()
func check(value:bool,message:String):
	checks.append({"passed":value,"name":message})
	if not value:push_error(message)
func _initialize():call_deferred("execute")
func picture(board)->Image:
	board.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw;return root.get_texture().get_image()
func execute():
	if DisplayServer.get_name()=="headless":push_error("Muzzle batch requires --render");quit(1);return
	root.size=Vector2i(1440,900);var board=Board.new();root.add_child(board)
	var reference=await picture(board);board.batched=true;var actual=await picture(board)
	var a=reference.get_data();var b=actual.get_data();var background=reference.get_pixel(1439,899)
	var active=0;var error=0;var different=0
	for y in 900:
		for x in 1440:
			var offset=(y*1440+x)*4
			var used=false
			for channel in 3:
				var base=int(round(background[channel]*255))
				used=used or absi(int(a[offset+channel])-base)>5 or absi(int(b[offset+channel])-base)>5
			if not used:continue
			for channel in 3:
				var distance=absi(int(a[offset+channel])-int(b[offset+channel]));error+=distance;active+=1
				if distance>24:different+=1
	var mean=float(error)/maxi(1,active);var fraction=float(different)/maxi(1,active)
	check(active>10000,"All 54 native/instanced discharges produce visible pixels")
	check(mean<2.5 and fraction<.01,"Magnified discharge art preserves tongues, pigment, halo, fade and shed husks")
	check(board.layer.muzzle_batch.count==54,"All discharge effects are instanced without dropping effects")
	reference.save_png("res://artifacts/muzzle-legacy-dense60.png");actual.save_png("res://artifacts/muzzle-batched-dense60.png")
	board.enabled=false;await picture(board)
	check(board.layer.muzzle_batch.batches.values().all(func(batch):return batch.instances.visible_instance_count==0),"Clearing effects hides every instanced discharge")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"active_rgb_channels":active,"mean_active_channel_error_255":mean,"active_channels_over_24_fraction":fraction}
	FileAccess.open("res://artifacts/muzzle-batch-dense60.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	board.queue_free();await process_frame;quit(0 if report.passed else 1)
