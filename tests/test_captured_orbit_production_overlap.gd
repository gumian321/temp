extends "res://tests/test_captured_orbit_production_native.gd"
var overlap_world

func make_fixture(db,snapshot:Dictionary,prototype:bool)->Dictionary:
	var fixture=super.make_fixture(db,snapshot,prototype)
	fixture.world.use_native_overlap=prototype
	if prototype:overlap_world=fixture.world
	return fixture

func execute():
	await super.execute()
	var stats=overlap_world.native_accel.stats() if overlap_world!=null else {}
	var exercised=int(stats.get("overlapQueries",0))==0
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/captured-orbit-near-contact-report.json"))
	source.passed=bool(source.passed) and exercised
	source.native=stats
	source.checks.append({"label":"Radius-15 captured map movement preserves the original boundary-overlap path","passed":exercised})
	FileAccess.open("res://artifacts/captured-production-overlap-report.json",FileAccess.WRITE).store_string(JSON.stringify(source,"\t"))
	if not exercised:push_error("Small captured map guards unexpectedly entered the large-radius native kernel")
	print(JSON.stringify(source));quit(0 if source.passed else 1)
