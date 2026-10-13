extends SceneTree
const FX=preload("res://scripts/insect_attack_fx.gd")
var checks:Array=[]
class Probe extends RefCounted:
	var calls=0
	var maximum_points=0
	func world(point:Vector2)->Vector2:return point
	func get_viewport_rect()->Rect2:return Rect2(0,0,1440,900)
	func draw_polyline(points:PackedVector2Array,_color:Color,_width:float,_aa:bool):
		calls+=1;maximum_points=maxi(maximum_points,points.size())
	func draw_circle(_at:Vector2,_radius:float,_color:Color,_filled:bool,_width:float,_aa:bool):calls+=1
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func execute():
	var finite=true
	for family in ["cannon","flak","missile","flame","emp","blackhole","sonic","tesla","gatling"]:
		for frame in range(600):
			var scale=FX.organ_scale(family,float(frame%31)/100,frame/60.0)
			finite=finite and scale.is_finite() and scale.x>0.83 and scale.x<1.17 and scale.y>0.87 and scale.y<1.13
	check(finite,"All organ deformation stays finite and restrained across firing cycles")
	check(FX.organ_scale("cannon",NAN,0)==Vector2.ONE and FX.organ_scale("emp",0,INF)==Vector2.ONE,"Invalid input safely returns undeformed art")
	var geometry_ok=true
	for kind in ["silk","tendril"]:
		for age in [0.0,0.15,0.6,1000.0]:
			for end in [Vector2(520,250),Vector2(200,250),Vector2(200,250.001)]:
				var points=FX.curve_points(Vector2(200,250),end,age,kind)
				geometry_ok=geometry_ok and points.size()==19 and points[0]==Vector2(200,250) and points[-1]==end
				for point in points:geometry_ok=geometry_ok and point.is_finite()
	check(geometry_ok,"Curves use 18 segments and exact finite endpoints, including zero-length tethers")
	check(FX.curve_points(Vector2(INF,0),Vector2.ZERO,0,"silk").is_empty(),"Nonfinite curve inputs are discarded")
	check(FX.control_alpha({"life":0,"duration":0.8})==0 and FX.control_alpha({"life":0.08,"duration":0.8})==0.5 and FX.control_alpha({"life":0.4,"duration":0.8})==1,"Terminal 160ms fade follows effect lifetime")
	check(FX.ownership_color("silk",true)!=FX.ownership_color("silk",false) and FX.ownership_color("tendril",true)!=FX.ownership_color("tendril",false),"Ownership colors distinguish silk and tendril hostility")
	var target={"position":Vector2(500,300),"radius":24,"hp":100}
	var event={"kind":"silk","target":target,"origin":Vector2(100,300),"duration":0.8,"life":0.6,"friendly":true}
	var controls:Array=[]
	for i in range(500):controls.append(event)
	var probe=Probe.new()
	FX.paint(probe,controls,1.0)
	check(probe.calls==32*14 and probe.maximum_points<=19,"Renderer caps 500 input events to 32 controls and 19 points per curve")
	check(target.position==Vector2(500,300) and target.hp==100 and event.life==0.6,"Rendering never mutates mechanics or target positions")
	probe.calls=0;event.life=0
	FX.paint(probe,controls,1.0)
	check(probe.calls==0,"Expired control events draw nothing")
	event.life=0.3;target.hp=0;FX.paint(probe,controls,1.0)
	check(probe.calls==0,"Dead targets have no lingering wraps")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/insect-attack-fx-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
