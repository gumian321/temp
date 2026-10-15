extends Button
const UI = preload("res://scripts/game_ui.gd")
const Ink = preload("res://scripts/blue_ink.gd")
const Symbols = preload("res://scripts/build_symbols.gd")
var symbol = "copy"
var count = 0
var active = false
func _draw():
	var color = UI.MUTED if disabled else UI.TEXT
	Symbols.draw(self,symbol,Vector2(30,size.y*0.5),1.0,color)
	draw_string(UI.font(),Vector2(53,size.y*0.5+7),str(count),HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
	if active: draw_style_box(UI.flat_style(Color.TRANSPARENT,UI.TEAL,26),Rect2(Vector2.ZERO,size))
