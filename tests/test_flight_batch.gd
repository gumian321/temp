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
	var optimized=true
	var overlay=true
	var only_trails=false
	func _ready():layer.attach(self)
	func world(at):return at*zoom+get_viewport_rect().size*.5
	func _draw():
		draw_rect(get_viewport_rect(),Color("383836"))
		layer.use_flight_batch=optimized;layer.begin_frame(clock)
		layer.batch_flights_this_frame=true;layer.batch_muzzles_this_frame=true
		fx.draw_count=0
		if only_trails:
			for shot in shots:Trails.paint(Layers.route(self,shot.fx_family,not shot.friendly),shot.projectile_trail,zoom,clock)
			layer.end_frame();return
		# Support cues precede live shots; remnants and impact effects follow.
		for i in mini(3,shots.size()):
			var painter=Layers.route(self,"gatling")
			Trails.paint(painter,shots[i].projectile_trail,zoom,clock)
			painter.draw_set_transform(Vector2.ZERO)
			painter.draw_circle(world(shots[i].position-Vector2(10,0)),30*zoom,Color(.7,.8,.6,.6),true,-1,true)
		for shot in shots:
			if shot.friendly:fx.paint_projectile(self,shot,clock,zoom)
		for i in mini(8,shots.size()):
			var shot=shots[i]
			Trails.paint(Layers.route(self,shot.fx_family,not shot.friendly),shot.projectile_trail,zoom,clock)
		if overlay:
			for i in mini(12,shots.size()):
				fx.paint_effect(self,{"kind":"muzzle","fx_family":shots[i].fx_family,"position":shots[i].position,"direction":Vector2.RIGHT,"life":.08,"fx_duration":.15,"radius":4,"friendly":i%2==0},zoom)
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
func compare(a:Image,b:Image)->Dictionary:
	var left=a.get_data();var right=b.get_data();var error=0;var over=0;var active=0;var active_error=0
	for pixel in left.size()/4:
		var start=pixel*4
		var visible=Vector3i(left[start],left[start+1],left[start+2])!=Vector3i(56,56,54) or Vector3i(right[start],right[start+1],right[start+2])!=Vector3i(56,56,54)
		for channel in 4:
			var d=absi(int(left[start+channel])-int(right[start+channel]));error+=d
			if d>24:over+=1
			if channel<3 and visible:active+=1;active_error+=d
	return {"mean_channel_error_255":float(error)/left.size(),"channels_over_24_fraction":float(over)/left.size(),"active_mean_channel_error_255":float(active_error)/maxi(1,active)}
func execute():
	if DisplayServer.get_name()=="headless":push_error("Flight batch check requires native renderer");quit(1);return
	root.size=Vector2i(1440,900)
	var board=Board.new();root.add_child(board)
	for i in 240:
		var base=Vector2(-600+i%15*84,-310+i/15*41)
		# Deliberate intersections exercise instance and phase ordering.
		if i<32:base=Vector2(-420+i%8*20,-120+i/8*16)
		var shot={"position":base,"previous":base-Vector2(6,0),"origin":base-Vector2(70,0),"velocity":Vector2.from_angle(i*.37)*600,"radius":4.0+float(i%3),"friendly":i%2==0,"fx_family":FAMILIES[i%FAMILIES.size()],"data":{},"age":.2}
		var state=Trails.make_state(shot,0)
		for sample in 10:
			Trails.record(state,base-Vector2(54-sample*6,sin(sample*.5+i)*8),sample/60.0)
		Trails.record(state,base,.2);shot.projectile_trail=state;board.shots.append(shot)
	var before=board.shots.duplicate(true);var comparisons=[]
	for zoom in [.5,1.0,1.65]:
		board.zoom=zoom;board.optimized=false;var reference=await picture(board)
		board.optimized=true;var actual=await picture(board)
		var difference=compare(reference,actual);difference.zoom=zoom;comparisons.append(difference)
		check(difference.mean_channel_error_255<.25 and difference.channels_over_24_fraction<.002,"240 mixed intersecting shots preserve original bodies, curves, material pigment and ordering at zoom "+str(zoom))
		if zoom==1.0:reference.save_png("res://artifacts/flight-reference-20261026.png");actual.save_png("res://artifacts/flight-batched-20261026.png")
	check(before==board.shots,"Instanced rendering does not write simulation or trail history")
	check(board.layer.flight_batch.submitted>0,"Dense fixture actually uses the instanced path")
	board.shots.clear();board.overlay=false;board.zoom=2.0
	for i in 27:
		var at=Vector2(-260+i%9*64,-100+i/9*100)
		var shot={"position":at,"origin":at,"velocity":Vector2.from_angle(i*.71)*600,"radius":4.0,"friendly":true,"fx_family":FAMILIES[i%FAMILIES.size()],"data":{},"age":0.0}
		shot.projectile_trail=Trails.make_state(shot,0);board.shots.append(shot)
	board.optimized=false;var bodies_reference=await picture(board)
	board.optimized=true;var bodies_actual=await picture(board)
	var bodies=compare(bodies_reference,bodies_actual)
	check(bodies.active_mean_channel_error_255<.5,"All 27 magnified illustrated bodies preserve their active pixels without relying on background dilution")
	board.shots.clear();await picture(board)
	# Reused data slots must not revive a retired body on a trail-only command.
	var shot={"position":Vector2.ZERO,"previous":Vector2(-40,0),"fx_family":"gatling","friendly":true}
	shot.projectile_trail=Trails.make_state(shot,0);Trails.record(shot.projectile_trail,Vector2.ZERO,.05)
	board.shots.append(shot);board.only_trails=true;board.optimized=false
	var remnant_reference=await picture(board);board.optimized=true;var remnant_actual=await picture(board)
	var remnant=compare(remnant_reference,remnant_actual)
	check(remnant.active_mean_channel_error_255<.5,"Recycled trail-only slots never resurrect a retired illustrated body")
	board.shots.clear();board.only_trails=false;board.overlay=false;board.zoom=.5
	for i in 900:
		var base=Vector2(-1200+i%45*54,-650+i/45*65)
		var incoming={"position":base,"previous":base-Vector2(20,0),"origin":base-Vector2(40,0),"velocity":Vector2.RIGHT*600,"radius":4.0,"friendly":false,"fx_family":"gatling","data":{},"age":.1}
		incoming.projectile_trail=Trails.make_state(incoming,0);Trails.record(incoming.projectile_trail,base,.05);board.shots.append(incoming)
	board.optimized=false;var overflow_reference=await picture(board)
	board.optimized=true;var overflow_actual=await picture(board)
	var overflow=compare(overflow_reference,overflow_actual)
	check(overflow.active_mean_channel_error_255<.5,"900 incoming shots overflow the instance capacity through the original path without disappearing")
	check(board.layer.flight_batch.entries.size()<=768 and board.layer.flight_batch.groups.size()<=96,"Flight data slots and material groups remain bounded under overflow")
	board.shots.clear();await picture(board);await picture(board)
	check(board.layer.flight_batch.entries.is_empty(),"Retired flight entries release every data slot")
	check(board.layer.flight_batch.groups.values().all(func(g):return g.instances.visible_instance_count==0),"Clearing the barrage hides all flight instances")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"comparisons":comparisons,"magnified_bodies":bodies,"remnant":remnant,"overflow":overflow}
	FileAccess.open("res://artifacts/flight-batch-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	board.queue_free();await process_frame;quit(0 if report.passed else 1)
