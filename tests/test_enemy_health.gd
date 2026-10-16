extends SceneTree
const Layer=preload("res://scripts/enemy_health_layer.gd")
var checks:Array=[]
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func _initialize():
	var e={"hp":100.0,"max_hp":100.0,"role":"swarm","kind":"AISwarmingUnit","radius":15.0}
	check(Layer.eligible(e),"Living hostile is eligible")
	for patch in [{"hp":0.0},{"max_hp":0.0},{"role":"friendly"},{"cloaked":true},{"warp":0.1}]:
		var hidden=e.duplicate();hidden.merge(patch,true)
		check(not Layer.eligible(hidden),"Hidden or invalid enemy excluded: "+str(patch))
	check(Layer.bar_size(e)==Vector2(48,6),"Ordinary bar has readable fixed screen dimensions")
	e.objective=true
	check(Layer.bar_size(e)==Vector2(64,7),"Objective bar is larger")
	e.kind="AIBossUnit"
	check(Layer.bar_size(e)==Vector2(88,8),"Boss bar is largest")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/enemy-health-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
