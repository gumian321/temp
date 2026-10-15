extends Control
## Native drag source/drop target. Names live in tooltips, not on every card.
const Neon = preload("res://scripts/game_ui.gd")
const Ink = preload("res://scripts/blue_ink.gd")
const Symbols = preload("res://scripts/build_symbols.gd")
var builder
var target: Dictionary = {}
var payload: Dictionary = {}
var icon: Texture2D
var caption = ""
var selected = false
var hovering = false
var drop_valid = true

func setup(owner_ui, destination: Dictionary, data: Dictionary, texture: Texture2D, title: String):
	builder = owner_ui; target = destination; payload = data; icon = texture; caption = title
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func(): hovering=true; builder.inspect(payload); builder.hover_mount(target); queue_redraw())
	mouse_exited.connect(func(): hovering=false; drop_valid=true; builder.inspect({}); builder.hover_mount({}); queue_redraw())
	tooltip_text = caption
	queue_redraw()

func _draw():
	var kind = target.get("kind","")
	var data = builder.active_drag_data if not builder.active_drag_data.is_empty() else builder.selected_data
	var candidate = not data.is_empty() and builder.can_drop(target,data)
	var edge = Neon.RED if hovering and not drop_valid else (Neon.TEAL if selected or hovering else (Color(Neon.TEAL,0.65) if candidate else Color(Neon.TEAL,0.28)))
	var fill = Color(Neon.PANEL,0.92) if selected or hovering else Color(Neon.BG,0.86)
	if candidate: fill = Color("39203d",0.85)
	var style = Neon.flat_style(fill,edge,26)
	style.set_border_width_all(2 if selected or hovering else 1)
	if kind!="segment" or selected or hovering: draw_style_box(style,Rect2(Vector2.ZERO,size))
	if kind=="segment":
		builder.draw_segment(self,int(target.segment),Vector2(size.x*0.5,62))
		draw_string(Neon.font(),Vector2(size.x*0.5-8,19),"%02d" % int(target.segment),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Neon.TEXT if selected else Neon.MUTED)
		for slot in 9:
			var occupied = builder.player.part_at(int(target.segment),slot)>0
			draw_circle(Vector2(size.x*0.5-5+slot%3*5,106+slot/3*3),1.1,Neon.TEAL if occupied else Color(Neon.MUTED,0.2),true,-1,true)
		return
	if icon!=null:
		var extent = Ink.fitted_size(icon,Vector2.ONE*(84 if kind=="slot" else 78))
		draw_texture_rect(icon,Rect2(size*0.5-extent*0.5,extent),false)
		if payload.get("part",{}).get("wall",false): Symbols.draw(self,"armor",size-Vector2(15,15),0.43,Neon.TEAL)
	elif kind in ["slot","tail"]:
		Symbols.draw(self,"add",size*0.5,0.65 if kind=="slot" else 1.4,edge)
		if kind=="slot" and candidate:
			var core = builder.db.asset(data.get("id",data.get("part",{}).get("id","")))
			var ghost = builder.db.core_sprite(core)
			if ghost!=null:
				var extent = Ink.fitted_size(ghost,Vector2.ONE*70)
				draw_texture_rect(ghost,Rect2(size*0.5-extent/2,extent),false,Color(1,1,1,0.2 if not hovering else 0.48))
	# Support reach is drawn directly on its neighboring mounts.
	var inspected = builder.inspected_data if not builder.inspected_data.is_empty() else builder.selected_data
	if kind=="slot" and inspected.get("kind")=="mounted":
		var part: Dictionary = inspected.part
		var source = builder.db.asset(part.id)
		var delta: Vector2i = builder.player.mount_cell(int(target.segment),int(target.slot))-Vector2i(part.cell)
		var linked = absi(delta.x)+absi(delta.y)==1 and (source.has("coreChip") or source.get("class")=="RepairCore")
		if source.get("class")=="ShieldCore":
			var pose = builder.player.segment_pose(int(target.segment))
			var at: Vector2 = Vector2(pose.point)+builder.player.slot_offset(int(target.slot)).rotated(Vector2(pose.direction).angle())
			linked = at.distance_to(part.position)<float(source.get("ShieldRange",0))*48
		if linked:
			draw_style_box(Neon.flat_style(Color(Neon.TEAL,0.12),Neon.TEAL,26),Rect2(Vector2(5,5),size-Vector2(10,10)))

func _get_drag_data(_at: Vector2):
	if payload.is_empty(): return null
	# Godot places the preview root at the cursor. Offset its child so the real
	# weapon is centered under the pointer and matches the highlighted drop slot.
	var preview = Control.new()
	var picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = icon; picture.size = Vector2(82,82)
	preview.add_child(picture)
	picture.position = Vector2(-41,-41); picture.modulate = Color(1,1,1,0.82)
	set_drag_preview(preview)
	builder.begin_drag(payload.duplicate())
	return payload.duplicate()

func _notification(what):
	if what==NOTIFICATION_DRAG_END and builder!=null and is_instance_valid(builder): builder.end_drag()

func _can_drop_data(_at: Vector2, data) -> bool:
	if target.get("kind")=="segment" and data is Dictionary:
		builder.show_segment_during_drag(int(target.segment)); return false
	drop_valid = data is Dictionary and builder.can_drop(target,data)
	builder.hover_mount(target)
	queue_redraw()
	return drop_valid

func _drop_data(_at: Vector2, data): builder.drop(target,data)

func _gui_input(event):
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:
			builder.click(target,payload); accept_event()
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			builder.cancel_selection(); accept_event()
	elif event.is_action_pressed("ui_accept"):
		builder.click(target,payload); accept_event()
