extends Control
## Viewport-centred mission briefing. Gameplay and persistence stay in the owner.
const Ink = preload("res://scripts/blue_ink.gd")
const MUTED = Color("54708a")
const SUMMARIES = {
 "Survival Mission": ["保持生存，撑过追捕。", "Survive until the hunt ends."],
 "Bounty Hunter Mission": ["追踪并击败目标舰队。", "Track down and defeat the target fleet."],
 "Gardian Angel Mission": ["护送商队，抵达安全区域。", "Escort the traders to safety."],
 "Station Hunter Mission": ["在时限内摧毁敌方空间站。", "Destroy the enemy station before time runs out."],
 "Station Protector Mission": ["抵御来袭，守住己方空间站。", "Defend your station against incoming waves."],
 "Endless Mission": ["持续迎战，挑战更长的生存记录。", "Keep fighting and set a new survival record."]
}
var game
var board: PanelContainer
var rows: Array[Button] = []
var difficulty_buttons: Array[Button] = []
var title: Label
var description: Label
var objective_text: Label
var duration: Label
var mode_label: Label
var points: Label
var status: Label
var serial: Label
var pool_summary: Label
var pool_button: Button
var reset_button: Button
var back_button: Button
var launch_button: Button
var emblem: Control
var body_row: HBoxContainer
var list_column: VBoxContainer
var details: VBoxContainer

class MissionMark extends Control:
 var number = 0
 func _draw():
  var ink=Color("2f60a0")
  var center=size*.5
  draw_circle(center,42,Color("e6eceb"))
  draw_arc(center,33,-PI*.8,PI*.8,56,ink,1.2,true)
  draw_arc(center,24,PI*.2,PI*1.8,48,Color(ink,.4),1,true)
  var points=PackedVector2Array([center+Vector2(-20,10),center+Vector2(-6,-8),center+Vector2(11,6),center+Vector2(23,-14)])
  draw_polyline(points,ink,1.5,true)
  for i in points.size():draw_circle(points[i],3.3,ink if i==number%4 else Color("f6f2e7"));draw_arc(points[i],3.3,0,TAU,16,ink,1,true)

func box(fill: Color, edge: Color, radius: int = 10, padding: int = 16) -> StyleBoxFlat:
 var s=Ink.box(fill,edge,1)
 s.set_corner_radius_all(radius)
 s.content_margin_left=padding;s.content_margin_right=padding
 s.content_margin_top=mini(padding,10);s.content_margin_bottom=mini(padding,10)
 return s

func setup(owner_game):
 game=owner_game
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 theme=Theme.new()
 theme.default_font=load("res://assets/fonts/NotoSansSC-Light.otf")
 theme.default_font_size=20
 for key in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:theme.set_color(key,"Button",Ink.INK)
 theme.set_color("font_disabled_color","Button",MUTED)
 theme.set_color("font_color","Label",Ink.INK)
 theme.set_stylebox("normal","Button",box(Color("f9f6ee"),Color("b8c9d6")))
 theme.set_stylebox("hover","Button",box(Color("e8eeed"),Ink.BLUE))
 theme.set_stylebox("pressed","Button",box(Color("d8e5e9"),Ink.BLUE))
 theme.set_stylebox("disabled","Button",box(Color("eeece5"),Color("cdd4d5")))
 var focus=box(Color.TRANSPARENT,Ink.BLUE,10,0);focus.set_border_width_all(2);focus.expand_margin_left=3;focus.expand_margin_right=3;focus.expand_margin_top=3;focus.expand_margin_bottom=3
 theme.set_stylebox("focus","Button",focus)
 board=PanelContainer.new();board.name="MissionBoard";add_child(board)
 board.add_theme_stylebox_override("panel",box(Color("f9f6ee"),Color("9cb2c9"),18,30))
 var content=VBoxContainer.new();content.add_theme_constant_override("separation",16);board.add_child(content)
 var heading=HBoxContainer.new();content.add_child(heading)
 var h=VBoxContainer.new();h.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(h)
 text(h,tr_text("出征准备  /  MISSION BRIEFING","PREPARE / MISSION BRIEFING"),14,MUTED)
 text(h,tr_text("选择任务","Choose a mission"),32)
 points=text(heading,"",20);points.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 line(content)
 body_row=HBoxContainer.new();body_row.size_flags_vertical=Control.SIZE_EXPAND_FILL;body_row.add_theme_constant_override("separation",30);content.add_child(body_row)
 list_column=VBoxContainer.new();list_column.custom_minimum_size.x=292;list_column.add_theme_constant_override("separation",8);body_row.add_child(list_column)
 text(list_column,tr_text("任务档案  /  06","OPERATIONS / 06"),14,MUTED)
 var group=ButtonGroup.new()
 for i in game.db.stores.MissionDataStore.missionsList.size():
  var mission=game.db.asset(game.db.stores.MissionDataStore.missionsList[i])
  var b=button(list_column,"",func(): select_mission(i))
  b.add_theme_font_size_override("font_size",18);b.custom_minimum_size.y=53;b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.toggle_mode=true;b.button_group=group
  rows.append(b)
 var rule=VSeparator.new();rule.add_theme_stylebox_override("separator",box(Color("cfdae0"),Color.TRANSPARENT,0,0));body_row.add_child(rule)
 details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",8);body_row.add_child(details)
 var hero=HBoxContainer.new();details.add_child(hero)
 var titles=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;hero.add_child(titles)
 serial=text(titles,"",14,MUTED)
 title=text(titles,"",40);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 emblem=MissionMark.new();emblem.custom_minimum_size=Vector2(82,82);emblem.mouse_filter=Control.MOUSE_FILTER_IGNORE;hero.add_child(emblem)
 description=text(details,"",18,MUTED);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var objective=PanelContainer.new();objective.add_theme_stylebox_override("panel",box(Color("edf1ee"),Color("d5dfdd"),10,18));details.add_child(objective)
 var objective_box=VBoxContainer.new();objective_box.add_theme_constant_override("separation",6);objective.add_child(objective_box)
 text(objective_box,tr_text("行动目标","OBJECTIVE"),14,MUTED)
 objective_text=text(objective_box,"",22);objective_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var metrics=HBoxContainer.new();metrics.add_theme_constant_override("separation",24);objective_box.add_child(metrics)
 duration=text(metrics,"",16,MUTED);duration.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 mode_label=text(metrics,"",16,MUTED)
 text(details,tr_text("任务难度","DIFFICULTY"),16,MUTED)
 var levels=HBoxContainer.new();levels.add_theme_constant_override("separation",10);details.add_child(levels)
 var level_group=ButtonGroup.new()
 for i in 3:
  var b=button(levels,game.db.text(game.db.stores.MissionDataStore.DifficultiesList[i].diffecultyTextID),func(): select_difficulty(i))
  b.toggle_mode=true;b.button_group=level_group;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.custom_minimum_size.y=48;difficulty_buttons.append(b)
 var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;details.add_child(spacer)
 var pool=HBoxContainer.new();pool.add_theme_constant_override("separation",8);details.add_child(pool)
 var pool_info=VBoxContainer.new();pool_info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pool.add_child(pool_info)
 text(pool_info,tr_text("奖励池","REWARD POOL"),18)
 pool_summary=text(pool_info,"",14,MUTED)
 reset_button=button(pool,tr_text("恢复默认","Reset"),reset_pool);reset_button.add_theme_font_size_override("font_size",16)
 pool_button=button(pool,tr_text("设置奖励池  ↗","Configure  ↗"),func(): game.show_reward_pool());pool_button.add_theme_font_size_override("font_size",17)
 line(content)
 var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",22);content.add_child(footer)
 back_button=button(footer,tr_text("←  返回","←  Back"),func():game.show_menu());back_button.custom_minimum_size=Vector2(128,54)
 status=text(footer,"",17,MUTED);status.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 launch_button=button(footer,"",launch);launch_button.custom_minimum_size=Vector2(254,54)
 for state in ["normal","hover","pressed"]:launch_button.add_theme_stylebox_override(state,box(Ink.INK if state=="normal" else Ink.BLUE,Ink.INK))
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:launch_button.add_theme_color_override(state,Ink.PAPER)
 resized.connect(layout_board)
 refresh()
 layout_board.call_deferred()

func tr_text(chinese: String, english: String) -> String:return game.db.ui(english,chinese)
func text(parent: Node, value: String, font_size: int, color: Color = Ink.INK) -> Label:
 var l=Label.new();l.text=value;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func button(parent: Node, value: String, action: Callable) -> Button:
 var b=Button.new();b.text=value;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;b.pressed.connect(func():game.audio_system.play(70);action.call());parent.add_child(b);return b
func line(parent: Node):
 var l=HSeparator.new();l.add_theme_stylebox_override("separator",box(Color("cfdae0"),Color.TRANSPARENT,0,0));l.custom_minimum_size.y=1;parent.add_child(l)
func layout_board():
 if board==null:return
 board.size=Vector2(minf(1180,size.x-64),minf(750,size.y-64))
 board.position=(size-board.size)*.5
func select_mission(index: int):
 game.selected_mission=game.db.asset(game.db.stores.MissionDataStore.missionsList[index]);refresh()
func select_difficulty(index: int):
 game.difficulty=index;refresh()
func refresh():
 var mission: Dictionary=game.selected_mission
 var index=game.db.stores.MissionDataStore.missionsList.find(mission.id)
 for i in rows.size():
  var m=game.db.asset(game.db.stores.MissionDataStore.missionsList[i])
  rows[i].text="%02d   %s%s"%[i+1,game.db.title(m),"" if game.save.mission_unlocked(m) else tr_text("  · 待解锁","  · Locked")]
  rows[i].set_pressed_no_signal(i==index)
  rows[i].add_theme_stylebox_override("normal",box(Color("e0e9eb") if i==index else Color("f9f6ee"),Ink.BLUE if i==index else Color("d3dddF")))
 for i in difficulty_buttons.size():
  difficulty_buttons[i].set_pressed_no_signal(i==game.difficulty)
  difficulty_buttons[i].add_theme_stylebox_override("normal",box(Color("dce7ea") if i==game.difficulty else Color("f9f6ee"),Ink.BLUE if i==game.difficulty else Color("b8c9d6")))
 title.text=game.db.title(mission)
 serial.text=tr_text("行动档案  /  %02d","OPERATION / %02d")%[index+1]
 description.text=game.db.text(mission.MissionDescTextID)
 var summary=SUMMARIES.get(mission.name,[description.text,description.text])
 objective_text.text=summary[0] if game.db.language.begins_with("Chinese") else summary[1]
 var objective=mission.MissionsObjectiveList[game.difficulty]
 duration.text=tr_text("不限时","No time limit") if mission.isEndless else tr_text("任务时限  %d 分钟","Mission time  %d min")%int(objective.objectiveTime)
 mode_label.text=tr_text("无限波次","Endless waves") if mission.isEndless else tr_text("难度  ","Difficulty  ")+difficulty_buttons[game.difficulty].text
 points.text=tr_text("%d 研究点","%d RP")%game.save.state.meta
 var unlocked=game.save.mission_unlocked(mission)
 launch_button.text=tr_text("出发  →","Deploy  →") if unlocked else tr_text("解锁任务  ·  %d 研究点","Unlock  ·  %d RP")%int(mission.MissionCost)
 launch_button.disabled=not unlocked and game.save.state.meta<int(mission.MissionCost)
 status.text=tr_text("准备就绪，选择难度后出发。","Ready. Choose a difficulty and deploy.") if unlocked else (tr_text("永久解锁此任务。","Unlock this mission permanently.") if not launch_button.disabled else tr_text("研究点不足，请先完成任务积累。","Earn more research points to unlock this mission."))
 pool_summary.text=tr_text("默认配置","Default configuration") if game.save.state.disabled.is_empty() else tr_text("已自定义 · 排除 %d 项","Custom · %d excluded")%game.save.state.disabled.size()
 reset_button.visible=not game.save.state.disabled.is_empty()
 emblem.number=index;emblem.queue_redraw()
 connect_focus()
 layout_board.call_deferred()
func launch():
 if game.save.mission_unlocked(game.selected_mission):game.begin_run()
 elif game.save.unlock_mission(game.selected_mission):refresh();launch_button.grab_focus()
 else:refresh()
func reset_pool():
 game.save.state.disabled.clear();game.save.save();refresh()
func focus_selection():
 var index=game.db.stores.MissionDataStore.missionsList.find(game.selected_mission.id)
 rows[maxi(0,index)].grab_focus()
func connect_focus():
 var ordered: Array=[];ordered.append_array(rows);ordered.append_array(difficulty_buttons)
 if reset_button.visible:ordered.append(reset_button)
 ordered.append(pool_button);ordered.append(back_button)
 if not launch_button.disabled:ordered.append(launch_button)
 for i in ordered.size():
  var b:Control=ordered[i];b.focus_next=b.get_path_to(ordered[(i+1)%ordered.size()]);b.focus_previous=b.get_path_to(ordered[posmod(i-1,ordered.size())])
 for i in rows.size():
  rows[i].focus_neighbor_top=rows[i].get_path_to(rows[posmod(i-1,rows.size())]);rows[i].focus_neighbor_bottom=rows[i].get_path_to(rows[(i+1)%rows.size()]);rows[i].focus_neighbor_right=rows[i].get_path_to(difficulty_buttons[game.difficulty])
 for i in difficulty_buttons.size():
  var b=difficulty_buttons[i]
  b.focus_neighbor_left=b.get_path_to(difficulty_buttons[i-1] if i>0 else rows[game.db.stores.MissionDataStore.missionsList.find(game.selected_mission.id)])
  b.focus_neighbor_right=b.get_path_to(difficulty_buttons[mini(2,i+1)])
  b.focus_neighbor_bottom=b.get_path_to(pool_button)
 pool_button.focus_neighbor_top=pool_button.get_path_to(difficulty_buttons[game.difficulty]);pool_button.focus_neighbor_bottom=pool_button.get_path_to(back_button if launch_button.disabled else launch_button)
 back_button.focus_neighbor_right=back_button.get_path_to(pool_button if launch_button.disabled else launch_button)
 launch_button.focus_neighbor_left=launch_button.get_path_to(back_button);launch_button.focus_neighbor_top=launch_button.get_path_to(pool_button)
