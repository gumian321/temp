extends SceneTree
const FX=preload("res://scripts/weapon_fx.gd")
const Trails=preload("res://scripts/projectile_trails.gd")
const Native=preload("res://scripts/native_visuals.gd")
const Splatter=preload("res://scripts/enemy_death_splatter.gd")
const Wet=preload("res://scripts/viscous_projectiles.gd")
const Layer=preload("res://scripts/attack_shader_layer.gd")
var checks:Array=[]
class Board extends Node2D:
	func world(p):return p
class Probe extends RefCounted:
	var textures:Array=[]
	var polygons:Array=[]
	func world(p):return p
	func get_viewport_rect():return Rect2(0,0,1440,900)
	func draw_set_transform(_at,_angle=0):pass
	func draw_texture_rect(texture,_rect,_tile,_color=Color.WHITE):textures.append(texture)
	func draw_colored_polygon(points,_color):polygons.append(points)
	func draw_polyline(_p,_c,_w=1,_a=false):pass
	func draw_line(_a,_b,_c,_w=1,_aa=false):pass
	func draw_circle(_p,_r,_c,_filled=true,_w=-1,_aa=false):pass
	func draw_arc(_a,_b,_c,_d,_e,_f,_g,_h=false):pass
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func _initialize():call_deferred("run")
func run():
	var fx=FX.new()
	for key in ["tesla","rail","sonic"]:
		for friendly in [true,false]:
			var effect={"kind":"chain","fx_family":key,"friendly":friendly,"position":Vector2(100,150),"end":Vector2(500,150),"life":.2,"fx_duration":.32}
			var before=effect.duplicate(true);var probe=Probe.new();fx.clock=.1;fx.paint_effect(probe,effect,1)
			check(not Wet.texture("wet_trail") in probe.textures and probe.polygons.size()>0,"Beam uses a moving membrane without a stretched trail image: %s / %s"%[key,friendly])
			var shape:PackedVector2Array=probe.polygons[0]
			probe=Probe.new();fx.clock=.21;fx.paint_effect(probe,effect,1)
			check(shape!=probe.polygons[0] and effect==before,"Beam surface flows at fixed exact endpoints without simulation writes: %s / %s"%[key,friendly])
	var burst=Splatter.make_effect({"position":Vector2(400,300),"kind":"AISwarmingUnit","uid":17,"radius":24,"last_death_direction":Vector2.RIGHT})
	burst.life=burst.fx_duration-.15
	var before=burst.duplicate(true);var probe=Probe.new();Splatter.paint(probe,burst,1.0)
	check(not Wet.texture("wet_trail") in probe.textures and not Wet.texture("mucus") in probe.textures and probe.polygons.size()==6,"Death pressure jets and flying droplet tails use six dynamic membranes with separate beads")
	check(burst==before,"Death membrane rendering preserves the immutable cleanup snapshot")
	var board=Board.new();root.add_child(board);var layer=Layer.new();layer.trace_commands=true;layer.attach(board);layer.begin_frame(.15)
	Splatter.paint(board,burst,1.0)
	check(layer.friendly_batches.gatling.batch.commands.filter(func(c):return c[0]==&"draw_triangle_array").size()==1,"All death jet and droplet strips combine into one native indexed submission")
	var native=Native.new()
	for kind in ["ProjectileDrone","EngineerDrone","Drone"]:
		var actor={"position":Vector2(180,180),"friendly":true,"data":{"class":kind}}
		Trails.advance_actors([actor],.02);actor.position+=Vector2(15,0);Trails.advance_actors([actor],.02)
		actor.position+=Vector2(0,15);Trails.advance_actors([actor],.02)
		var path=Trails.path(actor.flight_trail)
		check(Vector2(195,180) in path.points,"Drone trail retains the actual turn rather than stretching a segment texture: "+kind)
		var original=actor.duplicate(true);probe=Probe.new();native.trail(probe,actor,20,.2,1)
		check(probe.textures.is_empty() and probe.polygons.size()==1 and actor==original,"Drone rendering is texture-free and never records or changes simulation state: "+kind)
		actor.docked=true;Trails.advance_actors([actor],.02)
		check(not actor.has("flight_trail"),"Docked drone releases its flight history: "+kind)
	var effect={"position":Vector2(100,100),"end":Vector2(400,100),"life":.2,"friendly":false}
	before=effect.duplicate(true);probe=Probe.new();native.beam(probe,effect,.2,1)
	check(probe.textures.is_empty() and probe.polygons.size()==1 and effect==before,"Legacy native beam entry point also uses a flowing membrane without birth-time writes")
	var shots:Array=[]
	for i in Trails.MAX_TRACKED+10:shots.append({"position":Vector2(100,100),"previous":Vector2(90,100),"velocity":Vector2(600,0),"life":1.0,"age":.1,"fx_family":"gatling","friendly":true})
	var red={"position":Vector2(100,100),"previous":Vector2(90,100),"velocity":Vector2(600,0),"life":1.0,"age":.1,"fx_family":"gatling","friendly":false};shots.append(red)
	Trails.advance(shots,[],.02)
	check(red.has("projectile_trail") and shots.filter(func(s):return s.has("projectile_trail")).size()==Trails.MAX_TRACKED,"Dense friendly shots cannot consume the history slots needed by red incoming hazards")
	for i in 20:
		red.previous=red.position;red.position+=Vector2(10,0);red.age+=1.0/60;Trails.advance([red],[],1.0/60)
	for zoom in [.4,1.0,1.6]:
		var path=Trails.path(red.projectile_trail,42.0/zoom)
		check(path.length*zoom>=40 and path.length*zoom<=42.1,"Red incoming trail remains visibly extended beyond the body at zoom %.1f"%zoom)
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/all-dynamic-trails-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
