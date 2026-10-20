extends RefCounted
## Local-space version of chonglai_2's Hair: retain the previous world pose,
## relax toward the root direction, then constrain every link to its length.
const Ink = preload("res://scripts/blue_ink.gd")
const LINKS = 16
const HEAD_LENGTH = 164.0
const BODY_LENGTH = 128.0
const RANK_LENGTH = 20.0
var strands: Dictionary = {}

static func fusion_count(level: int) -> int:
	return maxi(0,level-1)*2

func clear(): strands.clear()

func step(key: int, at: Vector2, angle: float, count: int, head: bool, dt: float, clock: float, motion: float = -1.0):
	var xform = Transform2D(angle, at)
	var bundle: Array = strands.get(key, [])
	if bundle.size() != count: bundle.clear()
	for n in count:
		var side = -1.0 if n % 2 == 0 else 1.0
		var rank = float(n / 2)
		var root = Vector2(12, side * 22) if head else Vector2(12 - rank * 18, side * 23)
		var axis = Vector2(1, side * 0.8).normalized() if head else Vector2(-0.6 - rank * 0.3, side).normalized()
		var length = (HEAD_LENGTH if head else BODY_LENGTH + rank * RANK_LENGTH) / float(LINKS - 1)
		var natural = natural_pose(n, head, clock)
		if n >= bundle.size():
			bundle.append({"points": natural.duplicate(), "transform": xform, "idle": 0.0})
		var strand: Dictionary = bundle[n]
		var pts: PackedVector2Array = strand.points
		var previous: PackedVector2Array = (xform.affine_inverse() * strand.transform) * pts
		var moving = motion > 0.01 if motion >= 0 else Vector2(strand.transform.origin).distance_to(at) > 2.0 * dt or absf(angle_difference(strand.transform.get_rotation(), angle)) > 0.04 * dt
		var delta = clampf(dt, 0, 0.05)
		strand.idle = lerpf(float(strand.get("idle",0)), 0.0 if moving else 1.0, 1.0-exp(-(12.0 if moving else 3.0)*delta))
		var recovery = (1.0-exp(-4.5*delta))*float(strand.idle)
		# Teleports/restarts seed at the new anchor instead of stretching across the map.
		if Vector2(strand.transform.origin).distance_to(at) > 200:
			for i in LINKS: previous[i] = root + axis * length * i
		pts[0] = root
		var direction = axis.rotated(sin(clock * 2.4 + n * 1.9) * 0.28)
		# The directional spring must also soften at rest; otherwise it pulls
		# the strand back quickly even while natural-pose recovery is slowed.
		var stiffness = 1.0 - exp(-lerpf(9.0, 2.5, float(strand.idle)) * delta)
		for i in range(1, LINKS):
			var base = pts[i-1] + direction * length
			var pos = pts[i].lerp(previous[i], 0.95).lerp(base, stiffness)
			# At rest, ease out transported momentum and return to the live
			# natural wave. Blend positions before enforcing lengths: no snap/collapse.
			pos = pos.lerp(natural[i], recovery)
			direction = (pos - pts[i-1]).normalized()
			if direction.length_squared() < 0.01: direction = axis
			pts[i] = pts[i-1] + direction * length
		strand.points = pts; strand.transform = xform
	strands[key] = bundle

func poses(key: int) -> Array:
	var result: Array = []
	for strand in strands.get(key, []): result.append(strand.points)
	return result

func retain(keys: Array):
	for key in strands.keys():
		if key not in keys: strands.erase(key)

static func resting(clock: float) -> Array:
	return [natural_pose(0,true,clock), natural_pose(1,true,clock)]

static func natural_pose(n:int, head:bool, clock:float)->PackedVector2Array:
	var side = -1.0 if n%2==0 else 1.0
	var rank = float(n/2)
	var root = Vector2(12,side*22) if head else Vector2(12-rank*18,side*23)
	var axis = Vector2(1,side*0.8).normalized() if head else Vector2(-0.6-rank*0.3,side).normalized()
	var length = (HEAD_LENGTH if head else BODY_LENGTH+rank*RANK_LENGTH)/float(LINKS-1)
	var pts=PackedVector2Array([root])
	for i in range(1,LINKS):
		var t=float(i)/(LINKS-1)
		var wave=sin(clock*2.4+n*1.9-t*3.0)*(0.16+0.22*t)
		pts.append(pts[-1]+axis.rotated(wave)*length)
	return pts

static func paint(canvas: CanvasItem, poses: Array, at: Vector2, angle: float, scale_factor: float, evolved: bool = false):
	canvas.draw_set_transform(at, angle, Vector2.ONE * scale_factor)
	for pts in poses:
		# Short overlapping tapered strokes also handle tight turns/self-crossings;
		# one long polygon can become non-simple and fail triangulation.
		var smooth=PackedVector2Array()
		for i in range(pts.size()-1):
			for sample in 3:
				smooth.append(Vector2(pts[i]).cubic_interpolate(pts[i+1],pts[maxi(0,i-1)],pts[mini(pts.size()-1,i+2)],sample/3.0))
		smooth.append(pts[-1])
		for i in range(smooth.size()-1):
			var width=lerpf(5.8 if evolved else 4.8,0.45,float(i)/(smooth.size()-1))
			canvas.draw_line(smooth[i],smooth[i+1],Ink.INK,width,true)
			canvas.draw_line(smooth[i],smooth[i+1],Color("739ca0") if evolved else Ink.PAPER,maxf(0.25,width*0.38),true)
	canvas.draw_set_transform(Vector2.ZERO)
