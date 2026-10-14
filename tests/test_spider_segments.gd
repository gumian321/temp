extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/chain_centipede.gd")
const Rig = preload("res://scripts/spider_rig.gd")
const Art = preload("res://scripts/spider_art.gd")
var failures = 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize():
	var db = DB.new()
	var body = Body.new(db)
	body.configure_character("spider")
	var gun = db.named("Core_Gun_Gatling").id
	check(body.spider_rig.legs.size() == 8, "Eight permanent legs exist at zero equipment")
	for leg in body.spider_rig.legs:
		check(leg.segments.is_empty() and leg.chain_points.size() == 3, "Empty leg has connector and claw, no equipment shell")
		check(Vector2(leg.claw.a).distance_to(leg.claw.b) > 20.0, "Empty leg ends in a substantial claw")
	for count in range(1, 5):
		body.install_module(gun, body.spider_mount(0, count - 1))
		check(body.spider_rig.legs[0].segments.size() == count, "Assembly creates exactly one shell immediately per module")
		for frame in range(100): body.step(1.0 / 60.0, Vector2.ZERO, false)
		var leg: Dictionary = body.spider_rig.legs[0]
		check(is_equal_approx(leg.length, Rig.BASE_LENGTH + Rig.MODULE_LENGTH * count), "Each module adds exactly one length increment")
		for depth in range(count):
			var segment: Dictionary = leg.segments[depth]
			var pose = body.spider_rig.mount_pose(body.spider_mount(0, depth))
			check(Vector2(segment.a).distance_to(segment.b) > 50.0, "Discrete shell remains chunky rather than a thin stretched bone")
			check(Vector2(pose.point).distance_to((Vector2(segment.a) + Vector2(segment.b)) * 0.5) < 0.001, "Each mounted tower is centered on its own shell")
			check(Art.SEGMENT_WIDTH > body.module_size(body.part_at(body.spider_mount(0, depth))) + 8.0, "Armor rim remains wider than tower at default zoom")
		for other in range(1, 8): check(body.spider_rig.legs[other].segments.is_empty(), "Other legs never gain phantom shells")
	while body.parts.size() < 33: body.append_segment(gun)
	for frame in range(180): body.step(1.0 / 60.0, Vector2.ZERO, false)
	var total = 0
	for leg in body.spider_rig.legs:
		total += leg.segments.size()
		check(leg.segments.size() == 4 and leg.chain_points.size() == 7, "Full leg is connector plus four countable shells plus claw")
	check(total == 32, "Full spider has exactly32 equipment shells and eight separate claws")
	for side in range(2):
		for depth in range(4):
			var front_middle: Dictionary = body.spider_rig.legs[2 + side].segments[depth]
			var rear_middle: Dictionary = body.spider_rig.legs[4 + side].segments[depth]
			check(Vector2(front_middle.point).distance_to(rear_middle.point) > Art.SEGMENT_WIDTH, "Middle legs retain separate visible shafts instead of merging before the claws")
	for frame in range(180):
		body.step(1.0 / 60.0, Vector2.from_angle(frame * 0.03), true)
		for index in range(8):
			var leg: Dictionary = body.spider_rig.legs[index]
			check(Vector2(leg.claw.b).distance_to(Vector2(leg.foot) + Vector2.UP * leg.lift * 10.0) < 0.001, "Visual claw tip follows actual planted/lifted contact")
			for depth in range(leg.segments.size()):
				for other_depth in range(depth + 1, leg.segments.size()):
					check(Vector2(leg.segments[depth].point).distance_to(leg.segments[other_depth].point) > 36.0, "Same-leg armor centers stay separately countable through all turn angles")
			for segment in leg.segments:
				check(Vector2(segment.a).is_finite() and Vector2(segment.b).is_finite(), "Articulated shells remain finite through boosted turns")
				check(Vector2(segment.a).distance_to(segment.b) >= Rig.MODULE_LENGTH - 0.1, "Articulated shells retain their independent rigid length")
	print("Spider segment geometry: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
