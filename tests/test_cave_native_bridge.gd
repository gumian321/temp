extends "res://tests/test_native_wide_near_contact_sweeps.gd"

func make_reference_world():
	var world=World.new();world.use_native_sweep=false;world.use_wide_near_contact=false
	return world

func make_candidate_world():
	var world=World.new()
	world.use_native_sweep=true;world.native_available=world.native_accel.ready()
	world.use_near_contact_probe=true;world.use_wide_near_contact=true
	return world

func candidate_stats(candidate)->Dictionary:return {"native":candidate.native_accel.stats()}
func candidate_valid(candidate)->bool:
	return candidate.native_available and candidate.native_accel.stats().queries>0 and candidate.near_contact_hits>0
func report_path()->String:return "res://artifacts/cave-native-bridge-check-20261027.json"
