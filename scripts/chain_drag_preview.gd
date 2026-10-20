extends Control
## A lightweight native cursor preview. The pointer owns its position, never a tween.
const Ink=preload("res://scripts/blue_ink.gd")
const UI=preload("res://scripts/game_ui.gd")
const Art=preload("res://scripts/centipede_art.gd")
var builder
var texture:Texture2D
var anchor=Vector2.ZERO
var clock=0.0
var organs=preload("res://scripts/soft_organ_art.gd").new()
var flagella=preload("res://scripts/flagella.gd").new()
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(dt):
	clock+=dt
	if is_instance_valid(builder):
		var part:Dictionary=builder.active_drag_data.get("part",{})
		var level=int(part.get("fusion_level",1))
		if level>1:flagella.step(0,builder.drag_pointer,PI,Art.Flagella.fusion_count(level),false,dt,clock)
	queue_redraw()
func _draw():
	if not is_instance_valid(builder):return
	var at=anchor
	var scale_factor=builder.body_canvas.zoom if is_instance_valid(builder.body_canvas) else 1.2
	draw_circle(at+Vector2(0,8),29*scale_factor,Color(UI.BG,0.3),true,-1,true)
	Art.Flagella.paint(self,flagella.poses(0),at,PI,scale_factor,true)
	if builder.player.character_id=="centipede":Art.segment(self,at,PI,scale_factor,clock*3,false)
	else:
		var spider=preload("res://scripts/spider_art.gd")
		spider.prepare();draw_texture_rect(spider.pieces.segment,Rect2(at-Vector2(30,21)*scale_factor,Vector2(60,42)*scale_factor),false)
	var data:Dictionary=builder.active_drag_data
	var core=builder.db.asset(data.get("id",data.get("part",{}).get("id","")))
	organs.begin_frame()
	organs.paint(self,"preview",texture,at,builder.element_bounds(scale_factor,data.get("part",{})),PI*1.5,builder.db.Armaments.variant(builder.db,core),clock,0,Color.WHITE,float(data.get("part",{}).get("feedback_uid",0)))
	var target:Dictionary=builder.hovered_target
	var valid=builder.can_drop(target,builder.active_drag_data)
	var caption="松开取消"
	if valid:
		caption="让位插入" if target.get("kind")=="gap" else "调整位置"
		if target.get("kind")=="merge":
			var level=int(builder.player.parts[builder.player.part_at(int(target.segment))].get("fusion_level",1))+1
			caption="合成%d阶 · 攻击×2.2"%level
	var tint=UI.TEAL if valid else UI.MUTED
	var style=UI.flat_style(Color("160b1e",0.94),tint,16)
	draw_style_box(style,Rect2(at+Vector2(-104,36*scale_factor+12),Vector2(208,32)))
	draw_string(UI.font(),at+Vector2(-100,36*scale_factor+34),caption,HORIZONTAL_ALIGNMENT_CENTER,200,16,tint)
