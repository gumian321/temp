extends SceneTree
func _initialize():call_deferred("execute")
func execute():
	root.size=Vector2i(1440,900)
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	var probe=preload("res://scripts/cave_performance_probe.gd").new(game)
	set_meta("cave_native_performance",probe);probe.start()
