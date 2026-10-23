extends Control
## Progress comes from completed world/terrain jobs, never from a timer.
const UI = preload("res://scripts/game_ui.gd")
var progress: ProgressBar
var status: Label
var percent: Label
var history: Array = []
var cave = true

func _ready():
	UI.protect(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background = ColorRect.new(); background.color = UI.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var center_box = CenterContainer.new(); add_child(center_box)
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content = VBoxContainer.new(); center_box.add_child(content)
	content.custom_minimum_size = Vector2(640, 200)
	content.add_theme_constant_override("separation", 22)
	var title = Label.new(); title.text = "正在进入矿洞" if cave else "正在进入战场"; title.add_theme_font_override("font", UI.font())
	title.add_theme_font_size_override("font_size", 34); title.add_theme_color_override("font_color", UI.TEXT); content.add_child(title)
	var row = HBoxContainer.new(); content.add_child(row)
	status = Label.new(); status.text = "准备出发"; status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_override("font", UI.font()); status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", UI.MUTED); row.add_child(status)
	percent = Label.new(); percent.text = "0%"; percent.add_theme_font_override("font", UI.font()); percent.add_theme_font_size_override("font_size", 20); row.add_child(percent)
	progress = ProgressBar.new(); progress.custom_minimum_size = Vector2(640, 14); progress.show_percentage = false
	progress.add_theme_stylebox_override("background", UI.flat_style(Color("282827"), Color("444443"), 2))
	progress.add_theme_stylebox_override("fill", UI.flat_style(UI.TEXT, UI.TEXT, 2)); content.add_child(progress)
	var hint = Label.new(); hint.text = "顶住岩壁啃挖 · 矿粒的颜色会指引你" if cave else "拾取能量 · 逐节武装你的虫体"
	hint.add_theme_font_override("font", UI.font()); hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UI.MUTED); content.add_child(hint)
	set_progress(0, "准备出发")

func set_progress(value: float, caption: String):
	progress.value = maxf(progress.value, clampf(value, 0, 100))
	status.text = caption; percent.text = "%d%%" % roundi(progress.value)
	history.append({"progress": progress.value, "status": caption, "at_usec": Time.get_ticks_usec(), "frame": Engine.get_process_frames()})
