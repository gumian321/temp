extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Escort=preload("res://scripts/cave_escort.gd")
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Run=preload("res://scripts/run_state.gd")
const Save=preload("res://scripts/save_store.gd")
var checks:Array=[]

class Tunnel extends World:
	var navigation_calls=0
	func original_solid(cell:Vector2i)->bool:
		var at=(Vector2(cell)+Vector2.ONE*.5)*CELL
		return not ((at/Vector2(310,220)).length()<1 or segment_distance(at,Vector2.ZERO,Vector2(360,0))<70 or segment_distance(at,Vector2(360,0),Vector2(360,420))<70 or segment_distance(at,Vector2(360,420),Vector2(1000,420))<70)
	func nearby(_area:Rect2)->Array:return []
	func direction(_origin:Vector2,_target:Vector2,_radius:float,_memory:Dictionary)->Vector2:
		navigation_calls+=1;return Vector2.ZERO

func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func _initialize():call_deferred("execute")
func execute():
	var db=DB.new();var save=Save.new(db);save.path="user://escort-fixture.json";save.fresh()
	var mission:Dictionary={}
	for candidate in db.kind("Mission"):
		for c in db.prefabs[candidate.MissionsObjectiveList[0].objectivePrefab].components:
			if c.get("class")=="GAModeManager":mission=candidate
	var setups=[]
	for difficulty in 3:
		var world=World.new();world.reset_cave(true)
		var body=Body.new(db);body.configure_character("centipede");body.terrain=world
		body.history=world.initial_trail(body.head,body.facing)
		var battle=Battle.new(db,body);var run=Run.new(db,save,body,battle,mission,difficulty,true)
		var director=run.director;var ships=director.living_objectives()
		check(director.cave_escort!=null and ships.size()==director.initial_objectives,"Difficulty %d retains the source convoy and uses individual cave hulls"%difficulty)
		check(director.fleet_radius<=30 and ships.all(func(e):return not world.blocked(e.position,e.radius)),"Difficulty %d spawns every convoy hull outside solid rock"%difficulty)
		check(director.fleet_position.distance_to(body.head)<director.fleet_data.disFromPlayerToMove*48,"Difficulty %d starts within the actual convoy's follow range"%difficulty)
		check(not world.blocked(director.fleet_goal,director.fleet_radius),"Difficulty %d has a physically accessible safe-zone footprint"%difficulty)
		var at:Vector2=director.fleet_position
		director.fleet_goal=body.head
		for frame in 120:
			director.step(1.0/60)
			if run.finished:break
		check(run.finished and run.won and at.distance_to(director.fleet_position)>20 and director.fleet_position.distance_to(director.fleet_goal)<24,"Difficulty %d physically delivers a living ship before awarding victory"%difficulty)
		setups.append({"difficulty":difficulty,"count":ships.size(),"radius":director.fleet_radius,"start":at,"delivered":director.fleet_position})
	var world=Tunnel.new();world.reset_cave(true)
	var body=Body.new(db);body.terrain=world
	var ships:Array=[]
	for i in 7:ships.append({"uid":i+1,"position":Vector2.ZERO,"radius":15.0,"hp":100.0,"max_hp":100.0,"angle":0.0})
	var escort=Escort.new();var goal=Vector2(900,420)
	escort.setup(world,body,ships,{"movingSpeed":1.5,"disFromPlayerToMove":12.5},goal)
	var original=ships.map(func(e):return e.position)
	body.head=Vector2(1000,0)
	for frame in 60:escort.step(1.0/60,ships,goal)
	check(escort.status=="far" and ships.map(func(e):return e.position)==original,"Leaving the escort radius stops the whole convoy")
	body.head=Vector2(360,300)
	for frame in 60:escort.step(1.0/60,ships,goal)
	check(escort.status=="regroup" and ships.map(func(e):return e.position)==original,"Returning across a solid corner cannot link a teleport shortcut")
	body.head=Vector2.ZERO
	for frame in 30:escort.step(1.0/60,ships,goal)
	check(escort.connected and escort.status=="ready","Returning along clear ground resumes guidance without input or navigation spam")
	var clear=true;var continuous=true;var max_points=0;var samples=[];var promoted=false
	for target in [Vector2(360,0),Vector2(360,420),goal]:
		for frame in 1200:
			body.head=world.move(body.head,body.head.move_toward(target,72.0/60),30)
			var before=ships.map(func(e):return e.position)
			escort.step(1.0/60,ships,goal)
			for i in ships.size():
				clear=clear and not world.blocked(ships[i].position,ships[i].radius)
				continuous=continuous and Vector2(before[i]).distance_to(ships[i].position)<=72.0/60+.01
			max_points=maxi(max_points,escort.route.size())
			if body.head.y>180 and not promoted:
				ships.remove_at(0);promoted=true
			if frame%120==0:samples.append({"player":body.head,"leader":ships[0].position,"state":escort.status})
			if body.head.distance_to(target)<.1:break
	for frame in 360:
		escort.step(1.0/60,ships,goal)
		clear=clear and ships.all(func(e):return not world.blocked(e.position,e.radius))
	check(clear,"Every surviving ship stays outside rock through two narrow right-angle turns")
	check(continuous,"Convoy hulls retain 72 px/s source speed without jumps, including leader death")
	check(Vector2(ships[0].position).distance_to(goal)<1 and promoted,"A promoted surviving leader reaches the actual goal while the player waits in the safe zone")
	check(max_points<2048 and world.navigation_calls==0,"Travelled-path following uses bounded history and no formation-sized A* queries")
	# A player circling in range for a long time cannot grow an unconsumed path
	# without limit, and reconnect must preserve the physical tail behind it.
	var capacity=Escort.new();var pack=[{"uid":1,"position":Vector2.ZERO,"radius":15.0,"hp":100.0,"max_hp":100.0,"angle":0.0}]
	body.head=Vector2.ZERO;capacity.setup(world,body,pack,{"movingSpeed":1.5,"disFromPlayerToMove":12.5},goal)
	for i in 5000:
		body.head=Vector2.from_angle(i*.15)*100
		capacity.step(0,pack,goal)
	check(capacity.route.size()-capacity.first<=capacity.MAX_POINTS,"An indefinitely circling player cannot allocate unbounded pending route points")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"setups":setups,"max_points":max_points,"samples":samples,"scope":"Real cave mission setup and physical delivery at all three difficulties; a narrow two-corner cave checks all hulls, speed, stop/rejoin, leader loss, bounded route memory and arrival."}
	FileAccess.open("res://artifacts/cave-escort-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
