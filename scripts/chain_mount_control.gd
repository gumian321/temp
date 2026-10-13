extends "res://scripts/build_mount_control.gd"

func _draw():
	var kind=target.get("kind","")
	var carried=builder.active_drag_data if not builder.active_drag_data.is_empty() else builder.selected_data
	var candidate=not carried.is_empty() and builder.can_drop(target,carried)
	var edge=Ink.BLUE if selected or hovering else Color("bfccd7")
	if hovering and not drop_valid:edge=Color("b45846")
	if kind=="gap":
		draw_line(Vector2(0,83),Vector2(size.x,83),Color(Ink.MUTED,0.4),3,true)
		if candidate or hovering:
			draw_style_box(Ink.box(Color("e3efeb") if drop_valid else Color("f3e2dc"),edge,2),Rect2(Vector2(2,21),size-Vector2(4,29)))
		Symbols.draw(self,"add",Vector2(size.x/2,83),0.6 if size.x<60 else 1.1,edge)
		if size.x>=60:
			draw_string(Ink.theme().default_font,Vector2(6,159),"新增体节",HORIZONTAL_ALIGNMENT_CENTER,size.x-12,17,Ink.INK)
		return
	if kind=="head":
		builder.draw_head(self,Vector2(size.x/2,83),0.9)
		draw_string(Ink.theme().default_font,Vector2(4,159),"头部",HORIZONTAL_ALIGNMENT_CENTER,size.x-8,17,Ink.INK)
		return
	if kind=="segment":
		if selected or hovering:
			draw_style_box(Ink.box(Color(Ink.WASH,0.52),edge,2),Rect2(Vector2(4,12),size-Vector2(8,15)))
		draw_string(Ink.theme().default_font,Vector2(13,28),"%02d"%int(target.segment),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Ink.MUTED)
		builder.draw_segment(self,int(target.segment),Vector2(size.x/2,83),1.1)
		draw_string(Ink.theme().default_font,Vector2(5,159),caption,HORIZONTAL_ALIGNMENT_CENTER,size.x-10,16,Ink.INK)
		var part:Dictionary=payload.get("part",{})
		if not part.is_empty():
			draw_rect(Rect2(14,173,size.x-28,5),Ink.WASH)
			draw_rect(Rect2(14,173,(size.x-28)*clampf(float(part.hp)/maxf(1,part.max_hp),0,1),5),Ink.BLUE)
			draw_string(Ink.theme().default_font,Vector2(9,196),"%d / %d"%[maxf(0,part.hp),part.max_hp],HORIZONTAL_ALIGNMENT_CENTER,size.x-18,13,Ink.MUTED)
		var hovered:Dictionary=builder.hovered_target
		if get_viewport().gui_is_dragging() and hovered.get("kind")=="gap" and int(hovered.get("before",-1)) in [int(target.segment),int(target.segment)+1]:
			var x=3 if int(hovered.before)==int(target.segment) else size.x-3
			draw_line(Vector2(x,20),Vector2(x,size.y-10),Color("4b9a8f"),4,true)
		return
	super._draw()

func drop_destination(at:Vector2)->Dictionary:
	if target.get("kind")=="segment":
		return {"kind":"gap","before":int(target.segment)+(1 if at.x>=size.x*0.5 else 0)}
	return target

func _can_drop_data(at:Vector2,data)->bool:
	var destination=drop_destination(at)
	drop_valid=data is Dictionary and builder.can_drop(destination,data)
	builder.hover_mount(destination);queue_redraw()
	return drop_valid

func _drop_data(at:Vector2,data):builder.drop(drop_destination(at),data)
