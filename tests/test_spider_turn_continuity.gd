extends SceneTree
const Rig = preload("res://scripts/spider_rig.gd")
class Actor:
	extends RefCounted
	var head = Vector2.ZERO
	var facing = Vector2.RIGHT
	var character_reset_serial = 0
	var counts = [4,4,4,4,4,4,4,4]
	func spider_leg_count(i): return counts[i]
var failures = 0
func check(value, label):
	if not value:
		failures += 1
		push_error(label)
func _initialize():
	var report = []
	for fps in [15,30,60,120]:
		var actor = Actor.new()
		var rig = load(OS.get_environment("SPIDER_RIG_BASELINE")).new() if not OS.get_environment("SPIDER_RIG_BASELINE").is_empty() else Rig.new()
		rig.ensure(actor)
		var foot_speed = 0.0
		var mount_speed = 0.0
		var stretch = 0.0
		var planted = 0
		for frame in range(fps * 8):
			var before = rig.legs.duplicate(true)
			var time = float(frame) / fps
			var direction = Vector2.RIGHT if time < 1.0 else (Vector2.LEFT if time < 3.0 else Vector2.from_angle(time * 2.0))
			if time > 6.0: direction = Vector2.ZERO
			if direction != Vector2.ZERO:
				actor.facing = Vector2.from_angle(rotate_toward(actor.facing.angle(), direction.angle(), 7.0 / fps))
			actor.head += direction * 320.0 / fps
			rig.step(actor, 1.0/fps)
			check(rig.legs.filter(func(leg): return not leg.stepping).size() >= 4, "Fewer than four support legs")
			for i in 8:
				var leg = rig.legs[i]
				foot_speed = maxf(foot_speed, leg.foot.distance_to(before[i].foot) * fps)
				stretch = maxf(stretch, leg.hip.distance_to(leg.foot) / leg.length)
				for j in leg.segments.size():
					mount_speed = maxf(mount_speed, leg.segments[j].point.distance_to(before[i].segments[j].point) * fps)
				if not leg.stepping and not before[i].stepping and leg.get("step_serial",0) == before[i].get("step_serial",0):
					planted += 1
					check(leg.foot == before[i].foot, "Support contact slides")
				check(leg.knee.is_finite(), "Invalid IK")
		check(planted > 100, "No planted support")
		if OS.get_environment("SPIDER_RIG_BASELINE").is_empty():
			check(foot_speed < 1850.0, "Long foot exceeds planned swing speed")
			check(mount_speed < 3000.0, "Tower socket jumps during reversal")
			check(stretch < 1.2, "Loaded leg exceeds emergency reach allowance")
		report.append({"fps":fps,"max_foot_speed":foot_speed,"max_mount_speed":mount_speed,"max_extension":stretch})
	var changing = Actor.new()
	var changing_rig = Rig.new()
	changing_rig.ensure(changing)
	for frame in 240:
		var dt: float = [1.0/120.0, 1.0/30.0, 0.1][frame % 3]
		if frame in [40, 80, 120, 160, 200]:
			var feet = changing_rig.legs.map(func(leg): return leg.foot)
			changing.counts = [0,0,0,0,0,0,0,0] if frame == 120 else [3,1,4,0,2,0,4,1]
			changing_rig.ensure(changing)
			check(feet == changing_rig.legs.map(func(leg): return leg.foot), "Topology edit teleports contact")
		changing.head += Vector2.RIGHT * 160.0 * dt
		changing.facing = Vector2.from_angle(rotate_toward(changing.facing.angle(), PI if frame % 80 < 40 else 0.0, 7.0 * dt))
		changing_rig.step(changing,dt)
		for index in 8:
			var leg = changing_rig.legs[index]
			check(leg.foot.is_finite() and leg.knee.is_finite(), "Topology/hitch invalid IK")
			check(leg.segments.size() == changing.counts[index], "Wrong module count after edit")
			check(leg.foot.distance_to(leg.hip) < 400.0, "Topology/hitch unbounded limb")
	var frozen = changing_rig.legs.duplicate(true)
	changing_rig.step(changing,0.0)
	check(frozen == changing_rig.legs,"Paused rig changes")
	print(JSON.stringify(report))
	quit(1 if failures else 0)
