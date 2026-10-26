extends Control
## Menu specimen assembled from the same pieces used during play.
const Centipede = preload("res://scripts/centipede_art.gd")
const Spider = preload("res://scripts/spider_art.gd")
const Guide = preload("res://scripts/field_guide.gd")
var character_id = "centipede"
var chinese = true
var clock = 0.0
var redraw_left = 0.0
var body_points = PackedVector2Array()

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	# Equal arc-length sampling keeps the shells joined along the curved spine.
	var curve = Curve2D.new()
	curve.add_point(Vector2(555, 175), Vector2.ZERO, Vector2(105, 65))
	curve.add_point(Vector2(565, 430), Vector2(92, -85), Vector2(-76, 76))
	curve.add_point(Vector2(310, 465), Vector2(105, 50), Vector2(-95, -62))
	curve.add_point(Vector2(265, 260), Vector2(-65, 65), Vector2.ZERO)
	var length = curve.get_baked_length()
	for i in 12: body_points.append(curve.sample_baked(length * i / 11.0))
	queue_redraw()

func _process(dt: float):
	if not is_visible_in_tree(): return
	clock += dt; redraw_left -= dt
	if redraw_left <= 0:
		redraw_left = .05
		queue_redraw()

static func centipede(canvas: CanvasItem, points: PackedVector2Array, scale_factor: float, time: float = 0.0):
	if points.size() < 2: return
	var last = points.size() - 1
	Centipede.tail(canvas, points[last], (points[last - 1] - points[last]).angle(), scale_factor)
	for i in range(last, -1, -1):
		var direction = points[maxi(0, i - 1)] - points[mini(last, i + 1)]
		var feelers: Array = []
		if i == 0:
			feelers = Centipede.Flagella.resting(time)
			# A folded resting pose keeps the antennae inside the specimen plate.
			for n in feelers.size():
				var strand: PackedVector2Array = feelers[n]
				var origin = strand[0]
				for j in range(1, strand.size()): strand[j] = origin + (strand[j] - origin) * .46
				feelers[n] = strand
		Centipede.segment(canvas, points[i], direction.angle(), scale_factor, -i * .6 + time * .16,
			i == 0, false, false, .0, time, [], feelers)
	canvas.draw_set_transform(Vector2.ZERO)

static func spider(canvas: CanvasItem, at: Vector2, scale_factor: float, time: float = 0.0):
	Spider.prepare()
	if Spider.pieces.is_empty(): return
	for side in [-1, 1]:
		for i in 4:
			var root = Vector2(17 - i * 16, side * 19)
			var knee = Vector2(72 - i * 44, side * (49 + sin(i * .9) * 12))
			var foot = Vector2(110 - i * 65, side * (90 + cos(i) * 12))
			foot += Vector2(sin(time * .6 + i) * 1.1, 0)
			Spider._link(canvas, at + root * scale_factor, at + knee * scale_factor, 27 * scale_factor, "segment", Color.WHITE)
			Spider._link(canvas, at + knee * scale_factor, at + foot * scale_factor, 24 * scale_factor, "claw", Color.WHITE)
	canvas.draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	canvas.draw_texture_rect(Spider.pieces.body, Rect2(-65, -30.6, 115.5, 61.5), false)
	canvas.draw_set_transform(Vector2.ZERO)

func _draw():
	var faint = Color(Guide.PAPER, .10)
	# Broken specimen circles and registration ticks, deliberately offset.
	for r in [225.0, 235.0, 298.0]:
		draw_arc(Vector2(420, 350), r, -.82, 1.15, 50, faint, 1, true)
		draw_arc(Vector2(420, 350), r, 1.64, 3.58, 55, faint, 1, true)
	for i in 40:
		var angle = i * TAU / 40
		var axis = Vector2.from_angle(angle)
		draw_line(Vector2(420, 350) + axis * 306, Vector2(420, 350) + axis * (314 if i % 5 == 0 else 309), faint, 1, true)
	if character_id == "spider": spider(self, Vector2(420, 340), 2.45, clock)
	else: centipede(self, body_points, 1.56, clock)
	var a = Vector2(596, 197) if character_id == "centipede" else Vector2(465, 294)
	var end = Vector2(656, 125) if character_id == "centipede" else Vector2(636, 72)
	draw_polyline(PackedVector2Array([a, end, end + Vector2(116, 0)]), Color(Guide.PAPER, .4), 1, true)
	draw_circle(a, 3, Guide.ACCENT)
	draw_polyline(PackedVector2Array([Vector2(315, 475), Vector2(174, 577), Vector2(81, 577)]), Color(Guide.PAPER, .4), 1, true)
	draw_circle(Vector2(315, 475), 3, Guide.ACCENT)
	var font = Guide.UI.font()
	draw_string(font, end + Vector2(0, -12), "01 / 感知" if chinese else "01 / SENSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Guide.MUTED)
	draw_string(font, Vector2(81, 566), "02 / 生长" if chinese else "02 / GROW", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Guide.MUTED)
	for i in 21:
		var x = 260 + i * 16
		draw_line(Vector2(x, 658), Vector2(x, 658 + (11 if i % 5 == 0 else 5)), Color(Guide.PAPER, .28), 1)
