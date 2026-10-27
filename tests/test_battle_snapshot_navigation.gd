extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Snapshot=preload("res://scripts/battle_snapshot.gd")
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func execute():
	var source=World.new();source.reset_cave(true)
	for radius in [24,80]:
		var data=source.navigation(Vector2.ZERO,radius)
		for y in range(-5,6):
			for x in range(-5,6):
				var id=Vector2i(x,y);var solid=x==0 and y!=3
				data.grid.set_point_solid(id,solid);data.filled[id]=true
				source.nav_open[Vector3i(x,y,data.radius)]=not solid
		data.prepared[Rect2i(-5,-5,11,11)]=true
		data.preparing[Rect2i(-8,-8,17,17)]=37
		source.rebuild_navigation_ready(data)
	source.nav_waiting={2:7,4:8};source.nav_ticket_serial=5;source.nav_ticket_head=2
	source.nav_frame=8;source.nav_clock_ms=12345.5;source.nav_serial=19
	source.nav_cells_left=23;source.nav_prepare_us=701;source.nav_replans=2;source.nav_budget_active=true
	var captured=Snapshot.navigation_state(source)
	check(Snapshot.pure(captured),"A partially prepared native navigation grid is saved without executable objects")
	var file=FileAccess.open("user://navigation-state.bin",FileAccess.WRITE);file.store_var(captured);file.close()
	file=FileAccess.open("user://navigation-state.bin",FileAccess.READ)
	var saved:Dictionary=file.get_var(false);file.close()
	var restored=World.new();restored.reset_cave(true)
	Snapshot.restore_navigation(restored,saved)
	check(restored.nav_open==source.nav_open and restored.nav_waiting==source.nav_waiting and restored.nav_ticket_serial==5 and restored.nav_ticket_head==2 and restored.nav_frame==8 and restored.nav_clock_ms==12345.5,"Pending actor FIFO, cached decisions and the logical navigation clock survive a binary round trip")
	check(restored.nav_cells_left==23 and restored.nav_prepare_us==701 and restored.nav_replans==2 and restored.nav_serial==19 and restored.nav_budget_active,"In-progress cell and time budgets survive restoration")
	var same=true;var paths=true;var points=0
	for bucket in source.nav_grids:
		var before:Dictionary=source.nav_grids[bucket];var after:Dictionary=restored.nav_grids[bucket]
		same=same and before.filled==after.filled and before.prepared==after.prepared and before.preparing==after.preparing and before.ready_rows==after.ready_rows
		for y in range(-40,41):
			for x in range(-40,41):
				var id=Vector2i(x,y);points+=1
				same=same and before.grid.is_point_solid(id)==after.grid.is_point_solid(id)
		var expected=before.grid.get_id_path(Vector2i(-4,-4),Vector2i(4,-4))
		paths=paths and not expected.is_empty() and expected==after.grid.get_id_path(Vector2i(-4,-4),Vector2i(4,-4))
	check(same and points==13122,"Every known and still-unknown AStar cell, preparation rectangle and resume cursor remains identical")
	check(paths,"Native pathfinding takes the same nontrivial detour through the saved opening")
	var passed=checks.all(func(c):return c.passed)
	FileAccess.open("res://artifacts/deep50-navigation-snapshot.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"cell_comparisons":points},"\t"))
	print(JSON.stringify({"passed":passed,"checks":checks.size(),"cell_comparisons":points}));quit(0 if passed else 1)
