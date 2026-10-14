extends SceneTree
var probe
func _initialize():
	if not preload("res://scripts/windows_review_probe.gd").isolated_profile():
		printerr("ERROR: Refusing review test outside isolated user directory")
		quit(2)
		return
	call_deferred("execute")
func execute():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	probe = preload("res://scripts/windows_review_probe.gd").new(game)
	probe.start()
