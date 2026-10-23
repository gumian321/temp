extends SceneTree
func _initialize(): call_deferred("execute")
func execute():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game); await process_frame
	var probe = preload("res://scripts/cave_playtest_probe.gd").new(game)
	probe.capture_directory = "res://artifacts"
	set_meta("cave_probe", probe)
	probe.start()
