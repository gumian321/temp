extends SceneTree
const TerrainPrediction=preload("res://tools/pilot_escape_terrain.gd")
var checks:Array=[]

class MockCorridor extends RefCounted:
	var enabled=true
	var filled:Dictionary={}
	var queries=0
	func solid(cell:Vector2i)->bool:
		queries+=1
		return filled.has(cell)

func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)

func choose(world,start:Vector2,headings:Array,threat:Vector2,distance:float,radius:float)->Vector2:
	# Minimal bounded mock of escape scoring: maximize separation after the
	# terrain-clipped prediction. Preserve input order on equal scores.
	var best:Vector2=headings[0];var best_score=-INF
	for heading:Vector2 in headings:
		var predicted=TerrainPrediction.predicted_position(world,start,heading,distance,radius)
		var score=predicted.distance_squared_to(threat)
		if score>best_score:best=heading;best_score=score
	return best

func _initialize():
	var world=MockCorridor.new();var start=Vector2(12,12)
	# Right is a dead end 72px ahead; down remains an open lane. Without the
	# rock clip, the right prediction would maximize distance from this threat.
	for y in range(-3,5):world.filled[Vector2i(3,y)]=true
	var headings=[Vector2.RIGHT,Vector2.DOWN]
	check((start+Vector2.RIGHT*240).distance_squared_to(Vector2(-100,12))>(start+Vector2.DOWN*240).distance_squared_to(Vector2(-100,12)),"Unclipped prediction incorrectly favors the dead end")
	check(choose(world,start,headings,Vector2(-100,12),240,8)==Vector2.DOWN,"Terrain-clipped prediction chooses the open lane over a dead end")
	var reach=TerrainPrediction.reachable_distance(world,start,Vector2.RIGHT,240,8)
	check(reach==46,"Prediction stops before the first sampled rock with a 2px skin")
	check(TerrainPrediction.reachable_distance(world,start,Vector2.DOWN,240,8)==240,"Open corridor retains its complete prediction distance")
	# The centerline is clear, but the right hull footprint clips a side wall.
	var narrow=MockCorridor.new();narrow.filled[Vector2i(2,1)]=true
	check(TerrainPrediction.reachable_distance(narrow,start,Vector2.RIGHT,144,16)==22,"A perpendicular hull sample detects a narrow side obstruction")
	# All candidates blocked: return zero terrain reach and keep deterministic
	# candidate order. The production caller must retain its old fallback and
	# normal mining controls; this helper does not invent a new movement rule.
	var closed=MockCorridor.new()
	for cell in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:closed.filled[cell]=true
	var closed_headings=[Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]
	var zero=true
	for heading:Vector2 in closed_headings:zero=zero and TerrainPrediction.reachable_distance(closed,start,heading,240,8)==0
	check(zero and choose(closed,start,closed_headings,Vector2(-100,12),240,8)==Vector2.RIGHT,"All-rock predictions preserve a deterministic fallback without simulating mining")
	world.enabled=false
	check(TerrainPrediction.reachable_distance(world,start,Vector2.RIGHT,240,8)==240,"Disabled cave preserves the original prediction distance")
	check(TerrainPrediction.reachable_distance(world,start,Vector2.ZERO,240,8)==240,"Disabled cave bypass remains independent of heading")
	var report={"passed":checks.all(func(item):return item.passed),"checks":checks,"scope":"Pure controller terrain prediction with bounded mock corridors. No production integration, health, damage, movement, digging, dt, or full-game/FPS claim."}
	print(JSON.stringify(report));quit(0 if report.passed else 1)
