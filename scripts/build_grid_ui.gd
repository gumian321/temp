extends Control
const Neon = preload("res://scripts/game_ui.gd")
const Ink = preload("res://scripts/blue_ink.gd")
const Art = preload("res://scripts/centipede_art.gd")
const Mount = preload("res://scripts/build_mount_control.gd")
const Symbols = preload("res://scripts/build_symbols.gd")
const IconButton = preload("res://scripts/build_icon_button.gd")
const PAGE_SIZE = 8
var game
var player
var db
var slots: Array = []
var inventory: Array = []
var segment_buttons: Dictionary = {}
var tail_target
var hint: Label
var detail: Label
var grid_title: Label
var copy_button: Button
var armor_button: Button
var reward_button: Button
var return_button: Button
var selected_data: Dictionary = {}
var inspected_data: Dictionary = {}
var active_drag_data: Dictionary = {}
var hovered_target: Dictionary = {}
var stat_targets: Array = []
var selected_segment = 1
var copying = false
var page = 0
var toast_left = 0.0
var rebuilding = false

func setup(owner_game):
	game = owner_game
	theme = Neon.theme(); Neon.protect(self)
	player = game.player
	db = game.db
	size = Vector2(1440,900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_segment = clampi(game.build_selected_segment,1,player.segment_count())
	page = (selected_segment-1)/PAGE_SIZE
	if game.reward_flow_active and not player.pending.is_empty():selected_data={"kind":"inventory","index":0,"id":player.pending[0]}
	rebuild()

func text_at(content: String, at: Vector2, extent: Vector2, px: int = 20) -> Label:
	var label = Label.new()
	label.text = content; label.position = at; label.size = extent
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",px)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func action_button(title: String, at: Vector2, extent: Vector2, callback: Callable, disabled: bool = false) -> Button:
	var button = Button.new()
	button.text = title; button.position = at; button.size = extent; button.disabled = disabled
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		var skin=theme.get_stylebox(state,"Button").duplicate()
		skin.content_margin_left=minf(20,extent.x*.15);skin.content_margin_right=minf(20,extent.x*.15)
		button.add_theme_stylebox_override(state,skin)
	button.pressed.connect(callback); add_child(button)
	return button

func icon_button(symbol: String, count: int, at: Vector2, callback: Callable, tip: String) -> Button:
	var button = IconButton.new()
	button.symbol = symbol; button.count = count; button.position = at; button.size = Vector2(94,52)
	button.tooltip_text = tip; button.pressed.connect(callback); add_child(button)
	return button

func make_mount(at: Vector2, extent: Vector2, target: Dictionary, data: Dictionary = {}, icon: Texture2D = null, title: String = ""):
	var control = Mount.new()
	control.position = at; control.size = extent; add_child(control)
	control.setup(self,target,data,icon,title)
	return control

func rebuild():
	rebuilding = true
	for child in get_children():
		remove_child(child); child.queue_free()
	slots.clear(); inventory.clear(); segment_buttons.clear(); stat_targets.clear()
	text_at("安放奖励" if game.reward_flow_active else "武装",Vector2(48,34),Vector2(280,50),34)
	text_at("%d / 60" % (player.parts.size()-1),Vector2(1180,47),Vector2(180,32),20)
	text_at("待装",Vector2(58,230),Vector2(160,36),23)
	text_at(str(player.pending.size()),Vector2(261,236),Vector2(36,28),18)
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(58,288); scroll.size = Vector2(254,412)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list = GridContainer.new(); list.columns = 2
	list.add_theme_constant_override("h_separation",14); list.add_theme_constant_override("v_separation",14)
	scroll.add_child(list)
	for i in player.pending.size():
		var core = db.asset(player.pending[i])
		var control = Mount.new(); control.custom_minimum_size = Vector2(110,110)
		list.add_child(control)
		control.setup(self,{"kind":"inventory","index":i},{"kind":"inventory","index":i,"id":core.id},db.core_sprite(core),db.title(core))
		control.selected = selected_data.get("kind") == "inventory" and int(selected_data.get("index",-1)) == i
		inventory.append(control)
	if player.pending.is_empty():
		text_at("暂无待装",Vector2(126,489),Vector2(150,28),16)
	else:
		text_at("拖入空位",Vector2(157,733),Vector2(145,30),16)
	reward_button = action_button("领奖 · %d" % game.run.packs,Vector2(58,762),Vector2(234,52),game.show_rewards,not player.pending.is_empty())
	reward_button.visible = game.run.packs > 0
	reward_button.tooltip_text = "选择一项奖励" if player.pending.is_empty() else "先放好左边的模块"
	var first = page*PAGE_SIZE+1
	var shown = mini(PAGE_SIZE,player.segment_count()-first+1)
	for segment in range(first,first+shown):
		var c = make_mount(Vector2(454+(segment-first)*100,198),Vector2(94,120),{"kind":"segment","segment":segment},{},null,"体节 %02d" % segment)
		c.selected = segment == selected_segment; segment_buttons[segment] = c
	if player.segment_count() > PAGE_SIZE:
		action_button("‹",Vector2(1268,140),Vector2(42,36),func(): page-=1; rebuild(),page<=0).tooltip_text = "前面的体节"
		action_button("›",Vector2(1318,140),Vector2(42,36),func(): page+=1; rebuild(),(page+1)*PAGE_SIZE>=player.segment_count()).tooltip_text = "后面的体节"
	tail_target = make_mount(Vector2(454+shown*100,207),Vector2(94,102),{"kind":"tail"},{},null,"拖入模块，新增一节")
	grid_title = text_at("体节 %02d" % selected_segment,Vector2(536,339),Vector2(280,34),22)
	for slot in 9:
		var index = player.part_at(selected_segment,slot)
		var data = {"kind":"mounted","part":player.parts[index]} if index>0 else {}
		var core = db.asset(player.parts[index].id) if index>0 else {}
		var control = make_mount(Vector2(534+slot%3*128,388+slot/3*128),Vector2(116,116),{"kind":"slot","segment":selected_segment,"slot":slot},data,db.core_sprite(core),db.title(core) if index>0 else "空位")
		control.selected = index>0 and selected_data.get("part") == player.parts[index]
		slots.append(control)
	detail = text_at("实装预览",Vector2(1018,357),Vector2(342,58),22)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 3:
		var stat = Control.new(); stat.position = Vector2(1035,578+i*29); stat.size = Vector2(278,25)
		stat.mouse_filter = Control.MOUSE_FILTER_PASS; stat.visible = false; add_child(stat); stat_targets.append(stat)
	copy_button = icon_button("copy",int(player.actions.duplicate),Vector2(1060,697),func(): copying=not copying; rebuild(),"复制：点空位放下一份")
	copy_button.active = copying
	armor_button = icon_button("armor",int(player.actions.wall),Vector2(1170,697),reinforce_selected,"加固所选模块")
	hint = text_at("",Vector2(48,823),Vector2(1040,42),17)
	hint.add_theme_color_override("font_color",Neon.RED); hint.visible = false
	return_button = action_button("出战  →",Vector2(1170,812),Vector2(190,52),game.show_game,not player.pending.is_empty())
	if game.reward_flow_active:
		action_button("稍后安装",Vector2(1008,812),Vector2(142,52),game.postpone_rewards)
		return_button.text="安装后继续"
	return_button.tooltip_text = "E 返回战斗" if player.pending.is_empty() else "先将左侧模块放入空位"
	rebuilding = false
	inspect({})
	queue_redraw()

func _process(dt: float):
	if toast_left>0:
		toast_left-=dt
		if toast_left<=0: hint.visible=false

func _draw():
	if player == null: return
	draw_rect(Rect2(Vector2.ZERO,size),Neon.BG)
	var faint = Color(Neon.TEAL,0.24)
	draw_line(Vector2(48,111),Vector2(1360,111),faint,1.0,true)
	draw_line(Vector2(336,220),Vector2(336,779),faint,1.0,true)
	Symbols.draw(self,"grid",Vector2(1143,62),0.85,Neon.MUTED)
	draw_line(Vector2(420,260),Vector2(tail_target.position.x+45,260),Color(Neon.MUTED,0.45),3.0,true)
	Art.segment(self,Vector2(414,260),PI,0.67,0.0,true)
	if segment_buttons.has(selected_segment):
		var from: Vector2 = segment_buttons[selected_segment].position+Vector2(47,121)
		draw_polyline(PackedVector2Array([from,Vector2(from.x,329),Vector2(720,329),Vector2(720,337)]),Color(Neon.TEAL,0.6),1.5,true)
	Art.prepare()
	draw_texture_rect(Art.pieces.body,Rect2(515,369,410,410),false,Color(1,1,1,0.14))
	if player.pending.is_empty():
		Symbols.draw(self,"grid",Vector2(180,425),2.8,Color(Neon.MUTED,0.3))
	else:
		Symbols.draw(self,"arrow",Vector2(329,548),1.0,Neon.MUTED)
	var data = inspected_data if not inspected_data.is_empty() else selected_data
	var carried = active_drag_data if not active_drag_data.is_empty() else selected_data
	var placing = not hovered_target.is_empty() and can_drop(hovered_target,carried)
	if placing: data = {}
	if data.is_empty():
		var additional = 1 if placing and (carried.get("kind")!="mounted" or int(carried.get("part",{}).get("segment",-1))!=selected_segment) else 0
		draw_segment(self,selected_segment,Vector2(1185,538),2.7,additional)
		if placing:
			var ghost = db.core_sprite(db.asset(carried.get("id",carried.get("part",{}).get("id",""))))
			var slot = int(hovered_target.slot)
			var center = Vector2(1185,538)+player.display_slot_offset(selected_segment,slot,additional)*2.7
			var extent = Ink.fitted_size(ghost,Vector2.ONE*player.mount_display_size(player.parts_on_segment(selected_segment).size()+additional)*2.7)
			if ghost!=null: draw_texture_rect(ghost,Rect2(center-extent/2,extent),false,Color(1,1,1,0.6))
			draw_arc(center,23,0,TAU,40,Neon.TEAL,2,true)
		draw_string(Neon.font(),Vector2(1161,686),"%d / 9" % player.parts_on_segment(selected_segment).size(),HORIZONTAL_ALIGNMENT_LEFT,-1,20,Neon.MUTED)
	else:
		var core: Dictionary = db.asset(data.get("id",data.get("part",{}).get("id","")))
		var texture = db.core_sprite(core)
		if texture!=null:
			var extent = Ink.fitted_size(texture,Vector2(158,144))
			draw_texture_rect(texture,Rect2(Vector2(1186,485)-extent/2,extent),false)
		var projectile: Dictionary = db.asset(core.get("coreProjectile",""))
		if core.has("coreProjectile"):
			var damage: Dictionary = projectile.get("projectileDamage",{})
			var values = [float(damage.get("hullDamage",0)),float(core.get("turretRateOfFire",0)),db.range_units(core.get("turretRange",1))*48.0]
			var limits = [200.0,12.0,1200.0]
			for i in 3:
				Symbols.draw(self,["damage","rate","range"][i],Vector2(1056,590+i*29),0.7,Neon.MUTED)
				draw_line(Vector2(1086,590+i*29),Vector2(1298,590+i*29),Neon.PANEL,5,true)
				draw_line(Vector2(1086,590+i*29),Vector2(1086+212*clampf(values[i]/limits[i],0.02,1),590+i*29),Neon.TEAL,5,true)
		else:
			draw_segment(self,selected_segment,Vector2(1186,611),1.08)

func draw_segment(canvas: CanvasItem, segment: int, at: Vector2, scale_factor: float = 0.95, additional: int = 0):
	Art.segment(canvas,at,0,scale_factor,0.0,false,player.parts_on_segment(segment).is_empty())
	for index in player.parts_on_segment(segment):
		var part: Dictionary = player.parts[index]
		var texture = db.core_sprite(db.asset(part.id))
		if texture==null: continue
		var extent = Ink.fitted_size(texture,Vector2.ONE*player.mount_display_size(player.parts_on_segment(segment).size()+additional)*scale_factor)
		var center = at+player.display_slot_offset(segment,part.slot,additional)*scale_factor
		canvas.draw_line(at+player.slot_offset(part.slot)*scale_factor,center,Neon.MUTED,3.0*scale_factor,true)
		canvas.draw_texture_rect(texture,Rect2(center-extent/2,extent),false)

func inspect(data: Dictionary):
	# Mouse-exit notifications can arrive synchronously as old cards are removed.
	if rebuilding: return
	inspected_data = data
	var shown = inspected_data if not inspected_data.is_empty() else selected_data
	if detail!=null:
		detail.text = "实装预览" if shown.is_empty() else db.title(db.asset(shown.get("id",shown.get("part",{}).get("id",""))))
	var mounted = selected_data.get("kind") == "mounted"
	copy_button.visible = mounted and not game.reward_flow_active; armor_button.visible = mounted and not game.reward_flow_active
	copy_button.disabled = player.actions.duplicate<=0
	armor_button.disabled = player.actions.wall<=0 or selected_data.get("part",{}).get("wall",false)
	var core = db.asset(shown.get("id",shown.get("part",{}).get("id","")))
	for stat in stat_targets: stat.visible = core.has("coreProjectile") and active_drag_data.is_empty()
	if core.has("coreProjectile"):
		var projectile = db.asset(core.coreProjectile)
		stat_targets[0].tooltip_text = "单发伤害 %.1f" % float(projectile.get("projectileDamage",{}).get("hullDamage",0))
		stat_targets[1].tooltip_text = "射速 %.1f 次/秒" % float(core.get("turretRateOfFire",0))
		stat_targets[2].tooltip_text = "射程 %.0f" % (db.range_units(core.get("turretRange",1))*48.0)
	queue_redraw()
	for slot in slots: slot.queue_redraw()

func begin_drag(data: Dictionary):
	active_drag_data = data
	inspect(data)
	for control in slots+[tail_target]: control.queue_redraw()

func end_drag():
	active_drag_data = {}; inspected_data = {}; hovered_target = {}
	inspect({})
	for control in slots+[tail_target]: control.queue_redraw()

func hover_mount(target: Dictionary):
	if rebuilding: return
	hovered_target = target if target.get("kind")=="slot" else {}
	queue_redraw()

func destination(target: Dictionary) -> Vector2i:
	if target.get("kind") == "tail": return Vector2i(player.segment_count()+1,4)
	return Vector2i(int(target.get("segment",-1)),int(target.get("slot",-1)))

func show_segment_during_drag(segment: int):
	if segment==selected_segment: return
	selected_segment = segment; game.build_selected_segment = segment
	grid_title.text = "体节 %02d" % segment
	for slot in 9:
		var control = slots[slot]
		var index = player.part_at(segment,slot)
		var core = db.asset(player.parts[index].id) if index>0 else {}
		control.target = {"kind":"slot","segment":segment,"slot":slot}
		control.payload = {"kind":"mounted","part":player.parts[index]} if index>0 else {}
		control.icon = db.core_sprite(core); control.caption = db.title(core) if index>0 else "空位"
		control.tooltip_text = control.caption; control.selected = false; control.queue_redraw()
	for key in segment_buttons:
		segment_buttons[key].selected = key==segment; segment_buttons[key].queue_redraw()
	queue_redraw()

func can_drop(target: Dictionary, data: Dictionary) -> bool:
	if target.get("kind") not in ["slot","tail"]: return false
	var dest = destination(target)
	if data.get("kind") == "inventory":
		var index = int(data.get("index",-1))
		return index>=0 and index<player.pending.size() and player.pending[index]==data.get("id") and player.parts.size()<=60 and player.can_mount(dest.x,dest.y)
	if data.get("kind") == "mounted":
		var index = player.parts.find(data.get("part",{}))
		if index<=0: return false
		if copying: return player.actions.duplicate>0 and player.parts.size()+player.pending.size()<=60 and player.can_mount(dest.x,dest.y)
		var occupant = player.part_at(dest.x,dest.y)
		if occupant>=0: return occupant!=index and player.actions.swap>0
		return player.actions.move>0 and player.can_mount(dest.x,dest.y)
	return false

func toast(content: String):
	hint.text = content; hint.visible = true; toast_left = 4.0

func drop(target: Dictionary, data: Dictionary):
	if not can_drop(target,data):
		toast("这里放不下" if data.get("kind") == "inventory" else "需要移动或交换次数")
		return
	var dest = destination(target)
	var changed = false
	if data.kind == "inventory":
		changed = player.install_module(data.id,dest.x,dest.y)
		if changed: player.pending.remove_at(int(data.index))
	else:
		var index = player.parts.find(data.part)
		var occupant = player.part_at(dest.x,dest.y)
		if copying: changed = player.duplicate_to_mount(index,dest.x,dest.y)
		elif occupant>0: changed = player.swap_piece(index,occupant)
		else: changed = player.move_to_mount(index,dest.x,dest.y)
	if changed:
		selected_data = {}; inspected_data = {}; active_drag_data = {}; hovered_target = {}; copying = false
		selected_segment = dest.x; game.build_selected_segment = dest.x; page = (dest.x-1)/PAGE_SIZE
		game.audio_system.play(70)
		if game.reward_flow_active:game.reward_placement_changed.call_deferred()
		else:rebuild.call_deferred()
		game.queue_redraw()
	else: toast(player.last_error)

func click(target: Dictionary, data: Dictionary):
	if target.kind == "segment":
		selected_segment = target.segment; game.build_selected_segment = selected_segment; rebuild.call_deferred()
	elif target.kind == "inventory":
		selected_data = data.duplicate(); copying = false; rebuild.call_deferred()
	elif not selected_data.is_empty() and (data.is_empty() or copying or selected_data.kind == "mounted"):
		drop(target,selected_data)
	elif game.reward_flow_active and selected_data.get("kind")=="inventory":
		toast("请选择空位")
	elif not data.is_empty():
		selected_data = data.duplicate(); rebuild.call_deferred()

func cancel_selection():
	selected_data = {}; inspected_data = {}; copying = false; rebuild.call_deferred()

func reinforce_selected():
	var index = player.parts.find(selected_data.get("part",{}))
	if player.reinforce(index): rebuild.call_deferred()
	else: toast("这个模块已加固")
