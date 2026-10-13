extends RefCounted
## Painted square shells plus separately pivoted mouth sprites and generated articulated leg sprites.
const Ink = preload("res://scripts/blue_ink.gd")
const BODY_SIZE = Vector2(54, 54)
const Legs=preload("res://scripts/centipede_legs.gd")
static var pieces: Dictionary = {}

static func prepare():
	if not pieces.is_empty(): return
	var atlas: Texture2D = load("res://assets/blue_ink/centipede_parts.png")
	var regions = {"head": Rect2(173,108,432,416), "body": Rect2(879,103,514,427), "upper_jaw": Rect2(155,625,486,313), "lower_jaw": Rect2(885,622,493,306)}
	for key in regions:
		var part = AtlasTexture.new()
		part.atlas = atlas
		part.region = regions[key]
		part.filter_clip = true
		pieces[key] = part
	var tail = AtlasTexture.new()
	tail.atlas = load("res://assets/blue_ink/centipede_tail_reference.png")
	tail.region = Rect2(1120,140,300,830)
	tail.filter_clip = true
	pieces.tail = tail
	var links:Texture2D=load("res://assets/blue_ink/centipede_leg_links.png")
	for key in ["upper_leg","lower_leg"]:
		var link=AtlasTexture.new();link.atlas=links
		link.region=Rect2(44,150,1230,310) if key=="upper_leg" else Rect2(20,575,1495,405)
		link.filter_clip=true;pieces[key]=link

static func outline(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float):
	canvas.draw_polyline(points, color, width, true)

static func jaw_angle(clock: float, activity: float, side: int) -> float:
	return side * (0.10 + (0.5 + 0.5 * sin(clock * lerpf(3.5, 19.0, activity))) * lerpf(0.13, 0.42, activity))

static func segment(canvas: CanvasItem, at: Vector2, angle: float, scale_factor: float, phase: float, head: bool = false, empty: bool = false, selected: bool = false, activity: float = 0.0, clock: float = -1.0, leg_poses:Array=[]):
	prepare()
	canvas.draw_set_transform(at, angle, Vector2.ONE * scale_factor)
	if head:
		# Antennae and mouth each have their own movement, independent of head aim.
		var time = phase / 3.0 if clock < 0 else clock
		for side in [-1, 1]:
			var feeler = PackedVector2Array([Vector2(9, side*21), Vector2(24, side*32), Vector2(46, side*(39+sin(time*2)*3)), Vector2(64, side*(34+sin(time*2.6)*3)), Vector2(73, side*27)])
			outline(canvas, feeler, Ink.INK, 3.0)
			outline(canvas, feeler, Ink.PAPER, 0.8)
		canvas.draw_texture_rect(pieces.head, Rect2(-31,-30,62,60), false)
		for side in [-1, 1]:
			var pivot = at + Vector2(25, side*8).rotated(angle)*scale_factor
			canvas.draw_set_transform(pivot, angle+jaw_angle(time,activity,side), Vector2.ONE*scale_factor)
			var rect = Rect2(-3,-8,34,23) if side == -1 else Rect2(-4,-14,34,23)
			canvas.draw_texture_rect(pieces.upper_jaw if side == -1 else pieces.lower_jaw, rect, false)
	else:
		for leg in (Legs.resting(phase) if leg_poses.is_empty() else leg_poses):
			draw_link(canvas,at,angle,scale_factor,leg.root,leg.knee,leg.side,true)
			draw_link(canvas,at,angle,scale_factor,leg.knee,leg.foot,leg.side,false)
		canvas.draw_set_transform(at,angle,Vector2.ONE*scale_factor)
		canvas.draw_texture_rect(pieces.body,Rect2(-BODY_SIZE/2,BODY_SIZE),false)
		if empty:
			canvas.draw_line(Vector2(-5,0),Vector2(5,0),Ink.PAPER,1.3,true)
			canvas.draw_line(Vector2(0,-5),Vector2(0,5),Ink.PAPER,1.3,true)
		if selected:canvas.draw_rect(Rect2(-30,-30,60,60),Ink.BLUE,false,2.0)
	canvas.draw_set_transform(Vector2.ZERO)

static func tail(canvas: CanvasItem, at: Vector2, angle: float, scale_factor: float):
	prepare()
	canvas.draw_set_transform(at,angle+PI/2,Vector2.ONE*scale_factor)
	canvas.draw_texture_rect(pieces.tail,Rect2(-14,-15,28,63),false)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_link(canvas:CanvasItem,at:Vector2,angle:float,scale_factor:float,start:Vector2,end:Vector2,side:int,upper:bool):
	var pivot=at+start.rotated(angle)*scale_factor
	# Atlas pivots measured on the untouched image. Align the painted claw tip,
	# rather than the bounding box, with the planted foot solved by the rig.
	var source_start=Vector2(101,140) if upper else Vector2(92,115)
	var source_end=Vector2(1154,185) if upper else Vector2(1460,365)
	var source_axis=source_end-source_start
	var factor=start.distance_to(end)/source_axis.length()*scale_factor
	canvas.draw_set_transform(pivot,angle+(end-start).angle()-side*source_axis.angle(),Vector2(factor,side*factor))
	var texture:Texture2D=pieces.upper_leg if upper else pieces.lower_leg
	canvas.draw_texture_rect(texture,Rect2(-source_start,texture.get_size()),false)
