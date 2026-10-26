extends RefCounted
## Shared print treatment for the title screen and field briefing.
const UI = preload("res://scripts/game_ui.gd")
const PAPER = Color("e8e4d8")
const INK = Color("141514")
const FAINT = Color("424440")
const MUTED = Color("a9aca2")
const ACCENT = Color("e95279")

static func page(parent: Control):
	UI.protect(parent)
	parent.theme = UI.theme()
	var ground = Grain.new()
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ground)

static func label(parent: Control, text: String, rect: Rect2, px: int = 18, color: Color = PAPER) -> Label:
	var node = UI.label(parent, text, rect.position, px, color)
	node.size = rect.size
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return node

static func rule(parent: Control, rect: Rect2, color: Color = FAINT):
	var line = ColorRect.new()
	line.position = rect.position; line.size = rect.size; line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

static func skin(active: bool = false, primary: bool = false) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color("34332f") if primary else (Color("2b2827") if active else Color(0, 0, 0, 0))
	box.border_color = ACCENT if active else FAINT
	box.border_width_bottom = 2 if active else 1
	box.border_width_left = 3 if active else 0
	box.content_margin_left = 18; box.content_margin_right = 18
	box.content_margin_top = 4; box.content_margin_bottom = 4
	return box

static func focus_skin() -> StyleBoxFlat:
	var box = skin(true)
	box.draw_center = false
	box.border_color = PAPER
	box.set_border_width_all(1)
	return box

static func button(parent: Control, text: String, rect: Rect2, callback: Callable, primary: bool = false, px: int = 22) -> Button:
	var node = Button.new()
	node.text = text; node.position = rect.position; node.size = rect.size
	node.custom_minimum_size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", px)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box = skin(state in ["hover", "pressed", "hover_pressed"], primary)
		if state == "disabled": box.bg_color = Color("1b1c1a")
		node.add_theme_stylebox_override(state, box)
	node.add_theme_stylebox_override("focus", focus_skin())
	node.pressed.connect(callback)
	UI.protect(node); parent.add_child(node)
	return node

class Grain extends Control:
	func _ready(): resized.connect(queue_redraw)
	func _draw():
		draw_rect(Rect2(Vector2.ZERO, size), INK)
		# Seeded once per draw: no shimmer, shaders, or full-screen ticking.
		var rng = RandomNumberGenerator.new(); rng.seed = 27041
		for i in 1400:
			var at = Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_line(at, at + Vector2(rng.randf_range(1, 3), 0), Color(PAPER, rng.randf_range(.018, .045)), 1)
