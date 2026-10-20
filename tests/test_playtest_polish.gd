extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Whip=preload("res://scripts/flame_whip.gd")
const Marker=preload("res://scripts/boss_direction.gd")
var checks:Array=[]
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func _initialize():
	var db=DB.new()
	for fps in [30,60,120]:
		for offset in [Vector2(3,0),Vector2(0,90),Vector2(-170,50),Vector2(270,-80)]:
			var body=Body.new(db);var battle=Battle.new(db,body)
			battle.drones.resize(1)
			var d=battle.drones[0];d.angle=PI;d.speed=300;d.docked=false;d.ping=0
			var drop={"position":offset,"value":5,"pack":false};battle.loot.append(drop)
			var carried=false
			for frame in fps*12:
				# Returning collector must intercept a moving home, too.
				body.parts[0].position=Vector2(frame*40.0/fps,0)
				battle.step_drones(1.0/fps)
				carried=carried or drop.get("carried",false)
				if drop.get("delivered",false):break
			check(carried and drop.get("delivered",false),"Collector arrives and returns without orbiting: %d FPS %s"%[fps,offset])
			for frame in fps:battle.step_drones(1.0/fps)
			check(not drop.has("reserved_by") and not drop.get("carried",false),"Delivered crystal is never re-reserved while waiting for run collection")
	var body=Body.new(db);var battle=Battle.new(db,body)
	var drop={"position":Vector2(100,0),"value":1,"pack":false};battle.loot.append(drop)
	for d in battle.drones:d.ping=0
	battle.step_drones(.01)
	var owners=battle.drones.filter(func(d):return not d.target.is_empty())
	check(owners.size()==1,"Only one collector reserves a crystal")
	if not owners.is_empty():
		battle.loot.clear();battle.step_drones(.01)
		check(owners[0].target.is_empty() and not drop.has("reserved_by"),"Disappeared crystal releases its reservation")
	var state={}
	var root=Vector2(40,50)
	var points:PackedVector2Array
	for i in 60:points=Whip.advance(state,root,Vector2.RIGHT,280,1.0/60)
	var old=points.duplicate()
	var curved=false
	for p in points:curved=curved or absf(p.y-root.y)>10
	check(points[0]==root and curved,"Continuous whip has an anchored root and a visibly curved body")
	for i in 12:points=Whip.advance(state,root+Vector2(i,0),Vector2.from_angle(i*.04),280,1.0/60)
	check(points[-1].distance_to(old[-1])>10,"Whip tip responds to turning with delayed flexible motion")
	var bounded=true
	var axis=Vector2.from_angle(11*.04);var anchor=root+Vector2(11,0)
	for p in points:
		var delta=p-anchor
		bounded=bounded and delta.dot(axis)>=-.01 and delta.dot(axis)<=280.01 and absf(delta.dot(axis.orthogonal()))<=delta.dot(axis)*.181+.01
	check(bounded,"Soft curve stays in the original damage corridor")
	for level in 4:check(Body.Flagella.fusion_count(level+1)==level*2,"Fusion adds two strands at every tier: "+str(level+1))
	for size in [Vector2(1280,720),Vector2(1440,900),Vector2(1920,1080)]:
		for axis_dir in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1),Vector2(-1,-1)]:
			var pose=Marker.layout(size,size*.5+axis_dir*9000)
			check(not pose.is_empty() and Rect2(Vector2.ZERO,size).has_point(pose.point) and not Rect2(size-Vector2(230,260),Vector2(230,260)).has_point(pose.point),"Boss pointer remains inside screen and outside radar: %s %s"%[size,axis_dir])
		check(Marker.layout(size,size*.5).is_empty(),"Onscreen boss does not get a redundant direction arrow")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/playtest-polish-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
