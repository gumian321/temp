extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/centipede.gd")
const Save = preload("res://scripts/save_store.gd")
const Battle = preload("res://scripts/combat.gd")
const Run = preload("res://scripts/run_state.gd")
var checks = 0
var failures: Array = []
func check(ok, message):
	checks += 1
	if not ok: failures.append(message); printerr(message)
func _initialize():
	var db = DB.new()
	var p = Body.new(db)
	var b = Battle.new(db,p)
	var save = Save.new(db)
	var run = Run.new(db,save,p,b,db.kind("Mission")[0],0)
	var map = run.map_director
	check(map.nodes.size()==16,"original 4×4 grid loads sixteen nodes")
	for type in [100,101,103,105]:
		var key = Vector2(type*100,1000)
		map.spawn_node(key,type)
		var node = map.nodes[key]
		check(not node.objectives.is_empty(),"source map event %d has destructible objectives"%type)
		if type in [101,103,105]: check(node.members.size()>node.objectives.size(),"event %d has source-positioned guards"%type)
		for uid in node.objectives: b.entity(uid).hp = 0
		map.last_grid = (p.head/(map.distance*48)).round()*map.distance
		map.step(0)
		check(map.destroyed_nodes.has(key),"event %d clearing remembered"%type)
		if type == 103: check(b.loot.filter(func(d): return d.pack).size()==2,"station callback drops source's two reward packs")
	var first_key = map.nodes.keys()[0]
	var old_type = map.event_type(first_key)
	p.head = Vector2(50000,50000)
	map.update_grid()
	check(map.nodes.size()==16,"map unloads old cells and loads next sixteen")
	p.head = Vector2.ZERO
	map.update_grid()
	check(map.event_type(first_key)==old_type,"revisited map cell retains cached event type")
	var report = {"checks":checks,"passed":checks-failures.size(),"failures":failures,"scope":"Source map grid, four event kinds, guard transforms, destruction persistence, station reward callback."}
	FileAccess.open("res://artifacts/map-test-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(1 if not failures.is_empty() else 0)
