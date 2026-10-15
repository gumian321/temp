extends SceneTree
const Art = preload("res://scripts/encounter_art.gd")
var failures: Array = []

func _initialize():
	var rows: Array = []
	for id in ["charger", "broodmother", "treasure", "warning_seal", "charge_lane", "hud_plate"]:
		var image = Art.texture(id).get_image()
		var bounds: Array = []
		for threshold in [.1, .5, .9]:
			var low = Vector2i(image.get_width(), image.get_height()); var high = Vector2i.ZERO
			var transparent = 0
			for y in range(0, image.get_height(), 2):
				for x in range(0, image.get_width(), 2):
					if image.get_pixel(x, y).a >= threshold:
						low = low.min(Vector2i(x, y)); high = high.max(Vector2i(x, y))
					else: transparent += 1
			bounds.append({"alpha": threshold, "min": [low.x, low.y], "max": [high.x, high.y], "transparent_samples": transparent})
			if transparent == 0: failures.append(id + " requires genuine alpha")
		rows.append({"id": id, "size": [image.get_width(), image.get_height()], "used_rect": str(image.get_used_rect()), "bounds": bounds})
	var report = {"passed": failures.is_empty(), "failures": failures, "images": rows}
	FileAccess.open("res://artifacts/encounter-art-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
