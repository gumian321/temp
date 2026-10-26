extends SceneTree
const Probe=preload("res://scripts/dense_pressure_probe.gd")
func _initialize():call_deferred("execute")
func execute():
 var game=Probe.ProfileGame.new();root.add_child(game);await process_frame
 var probe=Probe.new(game);set_meta("dense_pressure_probe",probe);probe.start()
