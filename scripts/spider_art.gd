extends RefCounted
## Image-generated porcelain pieces, articulated by the simulation-owned rig.
## No painted full-spider warp: each link is one stable-width raster draw.
static var pieces: Dictionary = {}
const REGIONS = {
	"body": Rect2(80, 65, 1080, 540),
	"upper": Rect2(100, 625, 550, 205),
	"lower": Rect2(100, 850, 460, 140),
	"foot": Rect2(100, 1000, 640, 210),
	"joint": Rect2(945, 990, 235, 220),
}

static func prepare():
	if not pieces.is_empty(): return
	var atlas: Texture2D = load("res://assets/characters/spider_parts.png")
	for key in REGIONS:
		var piece = AtlasTexture.new()
		piece.atlas = atlas
		piece.region = REGIONS[key]
		piece.filter_clip = true
		pieces[key] = piece

static func _joint(canvas: CanvasItem, point: Vector2, radius: float, tint: Color):
	canvas.draw_set_transform(point)
	canvas.draw_texture_rect(pieces.joint, Rect2(-radius, -radius, radius * 2, radius * 2), false, tint)

static func _link(canvas: CanvasItem, a: Vector2, b: Vector2, thickness: float, key: String, tint: Color):
	# Independently scale along/across the bone; its width never grows with reach.
	var texture: Texture2D = pieces[key]
	var source_a = Vector2(43, 107) if key == "upper" else Vector2(39, 70)
	var source_b = Vector2(545, 107) if key == "upper" else Vector2(455, 70)
	if key == "foot":
		source_a = Vector2(45, 93)
		source_b = Vector2(612, 188)
	var source_axis = source_b - source_a
	var direction = (b - a).normalized()
	var normal = direction.orthogonal()
	var scale_x = a.distance_to(b) / source_axis.length()
	var scale_y = thickness / texture.get_height()
	# The foot's painted tip is slightly curved; map its measured endpoints exactly.
	var source_dir = source_axis.normalized()
	var source_normal = source_dir.orthogonal()
	var basis_x = direction * source_dir.x * scale_x + normal * source_normal.x * scale_y
	var basis_y = direction * source_dir.y * scale_x + normal * source_normal.y * scale_y
	var origin = a - basis_x * source_a.x - basis_y * source_a.y
	canvas.draw_set_transform_matrix(Transform2D(basis_x, basis_y, origin))
	canvas.draw_texture(texture, Vector2.ZERO, tint)

static func _bone_chain(canvas: CanvasItem, a: Vector2, b: Vector2, zoom: float, key: String, tint: Color):
	# A half-bone crop is broad at its socket and tapers toward its distal
	# endpoint. One continuous femur/tibia avoids a bead-necklace silhouette.
	# Module growth lengthens this rigid shell, never its painted width.
	_link(canvas, a, b, (20.0 if key == "upper" else 14.0) * zoom, key, tint)

static func draw_body(canvas: CanvasItem, player, at: Vector2, zoom: float, _clock: float):
	prepare()
	player.spider_rig.ensure(player)
	# Ground shadows stay at the planted world contacts as the feet lift.
	for leg in player.spider_rig.legs:
		var foot: Vector2 = at + (Vector2(leg.foot) - player.head) * zoom
		canvas.draw_set_transform(foot + Vector2(1, 3) * zoom, 0, Vector2(1, 0.48))
		canvas.draw_circle(Vector2.ZERO, (4.0 + float(leg.lift) * 1.5) * zoom, Color(0.04, 0.08, 0.13, 0.19 - float(leg.lift) * 0.09))
	for leg in player.spider_rig.legs:
		var visual: PackedVector2Array = leg.visual_points
		var hip: Vector2 = at + (visual[0] - player.head) * zoom
		var knee: Vector2 = at + (visual[1] - player.head) * zoom
		var foot: Vector2 = at + (visual[2] - player.head) * zoom
		var lift = float(leg.lift)
		var tint = Color.WHITE.lerp(Color(0.82, 0.88, 0.96), (1.0 - lift) * 0.12)
		var foot_length = minf(17.0 * zoom * (1.0 + lift * 0.08), knee.distance_to(foot) * 0.45)
		var ankle = foot - (foot - knee).normalized() * foot_length
		_bone_chain(canvas, hip, knee, zoom, "upper", tint)
		_bone_chain(canvas, knee, ankle, zoom, "lower", tint)
		_link(canvas, ankle, foot, (10.0 + lift) * zoom, "foot", tint)
		_joint(canvas, knee, 3.5 * zoom, tint)
		_joint(canvas, ankle, 2.2 * zoom, tint)
	# The leg-free carapace covers the eight independent hip pivots.
	canvas.draw_set_transform(at, player.facing.angle(), Vector2.ONE * zoom)
	canvas.draw_texture_rect(pieces.body, Rect2(-58, -29, 116, 58), false)
	canvas.draw_set_transform(Vector2.ZERO)
