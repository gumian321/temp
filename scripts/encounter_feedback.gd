extends Node2D
## A few bounded world markers, above fire effects and below the HUD.
const UI = preload("res://scripts/game_ui.gd")
const Art = preload("res://scripts/encounter_art.gd")
const Encounters = preload("res://scripts/encounter_director.gd")
const COLORS = {"charger": Color("ff6c89"), "broodmother": Color("bca0ff"), "treasure": Color("ffd16f"), "hatchling": Color("bca0ff")}
const INK = Color("1a1019")
const CHARGE_LENGTH = Encounters.CHARGE_SPEED * Encounters.CHARGE_DURATION
var game

func setup(owner_game):
	game = owner_game
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _draw():
	if game == null or game.run == null or game.screen not in ["game", "pause", "result", "rewards"] or game.radar_mode: return
	var director = game.run.encounters
	var zoom: float = game.zoom
	var viewport: Vector2 = get_viewport_rect().size
	if director.phase == "warning":
		for marker in director.markers:
			var at: Vector2 = game.world(marker)
			var color: Color = COLORS.get(director.event_type, Color.WHITE)
			pointer(at, color, viewport)
			if not Rect2(Vector2.ZERO, viewport).grow(70).has_point(at): continue
			arrival_marker(at, zoom, color, 1.0 - director.warning_left / director.WARNING_TIME)
			var text = game.db.ui("TOO CLOSE · WAITING", "距离过近 · 等待出现") if director.warning_waiting else game.db.ui("INCOMING", "即将出现")
			caption(at + Vector2(0, -48 * zoom), text, color)
	for e in game.combat.enemies:
		if not e.has("encounter_type") or e.hp <= 0 or e.get("despawn", false): continue
		var color: Color = COLORS[e.encounter_type]
		var at: Vector2 = game.world(e.position)
		var visible_lane = false
		# A lane can enter the screen while its caster is still outside it.
		if e.encounter_type == "charger" and e.encounter_phase in ["windup", "dash"]:
			visible_lane = charge_lane(e, zoom, viewport)
		# The lane already communicates incoming direction; avoid an opposing edge arrow.
		if e.encounter_type != "hatchling" and not visible_lane: pointer(at, color, viewport)
		if not Rect2(Vector2.ZERO, viewport).grow(130).has_point(at): continue
		var radius = float(e.radius) * zoom * 1.6 + 4
		if e.encounter_type == "hatchling": continue
		if e.encounter_type != "charger":
			stamp("warning_seal", at, Vector2.ONE * radius * 2.2, 0, Color(color, 0.7))
		var text: String = {"charger": game.db.ui("LANCER", "冲锋虫"), "broodmother": game.db.ui("BROODMOTHER", "裂殖母虫"), "treasure": game.db.ui("TREASURE", "藏宝虫")}[e.encounter_type]
		if e.encounter_type == "charger":
			if e.encounter_phase in ["windup", "dash"]:
				if e.encounter_phase == "windup":
					var progress = clampf(1.0 - float(e.phase_left) / Encounters.CHARGE_WINDUP, 0, 1)
					countdown(at, radius, color, progress)
				text = game.db.ui("LOCKED · SIDESTEP", "已锁定 · 向侧面闪避")
			elif e.encounter_phase == "recover":
				text = game.db.ui("RECOVERING · STRIKE", "僵直 · 反击机会")
				color = Color("80ecd5")
		elif e.encounter_type == "treasure":
			text += "  %.1fs" % maxf(0, director.TREASURE_LIFETIME - e.age)
		caption(at + Vector2(0, -radius - 8), text, color)
	var momentum = game.combat.momentum
	if momentum.burst_left > 0:
		var at: Vector2 = game.world(game.player.head)
		stamp("warning_seal", at, Vector2.ONE * 100 * zoom, float(game.player.motion.elapsed) * .6, Color("ffd16f", .75))

func countdown(at: Vector2, radius: float, color: Color, progress: float):
	draw_arc(at, radius, -PI * .5, PI * 1.5, 48, Color(INK, .9), 5.0, true)
	draw_arc(at, radius, -PI * .5, PI * 1.5, 48, Color(color, .25), 1.5, true)
	if progress > .001:
		draw_arc(at, radius, -PI * .5, -PI * .5 + TAU * progress, 48, color, 2.5, true)

func arrival_marker(at: Vector2, zoom: float, color: Color, progress: float):
	# Keep the footprint fixed; only the countdown arc advances.
	var radius = 36.0 * zoom
	draw_circle(at, radius, Color(color, .09))
	countdown(at, radius, color, clampf(progress, 0, 1))
	for i in range(4):
		var direction = Vector2.from_angle(i * PI * .5)
		draw_line(at + direction * (radius - 7 * zoom), at + direction * (radius + 4 * zoom), color, 2, true)

func lane_outline(start: float, end: float, radius: float, round_start: bool) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(17):
		points.append(Vector2(end, 0) + Vector2.from_angle(-PI * .5 + PI * i / 16) * radius)
	if round_start:
		for i in range(17):
			points.append(Vector2(start, 0) + Vector2.from_angle(PI * .5 + PI * i / 16) * radius)
	else:
		points.append(Vector2(start, radius))
		points.append(Vector2(start, -radius))
	points.append(points[0])
	return points

func charge_lane(e: Dictionary, zoom: float, viewport: Vector2) -> bool:
	var direction: Vector2 = Vector2(e.charge_direction).normalized()
	if direction.is_zero_approx(): return false
	var dashing: bool = e.encounter_phase == "dash"
	var passed = clampf(float(e.get("charge_travel", 0.0)), 0, CHARGE_LENGTH) if dashing else 0.0
	var origin: Vector2 = Vector2(e.position) - direction * passed
	# Slows or a wall can shorten the reachable distance, without scaling glyphs.
	var extent = minf(CHARGE_LENGTH, passed + maxf(0, float(e.phase_left)) * Encounters.CHARGE_SPEED) if dashing else CHARGE_LENGTH
	if extent - passed <= .01: return false
	var start: Vector2 = game.world(origin + direction * passed)
	var end: Vector2 = game.world(origin + direction * extent)
	var radius = float(e.radius) * zoom
	var bounds = Rect2(start, Vector2.ZERO).expand(end).grow(radius + 5)
	if not bounds.intersects(Rect2(Vector2.ZERO, viewport)): return false
	var progress = 1.0 if dashing else clampf(1.0 - float(e.phase_left) / Encounters.CHARGE_WINDUP, 0, 1)
	var color: Color = COLORS.charger
	draw_set_transform(game.world(origin), direction.angle())
	# Outer geometry always shows the full sweep. Charge progress stays inside it.
	var outline = lane_outline(passed * zoom, extent * zoom, radius, not dashing)
	draw_colored_polygon(outline, Color(color, .10 if not dashing else .16))
	var fill_length = (extent * progress - passed) * zoom
	if fill_length > 0:
		draw_rect(Rect2(Vector2(passed * zoom, -radius * .78), Vector2(fill_length, radius * 1.56)), Color(color, .13))
	draw_polyline(outline, Color(INK, .9), 4.5, true)
	draw_polyline(outline, Color(color, .55 + progress * .35), 1.5, true)
	# World-anchored chevrons are revealed/removed, never stretched with the lane.
	for i in range(5):
		var along = 54.0 + i * 62.0
		if along - 8 < passed or along + 4 > extent: continue
		var lit = clampf((progress * CHARGE_LENGTH - along) / 26.0 + .5, 0, 1)
		var arrow = PackedVector2Array([Vector2(along - 8, -9) * zoom, Vector2(along + 4, 0) * zoom, Vector2(along - 8, 9) * zoom])
		draw_polyline(arrow, Color(INK, .85), 5.0, true)
		draw_polyline(arrow, Color(color, .3 + .7 * lit), 2.5, true)
	draw_set_transform(Vector2.ZERO)
	return true

func stamp(id: String, at: Vector2, extent: Vector2, angle: float, tint: Color):
	if extent.x <= 0 or extent.y <= 0: return
	draw_set_transform(at, angle)
	draw_texture_rect(Art.decal(id), Rect2(-extent * .5, extent), false, tint)
	draw_set_transform(Vector2.ZERO)

func caption(at: Vector2, text: String, tint: Color):
	var font = UI.font()
	var pos = at - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x / 2, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color("160b1e"))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tint)

func pointer(at: Vector2, color: Color, viewport: Vector2):
	var safe = Rect2(60, 185, viewport.x - 120, viewport.y - 340)
	if safe.has_point(at): return
	var center = viewport * 0.5
	var direction = center.direction_to(at)
	var anchor = at.clamp(safe.position, safe.end)
	# Stay out of the minimap and bottom skill rail.
	if anchor.x > viewport.x - 230: anchor.y = minf(anchor.y, viewport.y - 280)
	# Screen-space direction marker: fixed dimensions, tinted by encounter kind.
	draw_set_transform(anchor, direction.angle())
	var arrow = PackedVector2Array([Vector2(-11, -9), Vector2(13, 0), Vector2(-11, 9), Vector2(-5, 0)])
	draw_colored_polygon(arrow, color)
	arrow.append(arrow[0])
	draw_polyline(arrow, INK, 2.0, true)
	draw_set_transform(Vector2.ZERO)
