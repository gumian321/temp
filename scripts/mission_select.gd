extends Control
## Field-guide expedition briefing. Mission IDs and balance stay source-owned.
const UI=preload("res://scripts/game_ui.gd")
const Guide=preload("res://scripts/field_guide.gd")
const Art=preload("res://scripts/mission_art.gd")
const NAMES_ZH=["生存","无尽","猎杀","护航","破巢","守卫"]
const NAMES_EN=["SURVIVE","ENDLESS","HUNT","ESCORT","SIEGE","DEFEND"]
var game
var board:Panel
var rows:Array[Button]=[]
var row_labels:Array[Label]=[]
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
var reward_summary:Label
var risk_summary:Label
var pool_button:Button
var reset_button:Button
var back_button:Button
var launch_button:Button
var scene_art:Control
var scene_icons:Array[Control]=[]
func tr_text(zh:String,en:String)->String:return game.db.ui(en,zh)
func text_line(text:String,rect:Rect2,font_size:int=20,color:Color=UI.TEXT)->Label:
 var l=UI.label(board,text,rect.position,font_size,color);l.size=rect.size
 l.clip_text=true;l.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 return l
func clean_button(text:String,rect:Rect2,callback:Callable,primary:bool=false)->Button:
 return Guide.button(board,text,rect,callback,primary)
func artwork(parent:Control,index:int,rect:Rect2,compact:bool=false)->Control:
 var art=Art.new();art.mission_index=index;art.compact=compact
 art.position=rect.position;art.size=rect.size
 parent.add_child(art);return art
func setup(owner_game):
 game=owner_game;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE;theme=UI.theme();UI.protect(self)
 Guide.page(self)
 board=Panel.new();board.name="MissionBoard";board.size=Vector2(1200,660)
 board.add_theme_stylebox_override("panel",StyleBoxEmpty.new());add_child(board)
 Guide.rule(board,Rect2(24,73,1152,1))
 Guide.rule(board,Rect2(718,94,1,519),Color(Guide.FAINT,.6))
 back_button=clean_button(tr_text("← 返回","← BACK"),Rect2(24,18,104,42),func():game.show_menu());back_button.add_theme_font_size_override("font_size",18)
 text_line(tr_text("出击","EXPEDITION"),Rect2(148,13,260,54),34)
 text_line("FIELD GUIDE   /   01—06",Rect2(430,31,380,28),15,Guide.MUTED)
 points=text_line("",Rect2(940,28,236,34),20,UI.AMBER);points.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 scene_art=artwork(board,0,Rect2(24,88,676,338));scene_art.name="MissionScene"
 text_line(tr_text("选择行动","CHOOSE OPERATION"),Rect2(24,443,400,30),17,Guide.MUTED)
 text_line(tr_text("六种生存方式","SIX WAYS TO SURVIVE"),Rect2(448,443,252,30),14,Guide.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 for i in game.db.stores.MissionDataStore.missionsList.size():
  var b=clean_button("",Rect2(24+i*114,478,106,110),func():select_mission(i))
  b.toggle_mode=true;b.clip_contents=true;rows.append(b)
  scene_icons.append(artwork(b,i,Rect2(5,0,96,72),true))
  var l=UI.label(b,(NAMES_ZH if game.db.language.begins_with("Chinese") else NAMES_EN)[i],Vector2(4,76),19)
  l.size=Vector2(98,30);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;row_labels.append(l)
 serial=text_line("",Rect2(746,90,430,28),15,Guide.ACCENT)
 title=text_line("",Rect2(736,122,440,54),38)
 objective_text=text_line("",Rect2(736,184,440,40),23)
 description=text_line("",Rect2(736,184,440,40),16,UI.MUTED);description.visible=false
 duration=text_line("",Rect2(736,230,190,46),29,UI.AMBER)
 mode_label=text_line("",Rect2(934,242,242,30),17,UI.MUTED);mode_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 text_line(tr_text("难度","DIFFICULTY"),Rect2(736,298,440,30),18,UI.MUTED)
 for i in 3:
  var b=clean_button(((["普通","困难","噩梦"] if game.db.language.begins_with("Chinese") else ["NORMAL","HARD","NIGHTMARE"])[i]),Rect2(736+i*150,338,140,72),func():select_difficulty(i))
  b.add_theme_font_size_override("font_size",25 if game.db.language.begins_with("Chinese") else 17)
  b.size=Vector2(140,72);b.toggle_mode=true;difficulty_buttons.append(b)
 risk_summary=text_line("",Rect2(736,422,440,28),17,UI.MUTED)
 reward_summary=text_line("",Rect2(736,464,440,30),19,UI.AMBER)
 status=text_line("",Rect2(736,504,440,30),18,UI.MUTED)
 launch_button=clean_button(tr_text("出发","DEPLOY"),Rect2(736,550,440,64),launch,true)
 launch_button.add_theme_font_size_override("font_size",28)
 pool_button=clean_button(tr_text("战利品","LOOT POOL"),Rect2(24,608,174,42),func():game.show_reward_pool())
 pool_button.add_theme_font_size_override("font_size",19)
 pool_summary=text_line("",Rect2(216,614,260,30),17,UI.MUTED)
 reset_button=clean_button(tr_text("重置","RESET"),Rect2(526,608,174,42),reset_pool);reset_button.add_theme_font_size_override("font_size",19)
 resized.connect(layout_board);refresh();layout_board.call_deferred()
func layout_board():
 if not is_inside_tree() or is_queued_for_deletion() or board==null:return
 var factor=maxf(.1,minf((size.x-40)/1200,(size.y-40)/660))
 board.scale=Vector2.ONE*factor;board.position=(size-board.size*factor)*.5
func select_mission(index:int):game.selected_mission=game.db.asset(game.db.stores.MissionDataStore.missionsList[index]);refresh()
func select_difficulty(index:int):game.difficulty=index;refresh()
func refresh():
 var mission:Dictionary=game.selected_mission
 var index=maxi(0,game.db.stores.MissionDataStore.missionsList.find(mission.id))
 for i in rows.size():
  var m=game.db.asset(game.db.stores.MissionDataStore.missionsList[i]);var unlocked=game.save.mission_unlocked(m)
  rows[i].set_pressed_no_signal(i==index)
  rows[i].add_theme_stylebox_override("normal",Guide.skin(i==index))
  scene_icons[i].selected=i==index
  rows[i].tooltip_text=game.db.title(m)+(tr_text(" · 解锁 %d RP"," · Unlock %d RP")%int(m.MissionCost) if not unlocked else "")
  row_labels[i].add_theme_color_override("font_color",UI.TEXT if i==index else UI.MUTED)
 for i in difficulty_buttons.size():
  difficulty_buttons[i].set_pressed_no_signal(i==game.difficulty)
  var config=game.db.asset(mission.MissionsObjectiveList[i].objectiveAIConfiguration)
  difficulty_buttons[i].tooltip_text=tr_text("每波敌群 %d–%d","Enemy groups per wave: %d–%d")%[int(config.get("MinWaveCount",0)),int(config.get("MaxWaveCount",0))]
 title.text=(NAMES_ZH if game.db.language.begins_with("Chinese") else NAMES_EN)[index]
 title.tooltip_text=game.db.title(mission);serial.text=tr_text("行动 %02d / 06","OPERATION %02d / 06")%[index+1]
 description.text=game.db.text(mission.MissionDescTextID);title.tooltip_text+="\n"+description.text
 var zh=["击败最后一波首领","迎战无限波次","击败目标运输队","护送迁徙虫群抵达安全区","摧毁敌方虫巢","守住己方虫巢"]
 var en=["Defeat the final boss wave","Survive endless waves","Eliminate the target brood","Escort the brood to safety","Destroy the enemy nest","Defend your nest"]
 objective_text.text=(zh if game.db.language.begins_with("Chinese") else en)[index]
 var cave=game.save.state.selected_character=="centipede"
 objective_text.tooltip_text=(tr_text("靠近迁徙虫群领航，清敌开路，护送至少一只护送虫抵达安全区；全部损失失败。","Stay close, lead through open tunnels and deliver at least one brood member. Losing the entire brood fails.") if cave else tr_text("靠近迁徙虫群，它会自动前进；护送至少一只护送虫抵达安全区，全部损失失败。","Stay close so the brood advances. Deliver at least one brood member; losing the entire brood fails.")) if index==3 else ""
 duration.text="∞" if mission.isEndless else "%02d : 00"%int(mission.MissionsObjectiveList[game.difficulty].objectiveTime)
 mode_label.text=tr_text("无限波次","ENDLESS") if mission.isEndless else tr_text("行动时限","TIME LIMIT")
 points.text="%d RP"%game.save.state.meta
 var unlocked=game.save.mission_unlocked(mission)
 launch_button.text=tr_text("出发","DEPLOY") if unlocked else tr_text("解锁  %d RP","UNLOCK  %d RP")%int(mission.MissionCost)
 launch_button.disabled=not unlocked and game.save.state.meta<int(mission.MissionCost)
 status.text=tr_text("准备就绪","READY") if unlocked else (tr_text("研究点不足","MORE RP NEEDED") if launch_button.disabled else tr_text("永久解锁 · 解锁后出发","PERMANENT UNLOCK"))
 pool_summary.text=tr_text("全部启用","ALL ACTIVE") if game.save.state.disabled.is_empty() else tr_text("排除 %d 项","%d EXCLUDED")%game.save.state.disabled.size()
 var config=game.db.asset(mission.MissionsObjectiveList[game.difficulty].objectiveAIConfiguration)
 risk_summary.text=tr_text("每波敌群 %d–%d","Enemy groups / wave  %d–%d")%[int(config.get("MinWaveCount",0)),int(config.get("MaxWaveCount",0))]
 if index==3:
  risk_summary.text=(tr_text("靠近领航 · 清敌开路 · 至少一只护送虫抵达","Stay close · Clear a path · Deliver one brood member") if cave else tr_text("靠近随行 · 清理敌人 · 至少一只护送虫抵达","Stay close · Defend brood · Deliver one brood member"))+"\n"+risk_summary.text
  status.text=tr_text("离队会等待 · 迁徙虫群全灭失败","Brood waits if you leave · Lose all = fail") if unlocked else status.text
 risk_summary.add_theme_font_size_override("font_size",14 if index==3 else 17)
 risk_summary.position.y=414 if index==3 else 422;risk_summary.size.y=48 if index==3 else 28
 reward_summary.position.y=470 if index==3 else 464;status.position.y=508 if index==3 else 504
 var mode:Dictionary={}
 for component in game.db.prefabs.get(mission.MissionsObjectiveList[game.difficulty].objectivePrefab,{}).get("components",[]):
  if str(component.get("class","")).ends_with("ModeManager"):mode=component;break
 reward_summary.text=tr_text("生存积分 +%d / 秒","Survival score +%d / sec")%int(mode.get("BonusRatingPerSecSurvived",0)) if mission.isEndless else tr_text("完成积分 +%s","Completion score +%s")%str(int(mode.get("MissionRating",0)))
 reward_summary.tooltip_text=tr_text("研究点按最终评分结算。难度不直接增加奖励倍率。","RP is awarded by final grade. Difficulty has no direct reward multiplier.")
 scene_art.mission_index=index
 reset_button.visible=not game.save.state.disabled.is_empty();connect_focus();layout_board.call_deferred()
func launch():
 if game.save.mission_unlocked(game.selected_mission):game.begin_run()
 elif game.save.unlock_mission(game.selected_mission):refresh();launch_button.grab_focus()
 else:refresh()
func reset_pool():
 var previous:Array=game.save.state.disabled.duplicate()
 game.save.state.disabled.clear()
 var saved=game.save.save()
 if not saved:game.save.state.disabled=previous
 refresh()
 if not saved:status.text=tr_text("保存失败 · 筛选未更改","SAVE FAILED · FILTER UNCHANGED")
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
