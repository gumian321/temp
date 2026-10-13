extends Button
const Ink = preload("res://scripts/blue_ink.gd")
const Symbols = preload("res://scripts/build_symbols.gd")
var symbol = "copy"
var count = 0
var active = false
func _draw():
	var color = Ink.MUTED if disabled else Ink.INK
	Symbols.draw(self,symbol,Vector2(30,size.y*0.5),1.0,color)
	draw_string(Ink.theme().default_font,Vector2(53,size.y*0.5+7),str(count),HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
	if active: draw_style_box(Ink.box(Color.TRANSPARENT,Ink.BLUE,3),Rect2(Vector2.ZERO,size))
