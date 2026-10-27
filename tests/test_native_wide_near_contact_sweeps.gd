extends "res://tools/check_near_contact_sweeps.gd"
const NativeWideCandidate=preload("res://tools/native_wide_near_contact_world.gd")
func make_candidate_world():return NativeWideCandidate.new()
func candidate_stats(candidate)->Dictionary:return {"native":candidate.native_stats()}
func candidate_valid(candidate)->bool:
	return candidate.native_kernel!=null and candidate.native_near_contact_queries>0 and candidate.wide_near_contact_probes>0 and candidate.wide_near_contact_hits>0
func test_radii()->Array:return [67.5,96.0,108.723,108.723000001,202.798,287.963623046875,512.0]
func extra_starts()->Array:
	return [Vector2(-8400,-3113),Vector2(12000,14000),Vector2(-16000,10000),Vector2(31000,-31000)]
func report_path()->String:return "res://artifacts/native-wide-near-contact-sweep-check-20261027.json"
