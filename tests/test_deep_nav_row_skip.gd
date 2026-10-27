extends SceneTree
const World=preload("res://scripts/cave_world.gd")
class ProbeWorld extends World:
	var calls:Array[Vector2i]=[]
	func nav_passable(id:Vector2i,_radius:int)->bool:
		calls.append(id);return id.x%9!=0 or id.y%9==0
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func prepared_world(skip:bool):
	var world=ProbeWorld.new();world.use_nav_row_skip=skip;world.reset_cave(true)
	var data=world.navigation(Vector2.ZERO,15)
	world.prepare_navigation(data,Vector2.ZERO,Vector2.ZERO,40)
	world.calls.clear()
	return world
func data_for(world):return world.nav_grids.values()[0]
func same_state(a,b)->bool:
	var da=data_for(a);var db=data_for(b)
	return da.filled==db.filled and da.prepared==db.prepared and da.preparing==db.preparing and a.calls==b.calls and a.nav_cells_left==b.nav_cells_left
func execute():
	var old=prepared_world(false);var current=prepared_world(true)
	check(data_for(old).filled.size()==6561 and same_state(old,current),"Warm preparation fills all 6561 cells with identical passability and call order")
	var rng=RandomNumberGenerator.new();rng.seed=20261026
	var same=true
	for i in 300:
		var origin=Vector2(rng.randi_range(-30,30),rng.randi_range(-30,30))*48
		var target=Vector2(rng.randi_range(-30,30),rng.randi_range(-30,30))*48
		var margin=rng.randi_range(0,40)
		var expected=old.prepare_navigation(data_for(old),origin,target,margin)
		var actual=current.prepare_navigation(data_for(current),origin,target,margin)
		same=same and expected==actual and same_state(old,current)
	check(same and current.nav_skipped_rows>0,"Changing and clipped rectangles skip filled rows without changing preparation keys or physical probes")
	for world in [old,current]:world.invalidate_navigation(Vector2(24,24),80)
	check(data_for(old).filled==data_for(current).filled,"Local excavation dirties exactly the same prepared cells")
	for budget in [0,1,2,7,48,48]:
		for world in [old,current]:world.begin_navigation_frame();world.nav_cells_left=budget
		var expected=old.prepare_navigation(data_for(old),Vector2.ZERO,Vector2.ZERO,40)
		var actual=current.prepare_navigation(data_for(current),Vector2.ZERO,Vector2.ZERO,40)
		same=same and expected==actual and same_state(old,current)
	check(same,"Partial-row resumes retain unfilled cell order, pending cursor and exact per-frame cell budget")
	for world in [old,current]:
		data_for(world).prepared.clear();data_for(world).preparing.clear()
		world.begin_navigation_frame();world.nav_prepare_us=World.NAV_PREPARE_USEC
	check(not old.prepare_navigation(data_for(old),Vector2.ZERO,Vector2.ZERO,40) and not current.prepare_navigation(data_for(current),Vector2.ZERO,Vector2.ZERO,40) and same_state(old,current),"An exhausted time budget returns before even fully prepared rows are skipped")
	for world in [old,current]:world.nav_budget_active=false
	old.prepare_navigation(data_for(old),Vector2.ZERO,Vector2.ZERO,40);current.prepare_navigation(data_for(current),Vector2.ZERO,Vector2.ZERO,40)
	check(data_for(old).grid.get_id_path(Vector2i(-25,-25),Vector2i(25,25))==data_for(current).grid.get_id_path(Vector2i(-25,-25),Vector2i(25,25)),"Ready-row metadata leaves the native AStar path unchanged after invalidation")
	# Same object can switch to the diagnostic legacy path and back safely.
	current.use_nav_row_skip=false;current.invalidate_navigation(Vector2(400,400),80);current.prepare_navigation(data_for(current),Vector2.ZERO,Vector2.ZERO,40)
	current.use_nav_row_skip=true;data_for(current).prepared.clear();current.prepare_navigation(data_for(current),Vector2.ZERO,Vector2.ZERO,40)
	check(data_for(current).ready_valid and data_for(current).ready_count==data_for(current).filled.size(),"Changing the A/B mode rebuilds stale readiness metadata from authoritative filled cells")
	var times:Array=[]
	for skip in [false,true,true,false]:
		var world=prepared_world(skip);var data=data_for(world)
		world.nav_scanned_cells=0;world.nav_skipped_cells=0;world.nav_skipped_rows=0
		var began=Time.get_ticks_usec()
		for repeat in 240:
			data.prepared.clear();world.prepare_navigation(data,Vector2.ZERO,Vector2.ZERO,40)
		times.append({"skip":skip,"total_ms":float(Time.get_ticks_usec()-began)/1000,"scanned_cells":world.nav_scanned_cells,"skipped_rows":world.nav_skipped_rows,"skipped_cells":world.nav_skipped_cells})
	var passed=checks.all(func(c):return c.passed)
	var report={"passed":passed,"checks":checks,"scope":"Filled-grid traversal micro-test only; same physical cell budget, no rendered FPS claim","abba":times}
	print(JSON.stringify(report));FileAccess.open("res://artifacts/deep-nav-row-skip-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if passed else 1)
