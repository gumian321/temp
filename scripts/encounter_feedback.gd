extends Node2D
## A few bounded world markers, above fire effects and below the HUD.
const UI = preload("res://scripts/game_ui.gd")
const Art = preload("res://scripts/encounter_art.gd")
const COLORS = {"charger": Color("ff6c89"), "broodmother": Color("bca0ff"), "treasure": Color("ffd16f"), "hatchling": Color("bca0ff")}
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
			var scale = (65 + 25 * director.warning_left / director.WARNING_TIME) * zoom
			stamp("warning_seal", at, Vector2.ONE * scale, 0, color)
			caption(at + Vector2(0, -48 * zoom), game.db.ui("INCOMING", "即将出现"), color)
	for e in game.combat.enemies:
		if not e.has("encounter_type") or e.hp <= 0 or e.get("despawn", false): continue
		var color: Color = COLORS[e.encounter_type]
		var at: Vector2 = game.world(e.position)
		if e.encounter_type != "hatchling": pointer(at, color, viewport)
		if not Rect2(Vector2.ZERO, viewport).grow(130).has_point(at): continue
		var radius = float(e.radius) * zoom * 1.6 + 4
		if e.encounter_type == "hatchling": continue
		stamp("warning_seal", at, Vector2.ONE * radius * 2.2, 0, Color(color, 0.7))
		var text: String = {"charger": game.db.ui("LANCER", "冲锋虫"), "broodmother": game.db.ui("BROODMOTHER", "裂殖母虫"), "treasure": game.db.ui("TREASURE", "藏宝虫")}[e.encounter_type]
		if e.encounter_type == "charger":
			if e.encounter_phase in ["windup", "dash"]:
				var direction: Vector2 = e.charge_direction
				var length = 352.0 if e.encounter_phase == "windup" else maxf(0, e.phase_left) * 640
				stamp("charge_lane", at + direction * length * zoom * .5, Vector2(length, float(e.radius) * 2) * zoom, direction.angle(), Color(1, 1, 1, .8))
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
	stamp("charge_lane", anchor, Vector2(36, 14), direction.angle(), Color.WHITE)
