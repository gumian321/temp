extends Control
## Spatial operation chart. Mission state remains owned by main/save_store.
const UI=preload("res://scripts/game_ui.gd")
const NAMES_ZH=["生存","猎杀","护航","破巢","守卫","无尽"]
const NAMES_EN=["SURVIVE","HUNT","ESCORT","SIEGE","DEFEND","ENDLESS"]
const KEYS=["shield","target","wing","burst","shield","orbit"]
const COORDS=[Vector2(100,280),Vector2(245,160),Vector2(435,205),Vector2(475,395),Vector2(280,455),Vector2(95,460)]
var game
var board:Panel
var rows:Array[Button]=[]
var difficulty_buttons:Array[Button]=[]
var title:Label
var description:Label
var objective_text:Label
var duration:Label
var mode_label:Label
var points:Label
var status:Label
var serial:Label
var pool_summary:Label
var pool_button:Button
var reset_button:Button
var back_button:Button
var launch_button:Button
var emblem:Control
var mark:Control

class RouteMap extends Control:
 var selected=0
 func _draw():
  var center=Vector2(295,320)
  for radius in [110,200,280]:draw_arc(center,radius,0,TAU,90,Color("203d48"),1,true)
  var coords=[Vector2(100,280),Vector2(245,160),Vector2(435,205),Vector2(475,395),Vector2(280,455),Vector2(95,460)]
  for i in 5:draw_line(coords[i],coords[i+1],Color("355767"),2,true)
  for i in coords.size():
   draw_arc(coords[i],57,0,TAU,48,Color("55e3c1") if i==selected else Color("355767"),3 if i==selected else 1,true)
  draw_circle(center,5,Color("ffc86a"))

func setup(owner_game):
 game=owner_game;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE;theme=UI.theme();UI.protect(self)
 UI.backdrop(self)
 board=Panel.new();board.name="MissionBoard";board.size=Vector2(1200,660);board.add_theme_stylebox_override("panel",UI.style(UI.BG,Color.TRANSPARENT));add_child(board)
 back_button=UI.button(board,"",Rect2(24,20,56,48),func():game.show_menu(),"back")
 UI.label(board,tr_text("出征","OPERATIONS"),Vector2(96,22),30)
 points=UI.label(board,"",Vector2(956,30),22,UI.AMBER)
 mark=RouteMap.new();mark.size=Vector2(620,570);mark.mouse_filter=MOUSE_FILTER_IGNORE;board.add_child(mark)
 UI.label(board,"SECTOR / 06",Vector2(26,88),13,UI.MUTED)
 for i in game.db.stores.MissionDataStore.missionsList.size():
  var b=UI.button(board,"",Rect2(COORDS[i]-Vector2(40,40),Vector2(80,80)),func():select_mission(i),KEYS[i])
  b.toggle_mode=true;b.tooltip_text=game.db.title(game.db.asset(game.db.stores.MissionDataStore.missionsList[i]));rows.append(b)
  UI.label(board,(NAMES_ZH if game.db.language.begins_with("Chinese") else NAMES_EN)[i],COORDS[i]+Vector2(-36,58),16,UI.MUTED)
 UI.panel(board,Rect2(640,92,532,462),UI.TEAL)
 serial=UI.label(board,"",Vector2(672,114),15,UI.TEAL)
 title=UI.label(board,"",Vector2(672,148),38);title.size=Vector2(365,62)
 emblem=UI.icon(board,"target",Vector2(1058,132),70,UI.AMBER)
 objective_text=UI.label(board,"",Vector2(672,227),21);objective_text.size=Vector2(458,64);objective_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 description=UI.label(board,"",Vector2(672,296),16,UI.MUTED);description.visible=false
 duration=UI.label(board,"",Vector2(672,302),27,UI.AMBER)
 mode_label=UI.label(board,"",Vector2(922,310),16,UI.MUTED)
 UI.label(board,tr_text("威胁等级","THREAT"),Vector2(672,375),14,UI.MUTED)
 for i in 3:
  var b=UI.button(board,"I".repeat(i+1),Rect2(672+i*152,405,136,58),func():select_difficulty(i))
  b.toggle_mode=true;b.tooltip_text=game.db.text(game.db.stores.MissionDataStore.DifficultiesList[i].diffecultyTextID);difficulty_buttons.append(b)
 status=UI.label(board,"",Vector2(672,490),17,UI.MUTED)
 pool_button=UI.button(board,tr_text("战利品","LOOT"),Rect2(24,586,168,52),func():game.show_reward_pool(),"reward")
 pool_summary=UI.label(board,"",Vector2(211,600),16,UI.MUTED)
 reset_button=UI.button(board,tr_text("重置","RESET"),Rect2(456,586,130,52),reset_pool)
 launch_button=UI.button(board,"",Rect2(640,576,532,64),launch,"play",UI.AMBER)
 resized.connect(layout_board);refresh();layout_board.call_deferred()
func tr_text(zh:String,en:String)->String:return game.db.ui(en,zh)
func layout_board():
 if board==null:return
 var factor=minf((size.x-40)/1200,(size.y-40)/660)
 factor=maxf(.1,factor);board.scale=Vector2.ONE*factor;board.position=(size-board.size*factor)*.5
func select_mission(index:int):game.selected_mission=game.db.asset(game.db.stores.MissionDataStore.missionsList[index]);refresh()
func select_difficulty(index:int):game.difficulty=index;refresh()
func refresh():
 var mission:Dictionary=game.selected_mission
 var index=maxi(0,game.db.stores.MissionDataStore.missionsList.find(mission.id))
 for i in rows.size():
  var m=game.db.asset(game.db.stores.MissionDataStore.missionsList[i]);var unlocked=game.save.mission_unlocked(m)
  rows[i].set_pressed_no_signal(i==index);rows[i].modulate=Color.WHITE if unlocked else Color(.55,.65,.7)
  rows[i].add_theme_stylebox_override("normal",UI.style(Color("24544e") if i==index else UI.PANEL,UI.TEAL if i==index else Color("355767"),40))
  rows[i].tooltip_text=game.db.title(m)+(tr_text(" · 锁定"," · Locked") if not unlocked else "")
 for i in difficulty_buttons.size():difficulty_buttons[i].set_pressed_no_signal(i==game.difficulty)
 title.text=(NAMES_ZH if game.db.language.begins_with("Chinese") else NAMES_EN)[index]
 title.tooltip_text=game.db.title(mission);serial.text="OP / %02d"%[index+1]
 description.text=game.db.text(mission.MissionDescTextID);title.tooltip_text+="\n"+description.text
 var zh=["存活至追捕结束","击败目标舰队","护送商队抵达安全区","摧毁敌方空间站","守住己方空间站","迎战无限波次"]
 var en=["Survive the hunt","Eliminate the target fleet","Escort traders to safety","Destroy the enemy station","Defend your station","Survive endless waves"]
 objective_text.text=(zh if game.db.language.begins_with("Chinese") else en)[index]
 duration.text="∞" if mission.isEndless else "%02d : 00"%int(mission.MissionsObjectiveList[game.difficulty].objectiveTime)
 mode_label.text=tr_text("无限波次","ENDLESS") if mission.isEndless else tr_text("行动时限","TIME LIMIT")
 points.text="◈ %d"%game.save.state.meta
 var unlocked=game.save.mission_unlocked(mission)
 launch_button.text=tr_text("出发","DEPLOY") if unlocked else tr_text("解锁  ◈ %d","UNLOCK  ◈ %d")%int(mission.MissionCost)
 launch_button.disabled=not unlocked and game.save.state.meta<int(mission.MissionCost)
 status.text=tr_text("准备就绪","READY") if unlocked else (tr_text("研究点不足","MORE RP NEEDED") if launch_button.disabled else tr_text("永久解锁","PERMANENT UNLOCK"))
 pool_summary.text=tr_text("全部启用","ALL ACTIVE") if game.save.state.disabled.is_empty() else tr_text("排除 %d 项","%d EXCLUDED")%game.save.state.disabled.size()
 emblem.key=KEYS[index];emblem.queue_redraw()
 reset_button.visible=not game.save.state.disabled.is_empty();mark.selected=index;mark.queue_redraw();connect_focus();layout_board.call_deferred()
func launch():
 if game.save.mission_unlocked(game.selected_mission):game.begin_run()
 elif game.save.unlock_mission(game.selected_mission):refresh();launch_button.grab_focus()
 else:refresh()
func reset_pool():game.save.state.disabled.clear();game.save.save();refresh()
func focus_selection():rows[maxi(0,game.db.stores.MissionDataStore.missionsList.find(game.selected_mission.id))].grab_focus()
func connect_focus():
 var ordered:Array=[];ordered.append_array(rows);ordered.append_array(difficulty_buttons)
 if reset_button.visible:ordered.append(reset_button)
 ordered.append(pool_button);ordered.append(back_button)
 if not launch_button.disabled:ordered.append(launch_button)
 for i in ordered.size():
  var b:Control=ordered[i];b.focus_next=b.get_path_to(ordered[(i+1)%ordered.size()]);b.focus_previous=b.get_path_to(ordered[posmod(i-1,ordered.size())])
 for i in rows.size():
  rows[i].focus_neighbor_top=rows[i].get_path_to(rows[posmod(i-1,rows.size())]);rows[i].focus_neighbor_bottom=rows[i].get_path_to(rows[(i+1)%rows.size()]);rows[i].focus_neighbor_right=rows[i].get_path_to(difficulty_buttons[game.difficulty])
 for i in difficulty_buttons.size():
  difficulty_buttons[i].focus_neighbor_left=difficulty_buttons[i].get_path_to(difficulty_buttons[i-1] if i>0 else rows[maxi(0,game.db.stores.MissionDataStore.missionsList.find(game.selected_mission.id))])
  difficulty_buttons[i].focus_neighbor_right=difficulty_buttons[i].get_path_to(difficulty_buttons[mini(2,i+1)])
