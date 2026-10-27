extends "res://tools/check_near_contact_sweeps.gd"
const NativeCandidate=preload("res://tools/native_near_contact_world.gd")
func make_candidate_world():return NativeCandidate.new()
func candidate_stats(candidate)->Dictionary:return {"native":candidate.native_stats()}
func candidate_valid(candidate)->bool:
	return candidate.native_kernel!=null and candidate.native_near_contact_queries>0 and candidate.near_contact_hits>0
func report_path()->String:return "res://artifacts/native-near-contact-sweep-check-20261027.json"
