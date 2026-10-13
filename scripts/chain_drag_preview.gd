extends Control
## A lightweight native cursor preview. The pointer owns its position, never a tween.
const Ink=preload("res://scripts/blue_ink.gd")
const Art=preload("res://scripts/centipede_art.gd")
var builder
var texture:Texture2D
var anchor=Vector2.ZERO
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_dt):queue_redraw()
func _draw():
	if not is_instance_valid(builder):return
	var at=anchor
	draw_circle(at+Vector2(0,8),45,Color(Ink.INK,0.12),true,-1,true)
	Art.segment(self,at,PI,1.2,0,false)
	if texture!=null:builder.draw_element(self,texture,at,1.35)
	var target:Dictionary=builder.hovered_target
	var valid=builder.can_drop(target,builder.active_drag_data)
	var caption="松开取消"
	if valid:caption="交换位置" if target.get("kind")=="swap" else "插入这里"
	var tint=Color("36887d") if valid else Ink.MUTED
	var style=Ink.box(Ink.PAPER,tint,2);style.set_corner_radius_all(12)
	draw_style_box(style,Rect2(at+Vector2(-56,54),Vector2(112,30)))
	draw_string(Ink.theme().default_font,at+Vector2(-50,75),caption,HORIZONTAL_ALIGNMENT_CENTER,100,15,tint)
