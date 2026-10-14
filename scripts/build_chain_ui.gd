extends "res://scripts/build_grid_ui.gd"
const ASSEMBLY_FACING = PI
const UI=preload("res://scripts/game_ui.gd")
const BodyCanvas=preload("res://scripts/direct_body_canvas.gd")
const TrayIcon=preload("res://scripts/assembly_tray_icon.gd")
class SpiderPreview extends RefCounted:
	var head=Vector2.ZERO
	var facing=Vector2.UP
	var character_reset_serial=0
	var spider_rig=preload("res://scripts/spider_rig.gd").new()
	var counts:Array=[]
	func spider_leg_count(leg:int)->int:return int(counts[leg])

func assembly_guidance()->String:
	if player.character_id=="spider":return "+ 延长腿部    ⇄ 交换    拖到其他腿可转移"
	return "+ 插入    ⇄ 交换    右键取消" if player.character_id=="centipede" else "拖入已占挂点将替换旧模块 · 不可撤销"

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

var body_canvas
var spider_preview
func rebuild():
	rebuilding=true
	var old_zoom=body_canvas.zoom if is_instance_valid(body_canvas) and body_canvas.view_adjusted else 0.0
	var old_pan=body_canvas.pan if is_instance_valid(body_canvas) else Vector2.ZERO
	for child in get_children():remove_child(child);child.queue_free()
	inventory.clear();slots.clear();segment_buttons.clear();insert_targets.clear()
	text_at("身体拼接",Vector2(48,28),Vector2(450,55),36)
	text_at("%02d / %d"%[player.parts.size()-1,player.module_cap()],Vector2(1210,38),Vector2(190,38),25)
	guidance=text_at("拖动元素到身体上的 +  ·  拖动身体模块交换",Vector2(48,89),Vector2(880,34),18)
	if player.character_id=="spider":
		spider_preview=SpiderPreview.new()
		for leg in range(8):spider_preview.counts.append(player.spider_leg_count(leg))
		spider_preview.spider_rig.ensure(spider_preview)
	body_canvas=BodyCanvas.new();body_canvas.position=Vector2(36,137);body_canvas.size=Vector2(1368,492);add_child(body_canvas);body_canvas.setup(self)
	if old_zoom>0:body_canvas.zoom=old_zoom;body_canvas.pan=old_pan;body_canvas.view_adjusted=true;body_canvas.layout_hotspots()
	action_button("−",Vector2(1126,91),Vector2(44,38),func():body_canvas.zoom_at(1/1.2,body_canvas.size/2))
	action_button("+",Vector2(1178,91),Vector2(44,38),func():body_canvas.zoom_at(1.2,body_canvas.size/2))
	action_button("全身",Vector2(1232,91),Vector2(128,38),func():body_canvas.fit())
	text_at("滚轮缩放 · 拖动空白移动",Vector2(48,625),Vector2(420,28),15)
	detail=text_at("",Vector2(500,625),Vector2(320,30),21)
	health_label=text_at("",Vector2(830,625),Vector2(240,30),17)
	description_label=text_at("",Vector2(500,660),Vector2(620,42),16)
	armor_button=action_button("加固  %d"%player.actions.wall,Vector2(1178,639),Vector2(182,42),reinforce_selected)
	text_at("待装  %02d"%player.pending.size(),Vector2(48,701),Vector2(190,30),22)
	inventory_scroll=ScrollContainer.new();inventory_scroll.position=Vector2(222,702);inventory_scroll.size=Vector2(1138,90);inventory_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(inventory_scroll)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);inventory_scroll.add_child(row)
	for i in player.pending.size():
		var control=TrayIcon.new();control.custom_minimum_size=Vector2(76,76);row.add_child(control)
		control.setup(self,{"kind":"inventory","index":i},{"kind":"inventory","index":i,"id":player.pending[i]})
		inventory.append(control)
	if player.pending.is_empty():text_at("战斗中收集元素，为身体继续生长",Vector2(232,725),Vector2(900,36),18)
	reward_button=action_button("奖励  %d"%game.run.packs,Vector2(48,811),Vector2(150,48),game.show_rewards,not player.pending.is_empty());reward_button.visible=game.run.packs>0
	return_button=action_button("出击  →",Vector2(1170,811),Vector2(190,52),game.finish_building,not player.pending.is_empty())
	return_button.tooltip_text="手动返回战斗 · E / Esc"
	if game.reward_flow_active:action_button("稍后安装",Vector2(1004,811),Vector2(148,52),game.postpone_rewards)
	hint=text_at("",Vector2(220,818),Vector2(750,36),17);hint.visible=false
	rebuilding=false;refresh_controls();queue_redraw()
	if not inventory.is_empty():inventory[0].grab_focus.call_deferred()
	elif segment_buttons.has(selected_segment):segment_buttons[selected_segment].grab_focus.call_deferred()
	else:return_button.grab_focus.call_deferred()

func _process(dt:float):
	super._process(dt)
	landing_left=maxf(0,landing_left-dt)

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
	if is_instance_valid(body_canvas):body_canvas.queue_redraw()
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
	draw_rect(Rect2(0,0,1440,900),UI.BG)
	draw_line(Vector2(48,124),Vector2(1392,124),Color(UI.MUTED,0.2),1,true)
	draw_line(Vector2(48,690),Vector2(1392,690),Color(UI.MUTED,0.3),1,true)

func draw_head(canvas:CanvasItem,at:Vector2,scale_factor:float):
	if player.character_id!="centipede":
		var texture=preload("res://scripts/character_art.gd").portrait(player.character_id)
		if texture!=null:canvas.draw_texture_rect(texture,Rect2(at-Vector2.ONE*50*scale_factor,Vector2.ONE*100*scale_factor),false)
		return
	if player.segment_count()==0:Art.tail(canvas,at,ASSEMBLY_FACING,scale_factor,true)
	Art.segment(canvas,at,ASSEMBLY_FACING,scale_factor,0,true)

func draw_element(canvas:CanvasItem,texture:Texture2D,at:Vector2,scale_factor:float):
	var extent=Ink.fitted_size(texture,Vector2.ONE*56*scale_factor)
	canvas.draw_set_transform(at,ASSEMBLY_FACING+PI/2)
	canvas.draw_texture_rect(texture,Rect2(-extent/2,extent),false)
	canvas.draw_set_transform(Vector2.ZERO)

func draw_segment(canvas:CanvasItem,segment:int,at:Vector2,scale_factor:float=0.95,_additional:int=0):
	if player.character_id!="centipede":
		canvas.draw_circle(at,32*scale_factor,Color(UI.TEAL,.1))
		var slot_index=player.part_at(segment)
		if slot_index>0:draw_element(canvas,db.core_sprite(db.asset(player.parts[slot_index].id)),at,scale_factor)
		else:canvas.draw_texture_rect(UI.icon_texture("body"),Rect2(at-Vector2.ONE*18,Vector2.ONE*36),false)
		return
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
		description_label.text=description_label.text.replace("\n","  ·  ")
		description_label.max_lines_visible=1;description_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	armor_button.visible=selected_data.get("kind")=="mounted" and not game.reward_flow_active
	armor_button.disabled=player.actions.wall<=0 or selected_data.get("part",{}).get("wall",false)
	queue_redraw()

func begin_drag(data:Dictionary):
	drag_cancelled=false;active_drag_data=data;drag_pointer=get_global_mouse_position();inspect(data)
	guidance.text=assembly_guidance()+" · ESC 取消"
	refresh_controls()

func end_drag():
	active_drag_data={};inspected_data={};hovered_target={};inspect({})
	guidance.text=assembly_guidance()
	drag_cancelled=false;refresh_controls()

func hover_mount(target:Dictionary):
	if rebuilding:return
	if hovered_target==target:return
	hovered_target=target
	for control in insert_targets.values():control.queue_redraw()
	if is_instance_valid(body_canvas):body_canvas.queue_redraw()
	for control in segment_buttons.values():control.queue_redraw()
	queue_redraw()

func can_drop(target:Dictionary,data:Dictionary)->bool:
	if drag_cancelled:return false
	if target.get("kind")=="mount":
		var mount=int(target.before)
		if mount<1 or mount>player.module_cap():return false
		if player.character_id=="spider":
			var leg=int(player.spider_leg_for_mount(mount))
			var depth=int(player.spider_depth_for_mount(mount))
			var count=int(player.spider_leg_count(leg))
			var occupied=player.part_at(mount)>0
			if data.get("kind")=="inventory":
				var index=int(data.get("index",-1))
				return not occupied and depth==count and count<4 and index>=0 and index<player.pending.size() and player.pending[index]==data.get("id")
			if data.get("kind")!="mounted":return false
			var index=player.parts.find(data.get("part",{}))
			if index<=0 or int(data.part.segment)==mount:return false
			if occupied:return true
			if depth!=count or count>=4:return false
			return int(player.spider_leg_for_mount(int(data.part.segment)))!=leg or int(player.spider_depth_for_mount(int(data.part.segment)))<count-1
		if data.get("kind")=="inventory":return int(data.index)>=0 and int(data.index)<player.pending.size() and player.pending[int(data.index)]==data.id
		return data.get("kind")=="mounted" and player.parts.find(data.get("part",{}))>0 and int(data.part.segment)!=mount
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
		return index>=0 and index<player.pending.size() and player.pending[index]==data.get("id") and player.parts.size()-1<player.module_cap()
	if data.get("kind")=="mounted":
		var index=player.parts.find(data.get("part",{}))
		if index<=0:return false
		var segment=int(player.parts[index].segment)
		return before!=segment and before!=segment+1
	return false

func drop(target:Dictionary,data:Dictionary):
	if not can_drop(target,data):toast("请选择有效挂点。" if player.character_id!="centipede" else "请选择身体间的 + 号，或拖到尾部。");return
	var before=int(target.get("before",-1))
	var changed=false
	var part:Dictionary={}
	if data.kind=="inventory":
		changed=player.install_module(data.id,before)
		if changed:
			player.pending.remove_at(int(data.index));part=player.parts[player.part_at(before)]
	else:
		part=data.part
		if target.get("kind")=="mount" and player.part_at(before)>0:changed=player.swap_piece(player.parts.find(part),player.part_at(before))
		elif target.get("kind")=="swap":changed=player.swap_piece(player.parts.find(part),player.part_at(int(target.segment)))
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
	elif target.get("kind")=="mount":
		if not selected_data.is_empty() and can_drop(target,selected_data):drop(target,selected_data)
		else:selected_segment=int(target.before);game.build_selected_segment=selected_segment;selected_data=data.duplicate();refresh_controls()
	elif target.get("kind")=="gap" and not selected_data.is_empty():drop(target,selected_data)
	elif target.get("kind")=="segment":
		selected_segment=int(target.segment);game.build_selected_segment=selected_segment
		selected_data=data.duplicate();refresh_controls()

func show_segment_during_drag(_segment:int):pass

func action_button(title: String, at: Vector2, extent: Vector2, callback: Callable, disabled: bool = false) -> Button:
	var button=Button.new();button.text=title;button.position=at;button.size=extent;button.disabled=disabled
	button.add_theme_font_size_override("font_size",19)
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,UI.focus_style() if state=="focus" else UI.flat_style(Color(UI.TEAL,0.12) if state in ["hover","pressed"] else Color(UI.BG,0),Color(UI.MUTED,0.32),8))
	button.pressed.connect(callback);add_child(button);return button
