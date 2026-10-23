extends SceneTree
const World=preload("res://scripts/cave_world.gd")
func _initialize():call_deferred("execute")
func execute():
	var world=World.new();world.reset_cave(true)
	var at=world.safe_position(Vector2(4800,-9200),15);var target=Vector2(300,0)
	var before=world.geometry.size();var memory={};var safe=true
	for i in 180:
		world.begin_navigation_frame()
		var intent=world.direction(at,target,15,memory)
		at=world.move(at,at+intent*1.6,15)
		safe=safe and not world.blocked(at,15)
	var extra=world.geometry.size()-before
	var bounded=extra<250 and world.nav_grids.is_empty() and memory.has("cave_far_direction")
	var near_plans=0
	for i in 120:
		world.begin_navigation_frame();world.direction(Vector2(630,0),target,15,memory);near_plans+=world.nav_replans
		if memory.has("cave_revision"):break
	var returned=near_plans>0 and memory.has("cave_revision")
	var report={"passed":safe and bounded and returned,"physical_clearance":safe,"new_geometry_cells":extra,"bounded_far_steering":bounded,"local_astar_reentry":returned}
	FileAccess.open("res://artifacts/cave-far-navigation-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
