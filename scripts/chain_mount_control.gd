extends "res://scripts/build_mount_control.gd"
const DragPreview=preload("res://scripts/chain_drag_preview.gd")
const UI=preload("res://scripts/game_ui.gd")
const TEAL=UI.TEAL
var hover_amount=0.0

func _process(dt):
	var goal=1.0 if hovering else 0.0
	if absf(hover_amount-goal)>0.01:
		hover_amount=move_toward(hover_amount,goal,dt*9);queue_redraw()

func label_at(text:String,y:float,px:int=16,color:Color=UI.TEXT):
	var font=UI.theme().default_font
	var shown=text
	while shown.length()>1 and font.get_string_size(shown,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x>size.x-14:
		shown=shown.left(shown.length()-2)+"…"
	draw_string(font,Vector2(7,y),shown,HORIZONTAL_ALIGNMENT_CENTER,size.x-14,px,color)

func _draw():
	var kind=target.get("kind","")
	var carried=builder.active_drag_data if not builder.active_drag_data.is_empty() else builder.selected_data
	var candidate=not carried.is_empty() and builder.can_drop(target,carried)
	var destination:Dictionary=builder.hovered_target
	var landing=destination==target and builder.can_drop(target,carried)
	if kind=="gap":
		draw_line(Vector2(0,104),Vector2(size.x,104),Color(UI.MUTED,0.32),2,true)
		var active=landing or (destination.get("kind")=="gap" and destination.get("before")==target.before and builder.can_drop(destination,carried))
		var bounds=Rect2(Vector2(4,24),Vector2(size.x-8,169))
		var style=UI.card_style(active or candidate)
		if size.x>=60:draw_style_box(style,bounds)
		draw_texture_rect(UI.icon_texture("body"),Rect2(Vector2(size.x/2-16,88),Vector2(32,32)),false)
		if active:
			draw_line(Vector2(size.x/2,31),Vector2(size.x/2,69),TEAL,3,true)
			draw_line(Vector2(size.x/2,139),Vector2(size.x/2,184),TEAL,3,true)
		if size.x>=60:
			label_at("插入" if active else "生长",166,17,TEAL if candidate else UI.MUTED)
		return
	if kind=="head":
		builder.draw_head(self,Vector2(size.x/2,104),0.85)
		label_at("头部",187,16,UI.MUTED)
		return
	if kind=="segment":
		var swap=destination.get("kind")=="swap" and int(destination.get("segment",-1))==int(target.segment) and builder.can_drop(destination,carried)
		var source=not builder.active_drag_data.is_empty() and builder.active_drag_data.get("part",{})==payload.get("part",{})
		var style=UI.card_style(swap or selected or has_focus())
		draw_style_box(style,Rect2(Vector2(2,13-hover_amount*3),Vector2(size.x-4,218)))
		draw_string(UI.font(),Vector2(20,49-hover_amount*3),"%02d"%int(target.segment),HORIZONTAL_ALIGNMENT_LEFT,-1,16,UI.TEXT if selected or swap else UI.MUTED)
		if selected:draw_circle(Vector2(size.x-23,39-hover_amount*3),3,UI.AMBER,true,-1,true)
		if payload.get("part",{}).get("wall",false):draw_texture_rect(UI.icon_texture("armor"),Rect2(size.x-42,27,28,28),false)
		var pulse=builder.landing_left if int(target.segment)==builder.landing_segment else 0.0
		if pulse>0:
			draw_arc(Vector2(size.x/2,104),43+(1-pulse/0.65)*14,0,TAU,48,Color(TEAL,pulse/0.65),3,true)
		if source:
			draw_circle(Vector2(size.x/2,104),34,Color(UI.MUTED,0.12),true,-1,true)
			label_at("正在移动",110,16,UI.MUTED)
		else:builder.draw_segment(self,int(target.segment),Vector2(size.x/2,104-hover_amount*3),1.2+sin(pulse/0.65*PI)*0.12)
		label_at("交换" if swap else caption,175,16,TEAL if swap else UI.TEXT)
		var part:Dictionary=payload.get("part",{})
		if not part.is_empty():
			var hp=clampf(float(part.hp)/maxf(1,part.max_hp),0,1)
			draw_rect(Rect2(16,191,size.x-32,4),Color(UI.MUTED,0.18))
			draw_rect(Rect2(16,191,(size.x-32)*hp,4),TEAL if hp>0.3 else UI.RED)
			label_at("%d / %d"%[maxf(0,part.hp),part.max_hp],216,16,UI.MUTED)
		if destination.get("kind")=="gap" and int(destination.get("before",-1)) in [int(target.segment),int(target.segment)+1] and builder.can_drop(destination,carried):
			var x=2 if int(destination.before)==int(target.segment) else size.x-2
			draw_line(Vector2(x,23),Vector2(x,222),TEAL,4,true)
		return
	if kind=="inventory":
		var style=UI.card_style(selected or has_focus())
		draw_style_box(style,Rect2(Vector2(1,1),size-Vector2(2,3)))
		if icon!=null:
			var extent=Ink.fitted_size(icon,Vector2(78,78))
			draw_texture_rect(icon,Rect2(Vector2(size.x/2,53-hover_amount*3)-extent/2,extent),false)
		label_at(caption,117,16)
		return
	super._draw()

func _get_drag_data(at:Vector2):
	if payload.is_empty():return null
	var preview=DragPreview.new();preview.builder=builder;preview.texture=icon
	# Preserve the pickup point near the artwork, but keep the target readable.
	var center=Vector2(size.x/2,104 if target.get("kind")=="segment" else 53)
	preview.anchor=(center-at).clamp(Vector2(-32,-40),Vector2(32,24))
	set_drag_preview(preview)
	builder.begin_drag(payload.duplicate())
	queue_redraw()
	return payload.duplicate()

func drop_destination(at:Vector2,data:Dictionary={})->Dictionary:
	if target.get("kind")=="segment":
		if data.is_empty():data=builder.active_drag_data
		if data.get("kind")=="mounted" and at.x>size.x*0.25 and at.x<size.x*0.75:
			return {"kind":"swap","segment":int(target.segment)}
		return {"kind":"gap","before":int(target.segment)+(1 if at.x>=size.x*0.5 else 0)}
	return target

func _can_drop_data(_at:Vector2,data)->bool:
	# Rendered drag callbacks can supply stale local coordinates. Resolve the
	# latest delivered pointer in this card's space for preview/drop agreement.
	var local=get_global_transform().affine_inverse()*builder.drag_pointer
	var destination=drop_destination(local,data if data is Dictionary else {})
	drop_valid=Rect2(Vector2.ZERO,size).has_point(local) and data is Dictionary and builder.can_drop(destination,data)
	builder.hover_mount(destination);queue_redraw()
	return drop_valid

func _drop_data(_at:Vector2,data):
	var local=get_global_transform().affine_inverse()*builder.drag_pointer
	if Rect2(Vector2.ZERO,size).has_point(local):builder.drop(drop_destination(local,data),data)

func _notification(what):
	# The viewport broadcasts drag end to every card. Settle the shared state once.
	if what==NOTIFICATION_DRAG_END and is_instance_valid(builder) and not builder.active_drag_data.is_empty():
		builder.end_drag()
