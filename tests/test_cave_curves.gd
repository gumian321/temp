extends SceneTree
const Contours = preload("res://scripts/cave_contour_mesh.gd")
var checks: Array = []
func check(value: bool, label: String):
	checks.append({"name": label, "passed": value})
	if not value: printerr("FAIL: ", label)
func _initialize(): call_deferred("execute")
func execute():
	var exact=true
	for seed in [20261020,17]:
		for mask in 512:
			var cell=Vector2i(mask%31-15,mask/31-8)
			var nodes=Contours.density_samples(mask).duplicate()
			for y in range(Contours.SUBDIVISIONS+1):
				for x in range(Contours.SUBDIVISIONS+1):nodes[y*(Contours.SUBDIVISIONS+1)+x]+=Contours.fracture_bias(cell*Contours.SUBDIVISIONS+Vector2i(x,y),seed)
			var reference=Contours.build_template(mask,nodes,true)
			var cached=Contours.fractured_template(mask,cell,seed)
			exact=exact and reference.pieces==cached.pieces and reference.outline==cached.outline
	check(exact,"Fast full/empty bounds and cached fracture bias exactly match all 512 original marching cases for two seeds")
	var convex = true; var bounded = true; var segments = 0; var short_edges = true
	for mask in 512:
		var shape = Contours.template(mask)
		for polygon in shape.pieces:
			for i in polygon.size():
				var a: Vector2 = polygon[(i + 1) % polygon.size()] - polygon[i]
				var b: Vector2 = polygon[(i + 2) % polygon.size()] - polygon[(i + 1) % polygon.size()]
				convex = convex and a.cross(b) >= -0.000001
				bounded = bounded and Rect2(-0.001, -0.001, 1.002, 1.002).has_point(polygon[i])
		for i in range(0, shape.outline.size(), 2):
			segments += 1
			var a: Vector2 = shape.outline[i]; var b: Vector2 = shape.outline[i + 1]
			var straight = (absf(a.x - b.x) < 0.000001 or absf(a.y - b.y) < 0.000001) and absf(Contours.density(mask, a.lerp(b, 0.5)) - Contours.ISO) < 0.000001
			short_edges = short_edges and (a.distance_to(b) <= 0.36 or straight)
	check(convex and bounded, "Every one of 512 neighboring rock patterns produces bounded convex collision pieces")
	check(segments > 1000 and short_edges, "Continuous boundaries use short curved-contour samples instead of full tile edges")
	check(Contours.template(0).pieces.is_empty() and Contours.template(511).pieces.size() == 1, "Empty and deep solid regions retain the cheap cached path")
	var monotone = true
	for mask in 512:
		for bit in 9:
			if not mask & (1 << bit): continue
			for point in [Vector2(0.1, 0.1), Vector2(0.35, 0.65), Vector2(0.5, 0.5), Vector2(0.9, 0.9)]:
				monotone = monotone and Contours.density(mask & ~(1 << bit), point) <= Contours.density(mask, point) + 0.000001
	check(monotone, "Removing material never increases the continuous rock field or grows a wall into a previous route")
	var fractured_convex = true; var stable = true; var preserved = true; var varied = 0
	for mask in 512:
		var original = Contours.density_samples(mask).duplicate()
		for cell in [Vector2i(-7, 11), Vector2i(13, -9)]:
			var shape = Contours.fractured_template(mask, cell, 20261020)
			stable = stable and shape.outline == Contours.fractured_template(mask, cell, 20261020).outline and original == Contours.density_samples(mask)
			if shape.outline != Contours.template(mask).outline: varied += 1
			for polygon in shape.pieces:
				for i in polygon.size():
					var a: Vector2 = polygon[(i + 1) % polygon.size()] - polygon[i]
					var b: Vector2 = polygon[(i + 2) % polygon.size()] - polygon[(i + 1) % polygon.size()]
					fractured_convex = fractured_convex and a.cross(b) >= -0.000001
			var center = Contours.density(mask, Vector2(0.5, 0.5)) + Contours.fracture_bias(cell * Contours.SUBDIVISIONS + Vector2i(2, 2), 20261020)
			preserved = preserved and ((center >= Contours.ISO) == bool(mask & 16))
	check(fractured_convex and varied > 100, "All 512 material arrangements retain convex collision pieces with varied rock fractures")
	check(stable, "Fractures are fixed in world space and never mutate the shared smooth templates")
	check(preserved, "Small surviving rocks keep a solid center and excavated cells keep an open center")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks, "patterns": 512, "segments": segments}
	FileAccess.open("res://artifacts/cave-curves-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if report.passed else 1)
