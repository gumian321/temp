extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/grid_centipede.gd")
const LegacyBody = preload("res://scripts/centipede.gd")
var checks: Array = []
var metrics: Dictionary = {}

func check(ok: bool, title: String):
	checks.append({"passed": ok, "name": title})
	if not ok: printerr("FAIL: ", title)

func simulate(body, seconds: float, direction: Vector2, fps: int = 60):
	for frame in range(roundi(seconds * fps)): body.step(1.0 / fps, direction, false)

func _initialize():
	var db = DB.new()
	var body = Body.new(db)
	var legacy = LegacyBody.new(db)
	var cruise = clampf(float(db.stores.PlayerDataStore.enginePower), 2.0, 4.0) * 48.0
	simulate(body, 0.2, Vector2.RIGHT)
	simulate(legacy, 0.2, Vector2.RIGHT)
	metrics.speed_at_200ms = body.velocity.length()
	metrics.previous_speed_at_200ms = legacy.velocity.length()
	check(body.velocity.length() > cruise * 0.95, "Movement reaches cruising speed within 200 ms")
	check(body.head.x > legacy.head.x * 3.0, "Starting input moves the actual playable head promptly instead of double smoothing")
	simulate(body, 0.4, Vector2.UP)
	check(absf(body.facing.angle_to(Vector2.UP)) < 0.16, "A 90-degree turn responds within 400 ms")
	simulate(body, 0.1, Vector2.ZERO)
	check(body.velocity.length() < 0.01, "Releasing movement stops the head within 100 ms")
	var parked = body.head
	var parked_facing = body.facing
	var tail_positions: Array[Vector2] = []
	for frame in range(180):
		body.step(1.0 / 60.0, Vector2.ZERO, false)
		tail_positions.append(body.segment_pose(6).point)
	check(body.head.distance_to(parked) < 0.001 and body.facing.distance_to(parked_facing) < 0.001, "Idle spine motion never moves or rotates the head/aim anchor")
	var idle_span = 0.0
	for point in tail_positions.slice(60): idle_span = maxf(idle_span, point.distance_to(tail_positions[60]))
	metrics.idle_tail_span = idle_span
	check(idle_span > 2.0 and idle_span < 30.0, "Idle body stays alive without drifting away")
	var poses_before: Array = body.body_poses.duplicate(true)
	for frame in range(10): body.step(0.0, Vector2.LEFT, false); body.refresh_positions()
	check(body.body_poses == poses_before, "Rendering, paused construction and zero-delta refreshes do not advance the spine")
	var trajectories: Array = []
	for fps in [30, 60, 120]:
		var variant = Body.new(db)
		for direction in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2(1,1), Vector2.ZERO]:
			simulate(variant, 1.0, direction, fps)
		trajectories.append(variant.body_poses.duplicate(true))
	var rate_error = 0.0
	for poses in trajectories:
		for i in range(poses.size()):
			rate_error = maxf(rate_error, poses[i].point.distance_to(trajectories[0][i].point))
	metrics.frame_rate_pose_error = rate_error
	check(rate_error < 0.05, "Identical input at 30, 60 and 120 FPS produces the same head and body path")
	var gun = db.named("Core_Gun_Gatling").id
	for count in [6, 60]:
		body = Body.new(db)
		body.grown_segments = count
		body.refresh_positions()
		body.install_module(gun, count, 0)
		body.parts[1].angle = -0.73
		var largest_step = 0.0
		var largest_bend = 0.0
		var largest_gap_error = 0.0
		var largest_mount_error = 0.0
		var previous: Array = body.body_poses.duplicate(true)
		for frame in range(600):
			var direction = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1,1)][(frame / 60) % 5]
			body.step(1.0 / 60.0, direction, false)
			for i in range(1, body.body_poses.size()):
				var pose: Dictionary = body.body_poses[i]
				var leader: Dictionary = body.body_poses[i-1]
				largest_gap_error = maxf(largest_gap_error, absf(pose.point.distance_to(leader.point) - body.body_spacing))
				largest_bend = maxf(largest_bend, absf(pose.direction.angle_to(leader.direction)))
				largest_step = maxf(largest_step, pose.point.distance_to(previous[i].point))
			var mount: Dictionary = body.parts[1]
			var wanted = body.segment_pose(count).point + body.slot_offset(0).rotated(mount.body_angle)
			largest_mount_error = maxf(largest_mount_error, mount.position.distance_to(wanted))
			previous = body.body_poses.duplicate(true)
		metrics[str(count) + "_segments"] = {"max_step": largest_step, "max_bend": largest_bend, "gap_error": largest_gap_error, "mount_error": largest_mount_error}
		check(largest_gap_error < 0.002 and largest_bend < 0.821, "%d segments keep exact spacing and bounded curvature through reversals" % count)
		check(largest_step < 4.0, "%d segments follow turns with less than four pixels of motion per frame" % count)
		check(largest_mount_error < 0.001 and body.parts[1].angle == -0.73, "%d-segment weapon follows its physical mount while aiming independently" % count)
	body = Body.new(db)
	simulate(body, 1.0, Vector2.RIGHT)
	var reversing_time = 0.0
	while absf(body.facing.angle_to(Vector2.LEFT)) > 0.1 and reversing_time < 2.0:
		body.step(1.0 / 120.0, Vector2.LEFT, false)
		reversing_time += 1.0 / 120.0
	metrics.reversal_seconds = reversing_time
	check(reversing_time < 0.9, "A full reversal completes as a responsive continuous arc")
	var turning = Body.new(db)
	simulate(turning,1.0,Vector2.RIGHT)
	var before_error = PI/2
	var eased = true
	for frame in 30:
		turning.step(1.0/60.0,Vector2.UP,false)
		var error = absf(turning.facing.angle_to(Vector2.UP))
		eased = eased and error<=before_error+0.0001 and absf(turning.motion.turn_rate)<=6.001
		before_error = error
	check(eased and before_error<0.04 and absf(turning.motion.turn_rate)>0.0001,"Steering eases into alignment without overshoot or snapping angular velocity to zero")
	turning = Body.new(db)
	simulate(turning,1.0,Vector2.RIGHT)
	simulate(turning,0.2,Vector2.UP)
	metrics.turning_tail_lateral_motion = absf(turning.motion.centers.back().y)
	check(metrics.turning_tail_lateral_motion<1.0,"A new bend travels from neck to tail instead of rotating the whole body immediately")
	var diagonal = Body.new(db)
	simulate(diagonal, 1.0, Vector2.ONE)
	check(absf(diagonal.velocity.length() - cruise) < 0.01, "Diagonal input cannot exceed normal cruising speed")
	body = Body.new(db)
	body.install_module(db.named("Core_FuelTank").id, 1, 4)
	body.fuel = body.max_fuel
	var start_fuel = body.fuel
	for frame in range(60): body.step(1.0 / 60.0, Vector2.RIGHT, true)
	check(body.velocity.length() > cruise and absf(start_fuel - body.fuel - 50.0) < 0.01, "Boost still uses installed fuel tanks and the source consumption rate")
	var phase_before = body.motion.phase
	body.reset()
	check(body.motion.spine.size() == 6 and body.motion.phase == 0.0 and phase_before != 0.0 and body.head == Vector2.ZERO, "A new run resets all movement and spine state")
	var report = {"checks": checks, "metrics": metrics, "passed": checks.all(func(c): return c.passed)}
	FileAccess.open("res://artifacts/centipede-motion-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
