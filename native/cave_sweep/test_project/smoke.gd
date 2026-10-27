extends SceneTree

func _initialize() -> void:
	var sandbox := OS.get_environment("RBPEW_TEST_SANDBOX").replace("\\", "/").to_lower() + "/"
	var actual_user_dir := OS.get_user_data_dir().replace("\\", "/").to_lower() + "/"
	if sandbox == "/" or not actual_user_dir.begins_with(sandbox):
		push_error("Native smoke requires isolated user directory: %s" % actual_user_dir)
		quit(2)
		return
	print("TEST_USER_DIR=", OS.get_user_data_dir())
	var status := GDExtensionManager.load_extension("res://cave_sweep.gdextension")
	if status != GDExtensionManager.LOAD_STATUS_OK and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		push_error("Native smoke load failed: %s" % status)
		quit(1)
		return
	if not ClassDB.class_exists(&"CaveSweepKernel"):
		push_error("CaveSweepKernel class missing")
		quit(1)
		return
	var kernel: RefCounted = ClassDB.instantiate(&"CaveSweepKernel")
	# Horizontal edge, upward normal; moving circle hits its face at t=0.4.
	var edges := PackedFloat64Array([0, 0, 10, 0, 10, 0, 0, -1, 100, 0, 0, 10, 0])
	var query := PackedFloat64Array([5, -5, 0, 10, 1, 4, -6, 2, 12])
	var result: PackedFloat64Array = kernel.call(&"scan", edges, query)
	if result.size() != 2 or result[0] != 0.0 or result[1] != 0.4:
		push_error("Native smoke result: %s" % result)
		quit(1)
		return
	print("CAVE_SWEEP_SMOKE=" + JSON.stringify({"index": result[0], "time": result[1]}))
	# Boundary overlap retains Rect2's half-open upper border, the original
	# closest-point test, and an integer first-edge result.
	if not kernel.has_method(&"overlap"):
		push_error("Native overlap method missing");quit(1);return
	var overlap_cases=[
		[PackedFloat64Array([5,-.5,1]),0],
		[PackedFloat64Array([5,-1,1]),0],
		[PackedFloat64Array([5,1,1]),-1],
		[PackedFloat64Array([5,0,0]),-1]]
	for overlap_case in overlap_cases:
		var overlap_result=kernel.call(&"overlap",edges,overlap_case[0])
		if not overlap_result is int or overlap_result!=overlap_case[1]:
			push_error("Native overlap result: %s expected %s"%[overlap_result,overlap_case[1]]);quit(1);return
	print("CAVE_SWEEP_OVERLAP_SMOKE="+JSON.stringify({"cases":overlap_cases.size(),"passed":true}))
	var fixture_path := OS.get_environment("CAVE_SWEEP_FIXTURE")
	if not fixture_path.is_empty() and not _compare_fixture(kernel, fixture_path):
		kernel = null
		quit(1)
		return
	kernel = null
	quit(0)

func _compare_fixture(kernel: RefCounted, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open fixture: %s" % path)
		return false
	var fixture: Dictionary = file.get_var()
	file.close()
	var cases := 0
	var mismatches := 0
	var max_time_error := 0.0
	for group: Dictionary in fixture["groups"]:
		var edges: PackedFloat64Array = group["edges"]
		var queries: Array = group["queries"]
		var expected: Array = group["expected"]
		for i in range(queries.size()):
			var actual: PackedFloat64Array = kernel.call(&"scan", edges, queries[i])
			var wanted: PackedFloat64Array = expected[i]
			cases += 1
			if actual.to_byte_array() != wanted.to_byte_array():
				mismatches += 1
				if actual.size() == 2 and is_finite(actual[1]) and is_finite(wanted[1]):
					max_time_error = maxf(max_time_error, absf(actual[1] - wanted[1]))
				if mismatches <= 8:
					print("CAVE_SWEEP_MISMATCH=" + JSON.stringify({"case": cases, "actual": Array(actual), "expected": Array(wanted)}))
	print("CAVE_SWEEP_FIXTURE=" + JSON.stringify({"cases": cases, "mismatches": mismatches, "max_time_error": max_time_error}))
	return cases == int(fixture["cases"]) and cases > 0 and mismatches == 0
