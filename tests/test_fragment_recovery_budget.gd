extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
func _initialize(): call_deferred("run")
func run():
	var db=DB.new()
	var body=Body.new(db)
	var gun=str(db.named("Core_Gun_Gatling").id)
	for i in 60: body.append_segment(gun)
	var removed: Array=[]
	for i in range(1,60,2):
		body.parts[i].hp=0
		removed.append(i)
	body.remove_destroyed_parts(removed)
	body.head=Vector2(100000,100000)
	var before=body.detached_fragments.map(func(g):return Vector2(g.poses[0].point))
	var start=Time.get_ticks_usec()
	for i in 10000: body.fragment_recovery.step(body,1.0/60.0)
	var usec=Time.get_ticks_usec()-start
	var frozen=true
	for i in before.size(): frozen=frozen and Vector2(body.detached_fragments[i].poses[0].point)==before[i]
	var passed=body.detached_fragments.size()==30 and body.detached_module_count()==30 and frozen and usec<50000000
	var report={"passed":passed,"groups":body.detached_fragments.size(),"modules":body.detached_module_count(),"steps":10000,"total_usec":usec,"mean_step_usec":float(usec)/10000,"dormant_positions_unchanged":frozen,"scope":"CPU fragment bookkeeping only; not renderer or FPS. 30 simultaneous groups is maximum from a 60-module alternating cut."}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var f=FileAccess.open("res://artifacts/fragment-budget-report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print(JSON.stringify(report));quit(0 if passed else 1)
