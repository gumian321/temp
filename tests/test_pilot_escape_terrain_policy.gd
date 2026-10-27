extends SceneTree
const Pilot=preload("res://scripts/conservative_pilot.gd")
var checks:Array=[]
var comparisons=0

class MockCorridor extends RefCounted:
	var enabled=true
	var filled:Dictionary={}
	func solid(cell:Vector2i)->bool:return filled.has(cell)
	func nearby(_area:Rect2)->Array:return []

class ExposureTrace extends "res://scripts/conservative_pilot.gd":
	var all_threats:Array=[]
	var differences=0
	var sample_comparisons=0
	var smallest_list=2147483647
	func pilot_exposure(point:Vector2,threats:Array)->Vector3:
		var actual=super.pilot_exposure(point,threats)
		var expected=super.pilot_exposure(point,all_threats)
		if actual!=expected:differences+=1
		sample_comparisons+=1;smallest_list=mini(smallest_list,threats.size())
		return actual

func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)

func threat(at:Vector2,soft:float=2200.0)->Dictionary:
	return {"position":at,"radius":soft,"soft":soft,"weight":6.0,"boss":true}

func _initialize():
	var pilot=Pilot.new();var world=MockCorridor.new();var start=Vector2(12,12)
	# A real policy call sees a wall directly away from the boss. Vertical
	# lanes are open and should outrank an impossible escape through rock.
	for y in range(-30,31):world.filled[Vector2i(3,y)]=true
	var boss=threat(Vector2(-1000,12))
	var direction=pilot.pilot_escape_direction(start,Vector2.RIGHT,[boss],[],200,world,8)
	check(absf(direction.y)>.9,"Actual pilot escape method chooses an open vertical lane over the right dead end")
	check(pilot.pilot_escape_direction(start,Vector2.RIGHT,[],[],200,world,8)==Vector2.RIGHT,"Safe actual pilot method retains rightward mining input")
	var rng=RandomNumberGenerator.new();rng.seed=20261027
	var trace=ExposureTrace.new();var all:Array=[]
	for i in 120:
		var at=Vector2(rng.randf_range(-15000,15000),rng.randf_range(-15000,15000))
		var soft=rng.randf_range(100,5000)
		all.append(threat(at,soft))
	# Include exact expanded-disk boundaries and nearby positions. Every real
	# policy sample is compared against the complete original threat list.
	for distance in [2699.999,2700.0,2707.999,2708.0,2708.001,2708.01]:all.append(threat(start+Vector2.RIGHT*distance))
	all.append(threat(Vector2(-1000,12)))
	trace.all_threats=all
	for i in 12:
		trace.pilot_escape_direction(start,Vector2.from_angle(TAU*i/12),all,[],200,world,8)
	comparisons=trace.sample_comparisons
	check(trace.differences==0,"Full and decision-filtered exposure Vector3 match exactly at every actual future sample")
	check(trace.smallest_list<all.size(),"Actual policy invokes future exposure with a smaller ordered threat list")
	# A large/nonfinite travel or an out-of-bounds head retains the full list.
	for probe in [[Vector2(40000,0),200.0],[Vector2.ZERO,2000.0]]:
		trace.smallest_list=2147483647
		trace.pilot_escape_direction(probe[0],Vector2.RIGHT,all,[],probe[1],world,8)
		check(trace.smallest_list==all.size(),"Unusual prediction domain preserves the original full threat list")
	pilot.free();trace.free()
	var report={"passed":checks.all(func(item):return item.passed),"checks":checks,"actual_exposure_comparisons":comparisons,"scope":"Actual conservative pilot escape method with mock terrain, ordinary mining input retained, exact full-vs-filtered exposure at random and boundary future samples. No movement, health, damage, entity or dt override; no FPS claim."}
	print(JSON.stringify(report));quit(0 if report.passed else 1)
