extends "res://tests/test_actor_flight_batch.gd"
func _initialize():
	OS.set_environment("RBPEW_PROTO_ACTOR_CLAMP","1")
	OS.set_environment("RBPEW_PROTO_ACTOR_SCREEN","1")
	OS.set_environment("RBPEW_PROTO_ACTOR_LARGE_SPACE","1")
	OS.set_environment("RBPEW_PROTO_ACTOR_PRODUCTION","0")
	super._initialize()
