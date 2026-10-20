extends RefCounted
## Salvage is encounter-local. Living detached modules keep identity and damage;
## only the connected body participates in combat. No module is cloned or healed.
const PICKUP_RADIUS = 96.0
const PICKUP_DELAY = 1.0
const WAKE_DELAY = 0.085
var groups: Array = []
var serial = 0

func clear():
	groups.clear()
	serial = 0

func count() -> int:
	var total = 0
	for group in groups: total += group.parts.size()
	return total

func sever(body, indices: Array):
	if indices.is_empty(): return
	if body.character_id != "centipede":
		body.remove_parts(indices)
		return
	var ordered: Array = body.body_part_indices()
	var cut = false
	var removed: Array = []
	var survivors: Array = []
	var poses: Array = []
	for index in ordered:
		var part: Dictionary = body.parts[index]
		var dead = index in indices or float(part.hp) <= 0
		if dead:
			cut = true
			store_group(survivors, poses)
			survivors = []; poses = []
		if not cut: continue
		removed.append(index)
		if dead: continue
		survivors.append(part)
		var pose: Dictionary = body.segment_pose(int(part.segment))
		poses.append({"point":Vector2(pose.point),"direction":Vector2(pose.direction),"activation":0.0})
	store_group(survivors, poses)
	body.remove_parts(removed)

func store_group(parts: Array, poses: Array):
	if parts.is_empty(): return
	serial += 1
	groups.append({"uid":serial,"parts":parts,"poses":poses,"age":0.0,"state":"dormant","wake_age":0.0})

func seed_recovered_motion(body, group: Dictionary, original_count: int):
	body.motion.ensure_length(body)
	var leader: Vector2 = body.segment_pose(original_count).point
	var physical: Vector2 = body.head if original_count==0 else body.motion.centers[original_count-1]
	for j in group.parts.size():
		var i = original_count+j
		var pose: Dictionary = group.poses[j]
		var wave = sin(body.motion.phase-(i+1)*0.9)*lerpf(0.045,0.075,body.motion.activity)*smoothstep(0.0,3.0,float(i+1))*smoothstep(0.0,0.4,body.motion.elapsed)
		var angle = Vector2(pose.point).direction_to(leader).angle()-wave
		body.motion.spine[i]=angle
		body.motion.route[i]=angle
		body.motion.orientations[i]=Vector2(pose.direction).angle()-wave
		physical-=Vector2.from_angle(angle)*body.body_spacing
		body.motion.centers[i]=physical
		leader=pose.point

func step(body, dt: float):
	if dt <= 0 or groups.is_empty() or body.parts.is_empty() or body.parts[0].hp <= 0: return
	dt = clampf(dt,0.0,0.1)
	var busy = false
	for group in groups:
		group.age += dt
		if group.state == "waking": busy = true
	# Curl poses are a different solver; freeze assembly until uncurl finishes.
	if body.coil_rig.engaged(): return
	if not busy:
		for group in groups:
			if group.age < PICKUP_DELAY: continue
			var near = false
			for pose in group.poses:
				if body.head.distance_squared_to(pose.point) <= PICKUP_RADIUS*PICKUP_RADIUS: near = true; break
			if near:
				group.state = "waking"
				break
	for group in groups:
		if group.state != "waking": continue
		group.wake_age += dt
		var leader: Vector2 = body.segment_pose(body.segment_count()).point
		var complete = true
		for i in group.parts.size():
			var local_age: float = maxf(0.0,float(group.wake_age)-float(i)*WAKE_DELAY)
			var pose: Dictionary = group.poses[i]
			pose.activation = smoothstep(0.0,0.55,local_age)
			if local_age > 0:
				# A critically damped approach with finite speed, never teleporting.
				var tangent: Vector2 = Vector2(pose.point).direction_to(leader)
				if tangent.length_squared()<0.001: tangent=Vector2(pose.direction)
				var target: Vector2 = leader-tangent*body.body_spacing
				var delta: Vector2 = target-Vector2(pose.point)
				pose.point = body.ground_position(pose.point,pose.point+delta.limit_length(720.0*dt)*minf(1.0,local_age/0.25),27.0)
				pose.direction = Vector2.from_angle(lerp_angle(Vector2(pose.direction).angle(),tangent.angle(),1.0-exp(-12.0*dt)))
				group.parts[i].position = pose.point
			if local_age < 0.75 or absf(Vector2(pose.point).distance_to(leader)-body.body_spacing)>0.01: complete = false
			leader=pose.point
		if complete:
			var original_count: int = body.segment_count()
			var next: int = original_count+1
			for part in group.parts:
				part.segment=next; next+=1
				# Elapsed cooldowns stay frozen during salvage; no free volley,
				# shield recharge, HP repair or fusion-level reset on pickup.
				body.parts.append(part)
			seed_recovered_motion(body,group,original_count)
			body.refresh_positions()
			groups.erase(group)
			body.emit_feedback("installed",group.parts.map(func(p):return p.feedback_uid))
		return
