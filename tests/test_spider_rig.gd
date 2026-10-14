extends SceneTree
const Rig = preload("res://scripts/spider_rig.gd")
class Player:
	extends RefCounted
	var head = Vector2.ZERO
	var facing = Vector2.RIGHT
	var character_reset_serial = 0
	var counts = [0, 0, 0, 0, 0, 0, 0, 0]
	func spider_leg_count(index): return counts[index]
var failures = 0
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)
func _initialize():
	var p = Player.new()
	var rig = Rig.new()
	rig.ensure(p)
	check(rig.legs.size() == 8, "Eight bare legs exist without towers")
	var snapshot = rig.legs.duplicate(true)
	for i in range(100):
		rig.ensure(p)
		rig.mount_pose(1)
		rig.step(p, 0.0)
	check(snapshot == rig.legs, "Read, refresh, and pause do not advance gait")
	for i in range(240): rig.step(p, 1.0 / 60.0)
	check(snapshot == rig.legs, "Idle feet do not jitter")
	var samples = 0
	var swings = 0
	var all_planted = 0
	var max_extension = 0.0
	for frame in range(600):
		var old = rig.legs.duplicate(true)
		p.head += Vector2.RIGHT * 180.0 / 60.0
		rig.step(p, 1.0 / 60.0)
		var groups = {}
		for index in range(8):
			var leg = rig.legs[index]
			if leg.stepping:
				groups[0 if index in [0, 3, 4, 7] else 1] = true
				if not old[index].stepping: swings += 1
			elif not old[index].stepping:
				samples += 1
				check(leg.foot == old[index].foot, "Planted feet remain anchored in world space")
			max_extension = maxf(max_extension, leg.hip.distance_to(leg.foot) / leg.length)
			check(absf(leg.hip.distance_to(leg.knee) - leg.knee.distance_to(leg.foot)) < 0.01, "IK shares reach equally across both bones")
			check(leg.hip.is_finite() and leg.knee.is_finite() and leg.foot.is_finite(), "IK stays finite")
		check(groups.size() <= 1, "Only one alternating support group swings")
		if groups.is_empty(): all_planted += 1
	check(max_extension < 1.01, "Normal movement remains within rigid leg reach")
	check(samples > 1000 and swings > 20 and swings < 1000, "Repeated stance and deliberate steps")
	check(all_planted > 20, "Each cycle includes a grounded settling interval")
	p.counts[0] = 4
	var length = rig.legs[0].length
	for i in range(180):
		rig.step(p, 1.0 / 60.0)
		check(rig.legs[0].length >= length, "Adding modules grows continuously")
		length = rig.legs[0].length
	check(is_equal_approx(length, Rig.BASE_LENGTH + Rig.MODULE_LENGTH * 4), "Four modules extend full reach")
	p.counts[0] = 3
	rig.step(p, 1.0 / 60.0)
	check(rig.legs[0].length < length and rig.legs[0].length > Rig.BASE_LENGTH + Rig.MODULE_LENGTH * 3, "One lost module retracts smoothly")
	for i in range(120): rig.step(p, 1.0 / 60.0)
	check(is_equal_approx(rig.legs[0].length, Rig.BASE_LENGTH + Rig.MODULE_LENGTH * 3), "Single loss removes one length increment")
	for mount in range(1, 33):
		var pose = rig.mount_pose(mount)
		check(pose.point.is_finite() and pose.direction.is_finite(), "Mount poses are finite joint-path samples")
	var results = []
	for speed in [180.0, 240.0, 320.0, 420.0]:
		var actor = Player.new()
		var gait = Rig.new()
		gait.ensure(actor)
		for frame in range(240):
			actor.head += Vector2.RIGHT * speed / 60.0
			gait.step(actor, 1.0 / 60.0)
			for leg in gait.legs:
				check(leg.hip.distance_to(leg.foot) < leg.length * 1.05, "Straight boost stays within five percent nominal reach")
	for fps in [30, 60, 120]:
		var actor = Player.new()
		var gait = Rig.new()
		gait.ensure(actor)
		for frame in range(fps * 3):
			actor.head += Vector2.RIGHT * 180.0 / fps
			gait.step(actor, 1.0 / fps)
		results.append(gait.legs[0].foot)
	check(results[0].distance_to(results[2]) < 12.0 and results[1].distance_to(results[2]) < 12.0, "Frame partition keeps bounded gait phase and feet")
	p.head += Vector2(2000, 1000)
	rig.step(p, 1.0 / 60.0)
	check(rig.legs[0].hip.distance_to(p.head) < 50.0 and not rig.legs[0].stepping, "Teleport replants immediately")
	var max_turn_extension = 0.0
	for frame in range(600):
		p.facing = Vector2.from_angle(frame * 0.06)
		p.head += p.facing * 8.0
		rig.step(p, 1.0 / 60.0)
		for leg in rig.legs:
			max_turn_extension = maxf(max_turn_extension, leg.foot.distance_to(leg.hip) / leg.length)
			check(leg.foot.distance_to(leg.hip) < 300.0 and leg.knee.is_finite(), "Fast turns have bounded foot lag")
	check(max_turn_extension < 1.20, "Boosted hard turns limit emergency extension to twenty percent")
	print("Spider gait checks: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
