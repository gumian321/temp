extends "res://tests/test_actor_flight_batch.gd"
func _initialize():
	OS.set_environment("RBPEW_PROTO_ACTOR_PRODUCTION","1")
	super._initialize()
