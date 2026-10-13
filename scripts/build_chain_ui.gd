extends "res://scripts/build_grid_ui.gd"
## Drag whole elements into gaps in the chain; every element grows one segment.
const ChainMount = preload("res://scripts/chain_mount_control.gd")
const ASSEMBLY_FACING = PI
var chain_scroll: ScrollContainer
var insert_targets: Dictionary = {}
var health_label: Label
var description_label: Label

func setup(owner_game):
	game=owner_game;player=game.player;db=game.db
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
	for child in get_children():remove_child(child);child.queue_free()
	inventory.clear();slots.clear();segment_buttons.clear();insert_targets.clear()
	text_at("长出新体节" if game.reward_flow_active else "身体装配",Vector2(48,34),Vector2(560,50),34)
	text_at("%d / 60 节"%player.segment_count(),Vector2(1180,47),Vector2(190,32),20)
	text_at("每节一个元素 · 拖到 + 号新增，拖动已有体节调整顺序",Vector2(48,98),Vector2(1220,32),18)
	text_at("待装元素",Vector2(58,206),Vector2(190,36),23)
	text_at(str(player.pending.size()),Vector2(268,212),Vector2(36,28),18)
	var scroll=ScrollContainer.new();scroll.position=Vector2(58,263);scroll.size=Vector2(254,449)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var list=GridContainer.new();list.columns=2;list.add_theme_constant_override("h_separation",14);list.add_theme_constant_override("v_separation",14);scroll.add_child(list)
	for i in player.pending.size():
		var core=db.asset(player.pending[i])
		var control=chain_mount(list,Vector2(110,110),{"kind":"inventory","index":i},{"kind":"inventory","index":i,"id":core.id},db.core_sprite(core),db.title(core))
		control.selected=selected_data.get("kind")=="inventory" and int(selected_data.get("index",-1))==i
		inventory.append(control)
	if player.pending.is_empty():
		text_at("暂无新元素",Vector2(95,395),Vector2(180,32),20)
		text_at("战斗获得奖励包\n选择新元素后，可新增一节",Vector2(70,441),Vector2(231,94),17)
	else:text_at("一个新元素，长出一节身体",Vector2(58,735),Vector2(255,32),17)
	reward_button=action_button("选择奖励（%d）"%game.run.packs,Vector2(58,768),Vector2(254,46),game.show_rewards,not player.pending.is_empty())
	reward_button.visible=game.run.packs>0
	text_at("头部 → 尾部",Vector2(402,207),Vector2(590,34),23)
	text_at("拖动即可换位，不消耗次数",Vector2(1061,211),Vector2(302,30),16)
	chain_scroll=ScrollContainer.new();chain_scroll.position=Vector2(386,265);chain_scroll.size=Vector2(972,258)
	chain_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	chain_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;add_child(chain_scroll)
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",0);chain_scroll.add_child(row)
	chain_mount(row,Vector2(136,206),{"kind":"head"},{},null,"头部")
	for before in range(1,player.segment_count()+2):
		var tail=before==player.segment_count()+1
		var extent=Vector2(222 if player.segment_count()==0 else (96 if tail else 32),206)
		var gap=chain_mount(row,extent,{"kind":"gap","before":before},{},null,"新增体节" if tail else "插入此处")
		insert_targets[before]=gap
		if tail:tail_target=gap;continue
		var index=player.part_at(before)
		var part:Dictionary=player.parts[index]
		var core=db.asset(part.id)
		var control=chain_mount(row,Vector2(138,206),{"kind":"segment","segment":before},{"kind":"mounted","part":part},db.core_sprite(core),db.title(core))
		control.selected=selected_data.get("part",{})==part or before==selected_segment
		segment_buttons[before]=control
	chain_scroll.set_deferred("scroll_horizontal",previous_scroll)
	detail=text_at("",Vector2(647,588),Vector2(645,40),25)
	health_label=text_at("",Vector2(647,636),Vector2(645,32),19)
	description_label=text_at("",Vector2(647,683),Vector2(655,79),17)
	armor_button=action_button("加固体节（%d）"%player.actions.wall,Vector2(1123,757),Vector2(212,43),reinforce_selected)
	hint=text_at("",Vector2(48,825),Vector2(1040,42),17);hint.add_theme_color_override("font_color",Color("b45846"));hint.visible=false
	return_button=action_button("完成调整  →",Vector2(1170,812),Vector2(190,52),game.finish_building,not player.pending.is_empty())
	return_button.tooltip_text="手动返回战斗 · E / Esc"
	if game.reward_flow_active:
		action_button("稍后安装",Vector2(1008,812),Vector2(142,52),game.postpone_rewards)
	rebuilding=false;inspect({});queue_redraw()

func _process(dt:float):
	super._process(dt)
	if is_instance_valid(chain_scroll) and get_viewport().gui_is_dragging():
		var pointer=get_global_mouse_position()
		var bounds=chain_scroll.get_global_rect()
		if pointer.y>bounds.position.y and pointer.y<bounds.end.y:
			if pointer.x<bounds.position.x+48:chain_scroll.scroll_horizontal-=roundi(560*dt)
			elif pointer.x>bounds.end.x-48:chain_scroll.scroll_horizontal+=roundi(560*dt)

func shown_data()->Dictionary:
	if not inspected_data.is_empty():return inspected_data
	if not selected_data.is_empty():return selected_data
	var index=player.part_at(selected_segment)
	return {"kind":"mounted","part":player.parts[index]} if index>0 else {}

func _draw():
	if player==null:return
	var faint=Color(Ink.MUTED,0.24)
	draw_line(Vector2(48,147),Vector2(1360,147),faint,1,true)
	draw_line(Vector2(340,197),Vector2(340,798),faint,1,true)
	draw_style_box(Ink.box(Color(Ink.PAPER,0.75),Color("c6d2db"),1),Rect2(386,566,972,234))
	var data=shown_data()
	var core=db.asset(data.get("id",data.get("part",{}).get("id","")))
	if core.is_empty():
		draw_head(self,Vector2(520,685),1.4)
	else:
		if int(data.get("part",{}).get("segment",-1))==player.segment_count():Art.tail(self,Vector2(520,685),ASSEMBLY_FACING,1.7)
		Art.segment(self,Vector2(520,685),ASSEMBLY_FACING,1.7,0,false)
		var texture=db.core_sprite(core)
		if texture!=null:
			draw_element(self,texture,Vector2(520,678),1.7)

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
		detail.text="从头部开始，逐节生长"
		health_label.text="每节一个元素，各自拥有血量"
		description_label.text="选到新元素后，把它拖到身体间的 + 号。\n体节被打爆时，后面的体节会自动补位。"
	else:
		detail.text=db.title(core)
		var part:Dictionary=shown.get("part",{})
		health_label.text="血量 %d / %d"%[maxf(0,part.hp),part.max_hp] if not part.is_empty() else "新增一节 · 初始血量 %d"%float(core.get("CoreHealth",90))
		if core.has("coreProjectile"):
			var projectile=db.asset(core.coreProjectile)
			description_label.text="伤害 %.1f    射速 %.1f / 秒    射程 %.0f\n拖动整节身体可改变它的前后位置。"%[float(projectile.get("projectileDamage",{}).get("hullDamage",0)),float(core.get("turretRateOfFire",0)),db.range_units(core.get("turretRange",1))*48]
		else:description_label.text="每节一个元素 · 与相邻体节一起协作。\n拖动整节身体可改变它的前后位置。"
	armor_button.visible=selected_data.get("kind")=="mounted" and not game.reward_flow_active
	armor_button.disabled=player.actions.wall<=0 or selected_data.get("part",{}).get("wall",false)
	queue_redraw()

func begin_drag(data:Dictionary):
	active_drag_data=data;inspect(data)
	for control in insert_targets.values():control.queue_redraw()

func end_drag():
	active_drag_data={};inspected_data={};hovered_target={};inspect({})
	for control in insert_targets.values():control.queue_redraw()

func hover_mount(target:Dictionary):
	if rebuilding:return
	hovered_target=target
	queue_redraw()

func can_drop(target:Dictionary,data:Dictionary)->bool:
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
	var before=int(target.before)
	var changed=false
	var part:Dictionary={}
	if data.kind=="inventory":
		changed=player.install_module(data.id,before)
		if changed:
			player.pending.remove_at(int(data.index));part=player.parts[player.part_at(before)]
	else:
		part=data.part;changed=player.move_to_mount(player.parts.find(part),before)
	if not changed:toast(player.last_error);return
	selected_segment=int(part.segment);game.build_selected_segment=selected_segment
	selected_data={};inspected_data={};active_drag_data={};hovered_target={}
	game.audio_system.play(70)
	if game.reward_flow_active:game.reward_placement_changed.call_deferred()
	else:rebuild.call_deferred()
	game.queue_redraw()

func click(target:Dictionary,data:Dictionary):
	if target.get("kind")=="inventory":selected_data=data.duplicate();rebuild.call_deferred()
	elif target.get("kind")=="gap" and not selected_data.is_empty():drop(target,selected_data)
	elif target.get("kind")=="segment":
		selected_segment=int(target.segment);game.build_selected_segment=selected_segment
		selected_data=data.duplicate();rebuild.call_deferred()

func show_segment_during_drag(_segment:int):pass
