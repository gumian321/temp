extends "res://scripts/build_grid_ui.gd"
## Drag whole elements into gaps in the chain; every element grows one segment.
const ChainMount = preload("res://scripts/chain_mount_control.gd")
const ASSEMBLY_FACING = PI
const UI=preload("res://scripts/game_ui.gd")
var chain_scroll: ScrollContainer
var inventory_scroll: ScrollContainer
var insert_targets: Dictionary = {}
var health_label: Label
var description_label: Label
var guidance: Label
var landing_segment = -1
var landing_left = 0.0
var drag_cancelled = false
var scroll_remainder = 0.0
var drag_pointer = Vector2.ZERO

func setup(owner_game):
	game=owner_game;player=game.player;db=game.db;theme=UI.theme();UI.protect(self)
	size=Vector2(1440,900);mouse_filter=Control.MOUSE_FILTER_IGNORE
	selected_segment=clampi(game.build_selected_segment,0,player.segment_count())
	if game.reward_flow_active and not player.pending.is_empty():
		selected_data={"kind":"inventory","index":0,"id":player.pending[0]}
	rebuild()

func chain_mount(parent:Node,extent:Vector2,target:Dictionary,data:Dictionary={},icon:Texture2D=null,title:String=""):
	var control=ChainMount.new();control.custom_minimum_size=extent
	parent.add_child(control);control.setup(self,target,data,icon,title)
	return control

func rebuild():
	rebuilding=true
	var previous_scroll=chain_scroll.scroll_horizontal if is_instance_valid(chain_scroll) else 0
	var previous_inventory_scroll=inventory_scroll.scroll_vertical if is_instance_valid(inventory_scroll) else 0
	for child in get_children():remove_child(child);child.queue_free()
	inventory.clear();slots.clear();segment_buttons.clear();insert_targets.clear()
	var title=text_at("蜕变舱" if game.reward_flow_active else "虫巢武装",Vector2(65,35),Vector2(600,58),38)
	var capacity=text_at("%02d / 60"%player.segment_count(),Vector2(1200,42),Vector2(170,36),24)
	var subtitle=text_at("1 元素 = 1 体节    ·    拖入 + 生长",Vector2(65,106),Vector2(900,30),17)
	text_at("待装  ·  %02d"%player.pending.size(),Vector2(72,527),Vector2(280,36),22)
	var scroll=ScrollContainer.new();scroll.position=Vector2(72,579);scroll.size=Vector2(652,186)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	inventory_scroll=scroll;scroll.set_deferred("scroll_vertical",previous_inventory_scroll)
	var list=GridContainer.new();list.columns=5;list.add_theme_constant_override("h_separation",17);list.add_theme_constant_override("v_separation",14);scroll.add_child(list)
	for i in player.pending.size():
		var core=db.asset(player.pending[i])
		var control=chain_mount(list,Vector2(110,136),{"kind":"inventory","index":i},{"kind":"inventory","index":i,"id":core.id},db.core_sprite(core),db.title(core))
		control.selected=selected_data.get("kind")=="inventory" and int(selected_data.get("index",-1))==i
		inventory.append(control)
	if player.pending.is_empty():
		text_at("暂无待装元素",Vector2(250,607),Vector2(420,40),23)
		text_at("战斗 → 奖励 → 生长",Vector2(250,655),Vector2(400,36),17)
	reward_button=action_button("奖励  %d"%game.run.packs,Vector2(582,526),Vector2(140,44),game.show_rewards,not player.pending.is_empty())
	reward_button.tooltip_text="选择奖励";reward_button.visible=game.run.packs>0
	text_at("身体序列",Vector2(72,174),Vector2(280,34),21)
	text_at("头部 → 尾部",Vector2(1200,174),Vector2(170,30),16)
	chain_scroll=ScrollContainer.new();chain_scroll.position=Vector2(72,218);chain_scroll.size=Vector2(1296,256)
	chain_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	chain_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;add_child(chain_scroll)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",0);chain_scroll.add_child(row)
	chain_mount(row,Vector2(128,238),{"kind":"head"},{},null,"头部")
	for before in range(1,player.segment_count()+2):
		var tail=before==player.segment_count()+1
		var extent=Vector2(222 if player.segment_count()==0 else (104 if tail else 44),238)
		var gap=chain_mount(row,extent,{"kind":"gap","before":before},{},null,"新增体节" if tail else "插入此处")
		insert_targets[before]=gap
		if tail:tail_target=gap;continue
		var index=player.part_at(before)
		var part:Dictionary=player.parts[index]
		var core=db.asset(part.id)
		var control=chain_mount(row,Vector2(126,238),{"kind":"segment","segment":before},{"kind":"mounted","part":part},db.core_sprite(core),db.title(core))
		control.selected=(selected_data.get("kind")!="inventory" and before==selected_segment)
		segment_buttons[before]=control
	chain_scroll.set_deferred("scroll_horizontal",previous_scroll)
	guidance=text_at("+ 插入    ⇄ 交换    右键取消",Vector2(780,106),Vector2(580,30),16)
	detail=text_at("",Vector2(1000,534),Vector2(350,65),25)
	health_label=text_at("",Vector2(1000,608),Vector2(350,32),19)
	description_label=text_at("",Vector2(1000,658),Vector2(350,92),17)
	armor_button=action_button("加固  %d"%player.actions.wall,Vector2(806,724),Vector2(165,43),reinforce_selected)
	hint=text_at("",Vector2(48,825),Vector2(1040,42),17);hint.add_theme_color_override("font_color",UI.RED);hint.visible=false
	return_button=action_button("出击  →",Vector2(1170,812),Vector2(190,52),game.finish_building,not player.pending.is_empty())
	return_button.tooltip_text="手动返回战斗 · E / Esc"
	if game.reward_flow_active:
		action_button("稍后安装",Vector2(1008,812),Vector2(142,52),game.postpone_rewards)
	rebuilding=false;inspect({});queue_redraw()
	apply_local_styles.call_deferred(title,subtitle,capacity)

func apply_local_styles(title:Label,subtitle:Label,capacity:Label):
	if not is_instance_valid(title) or not is_instance_valid(return_button):return
	title.add_theme_color_override("font_color",UI.TEXT)
	subtitle.add_theme_color_override("font_color",UI.MUTED)
	capacity.add_theme_color_override("font_color",UI.AMBER)
	return_button.add_theme_stylebox_override("normal",UI.Art.skin("active"))
	return_button.add_theme_stylebox_override("hover",UI.Art.skin("active"))
	return_button.add_theme_color_override("font_color",UI.TEXT)
	return_button.add_theme_color_override("font_hover_color",UI.TEXT)

func _process(dt:float):
	super._process(dt)
	if landing_left>0:
		landing_left=maxf(0,landing_left-dt)
		if segment_buttons.has(landing_segment):segment_buttons[landing_segment].queue_redraw()
	if is_instance_valid(chain_scroll) and get_viewport().gui_is_dragging():
		var pointer=drag_pointer
		var bounds=chain_scroll.get_global_rect()
		# Restricted to the rail; pointing at inventory must not scroll the body.
		if bounds.grow(24).has_point(pointer):
			var speed=0.0
			if pointer.x<bounds.position.x+72:speed=-780*clampf((bounds.position.x+72-pointer.x)/72,0,1)
			elif pointer.x>bounds.end.x-72:speed=780*clampf((pointer.x-bounds.end.x+72)/72,0,1)
			scroll_remainder+=speed*dt
			var pixels=int(scroll_remainder)
			chain_scroll.scroll_horizontal+=pixels;scroll_remainder-=pixels

func _input(event):
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		drag_pointer=get_canvas_transform().affine_inverse()*event.position
	if not active_drag_data.is_empty() and ((event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT)):
		drag_cancelled=true
		get_viewport().set_input_as_handled()
		guidance.text="已取消 · 松开鼠标，元素保留在原位"
		refresh_controls()

func refresh_controls():
	for control in inventory:
		control.selected=selected_data.get("kind")=="inventory" and int(selected_data.get("index",-1))==int(control.target.index)
		control.queue_redraw()
	for segment in segment_buttons:
		var control=segment_buttons[segment]
		control.selected=selected_data.get("kind")!="inventory" and segment==selected_segment
		control.queue_redraw()
	for control in insert_targets.values():control.queue_redraw()
	inspect({})

func cancel_selection():
	selected_data={};inspected_data={};hovered_target={};selected_segment=0
	refresh_controls()

func shown_data()->Dictionary:
	if not active_drag_data.is_empty():return active_drag_data
	if not inspected_data.is_empty():return inspected_data
	if not selected_data.is_empty():return selected_data
	var index=player.part_at(selected_segment)
	return {"kind":"mounted","part":player.parts[index]} if index>0 else {}

func _draw():
	if player==null:return
	draw_rect(Rect2(0,0,1440,900),UI.BG)
	for i in 18:
		draw_line(Vector2(i*100,0),Vector2(i*100-300,900),Color(UI.TEAL,.028),1,true)
	draw_line(Vector2(65,93),Vector2(1380,93),Color(UI.TEAL,.22),1,true)
	draw_line(Vector2(65,93),Vector2(205,93),UI.TEAL,3,true)
	draw_style_box(UI.style(UI.PANEL,Color(UI.TEAL,.24),22),Rect2(32,145,1376,344))
	draw_style_box(UI.style(UI.PANEL,Color(UI.TEAL,.16),22),Rect2(32,501,724,292))
	draw_style_box(UI.style(UI.PANEL,Color(UI.TEAL,.16),22),Rect2(780,501,628,292))
	draw_arc(Vector2(906,624),74,0,TAU,64,Color(UI.TEAL,.22),2,true)
	for i in 12:
		var a=i*TAU/12
		draw_line(Vector2(906,624)+Vector2.from_angle(a)*78,Vector2(906,624)+Vector2.from_angle(a)*84,Color(UI.TEAL,.36),2,true)
	if player.pending.is_empty():
		draw_head(self,Vector2(154,650),1.1)
	var data=shown_data()
	var core=db.asset(data.get("id",data.get("part",{}).get("id","")))
	if core.is_empty():
		draw_head(self,Vector2(906,624),1.4)
	else:
		if int(data.get("part",{}).get("segment",-1))==player.segment_count():Art.tail(self,Vector2(906,624),ASSEMBLY_FACING,1.7)
		Art.segment(self,Vector2(906,624),ASSEMBLY_FACING,1.7,0,false)
		var texture=db.core_sprite(core)
		if texture!=null:
			draw_element(self,texture,Vector2(906,617),1.7)

func draw_head(canvas:CanvasItem,at:Vector2,scale_factor:float):
	if player.segment_count()==0:Art.tail(canvas,at,ASSEMBLY_FACING,scale_factor,true)
	Art.segment(canvas,at,ASSEMBLY_FACING,scale_factor,0,true)

func draw_element(canvas:CanvasItem,texture:Texture2D,at:Vector2,scale_factor:float):
	var extent=Ink.fitted_size(texture,Vector2.ONE*56*scale_factor)
	canvas.draw_set_transform(at,ASSEMBLY_FACING+PI/2)
	canvas.draw_texture_rect(texture,Rect2(-extent/2,extent),false)
	canvas.draw_set_transform(Vector2.ZERO)

func draw_segment(canvas:CanvasItem,segment:int,at:Vector2,scale_factor:float=0.95,_additional:int=0):
	if segment==player.segment_count():Art.tail(canvas,at,ASSEMBLY_FACING,scale_factor)
	Art.segment(canvas,at,ASSEMBLY_FACING,scale_factor,0,false)
	var index=player.part_at(segment)
	if index<1:return
	var texture=db.core_sprite(db.asset(player.parts[index].id))
	if texture==null:return
	var center=at+player.display_slot_offset(segment).rotated(ASSEMBLY_FACING)*scale_factor
	draw_element(canvas,texture,center,scale_factor)

func inspect(data:Dictionary):
	if rebuilding:return
	inspected_data=data
	var shown=shown_data()
	var core=db.asset(shown.get("id",shown.get("part",{}).get("id","")))
	if core.is_empty():
		detail.text="虫群中枢"
		health_label.text="独立甲壳 · 协同攻击"
		description_label.text="选择元素查看性能\n拖动体节调整阵型"
	else:
		detail.text=db.title(core)
		detail.tooltip_text=db.title(core)+"\n"+db.armament_description(core)
		var part:Dictionary=shown.get("part",{})
		health_label.text="甲壳  %d / %d"%[maxf(0,part.hp),part.max_hp] if not part.is_empty() else "甲壳  %d"%float(core.get("CoreHealth",90))
		if core.has("coreProjectile"):
			var projectile=db.asset(core.coreProjectile)
			description_label.text="伤害  %.1f    频率  %.1f/s\n射程  %.0f"%[float(projectile.get("projectileDamage",{}).get("hullDamage",0)),float(core.get("turretRateOfFire",0)),db.range_units(core.get("turretRange",1))*48]
		else:description_label.text=db.armament_description(core)
		description_label.max_lines_visible=3;description_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	armor_button.visible=selected_data.get("kind")=="mounted" and not game.reward_flow_active
	armor_button.disabled=player.actions.wall<=0 or selected_data.get("part",{}).get("wall",false)
	queue_redraw()

func begin_drag(data:Dictionary):
	drag_cancelled=false;active_drag_data=data;drag_pointer=get_global_mouse_position();inspect(data)
	guidance.text="+ 插入    ⇄ 交换    边缘滚动    ESC 取消"
	refresh_controls()

func end_drag():
	active_drag_data={};inspected_data={};hovered_target={};inspect({})
	guidance.text="+ 插入    ⇄ 交换    右键取消"
	drag_cancelled=false;refresh_controls()

func hover_mount(target:Dictionary):
	if rebuilding:return
	if hovered_target==target:return
	hovered_target=target
	for control in insert_targets.values():control.queue_redraw()
	for control in segment_buttons.values():control.queue_redraw()
	queue_redraw()

func can_drop(target:Dictionary,data:Dictionary)->bool:
	if drag_cancelled:return false
	if target.get("kind")=="swap":
		if data.get("kind")!="mounted":return false
		var index=player.parts.find(data.get("part",{}))
		var other=player.part_at(int(target.get("segment",-1)))
		return index>0 and other>0 and index!=other
	if target.get("kind")!="gap":return false
	var before=int(target.get("before",-1))
	if before<1 or before>player.segment_count()+1:return false
	if data.get("kind")=="inventory":
		var index=int(data.get("index",-1))
		return index>=0 and index<player.pending.size() and player.pending[index]==data.get("id") and player.segment_count()<60
	if data.get("kind")=="mounted":
		var index=player.parts.find(data.get("part",{}))
		if index<=0:return false
		var segment=int(player.parts[index].segment)
		return before!=segment and before!=segment+1
	return false

func drop(target:Dictionary,data:Dictionary):
	if not can_drop(target,data):toast("请选择身体间的 + 号，或拖到尾部。");return
	var before=int(target.get("before",-1))
	var changed=false
	var part:Dictionary={}
	if data.kind=="inventory":
		changed=player.install_module(data.id,before)
		if changed:
			player.pending.remove_at(int(data.index));part=player.parts[player.part_at(before)]
	else:
		part=data.part
		if target.get("kind")=="swap":changed=player.swap_piece(player.parts.find(part),player.part_at(int(target.segment)))
		else:changed=player.move_to_mount(player.parts.find(part),before)
	if not changed:toast(player.last_error);return
	selected_segment=int(part.segment);game.build_selected_segment=selected_segment
	landing_segment=selected_segment;landing_left=0.65
	selected_data={};inspected_data={};active_drag_data={};hovered_target={}
	game.audio_system.play(70)
	if game.reward_flow_active:game.reward_placement_changed.call_deferred()
	else:rebuild.call_deferred()
	game.queue_redraw()

func click(target:Dictionary,data:Dictionary):
	if target.get("kind")=="inventory":selected_data=data.duplicate();refresh_controls()
	elif target.get("kind")=="gap" and not selected_data.is_empty():drop(target,selected_data)
	elif target.get("kind")=="segment":
		selected_segment=int(target.segment);game.build_selected_segment=selected_segment
		selected_data=data.duplicate();refresh_controls()

func show_segment_during_drag(_segment:int):pass

func action_button(title: String, at: Vector2, extent: Vector2, callback: Callable, disabled: bool = false) -> Button:
	var button=Button.new();button.text=title;button.position=at;button.size=extent;button.disabled=disabled
	button.add_theme_font_size_override("font_size",19)
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,UI.focus_style() if state=="focus" else UI.Art.skin("normal" if state in ["normal","disabled"] else "active",8))
	button.pressed.connect(callback);add_child(button);return button
