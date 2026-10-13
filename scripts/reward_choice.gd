extends Control
const Ink=preload("res://scripts/blue_ink.gd")
var game
var board:PanelContainer
var buttons:Array[Button]=[]
var faces:Array[VBoxContainer]=[]
var effect_labels:Array[Label]=[]
var postpone_button:Button
var recycle_button:Button
var epoch=0
const RARITY_COLORS=[Color("66839d"),Color("397594"),Color("70668f"),Color("9b7b41")]
func setup(owner_game,offers:Array,token:int):
 game=owner_game;epoch=token
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_STOP
 theme=Ink.theme()
 board=PanelContainer.new();add_child(board)
 var paper=Ink.box(Color("f9f6ee"),Color("c1cddd"),1);paper.set_corner_radius_all(18)
 paper.content_margin_left=28;paper.content_margin_right=28;paper.content_margin_top=24;paper.content_margin_bottom=24
 board.add_theme_stylebox_override("panel",paper)
 var stack=VBoxContainer.new();stack.add_theme_constant_override("separation",16);board.add_child(stack)
 var heading=HBoxContainer.new();stack.add_child(heading)
 var title=label(heading,game.db.ui("Choose your upgrade","选择一项奖励"),30);title.size_flags_horizontal=SIZE_EXPAND_FILL
 label(heading,game.db.ui("%d packs waiting","待领 %d 包")%game.run.packs,17)
 label(stack,game.db.ui("Combat paused · Choose one of three","战斗已暂停 · 三选一，继续强化你的蜈蚣"),17).add_theme_color_override("font_color",Color("687f99"))
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",18);row.size_flags_vertical=SIZE_EXPAND_FILL;stack.add_child(row)
 for i in offers.size():
  var reward:Dictionary=offers[i]
  var rarity=clampi(int(reward.get("rarity",0)),0,3);var accent=RARITY_COLORS[rarity]
  var b=Button.new();b.size_flags_horizontal=SIZE_EXPAND_FILL;b.custom_minimum_size=Vector2(0,365);b.disabled=not game.run.can_reward(reward);row.add_child(b)
  b.tooltip_text=effect_text(reward)
  for key in ["normal","hover","pressed","disabled","focus"]:
   var fill=Color("fcfaf3") if key=="normal" else Color("eaf0f5")
   if key=="disabled":fill=Color("eeede8")
   var style=Ink.box(fill,accent.lightened(.35) if key=="normal" else accent,1 if key in ["normal","disabled"] else 2)
   style.set_corner_radius_all(12)
   if key=="focus":style.bg_color=Color.TRANSPARENT
   b.add_theme_stylebox_override(key,style)
  b.pressed.connect(func():game.choose_reward(reward,epoch));buttons.append(b)
  var face=VBoxContainer.new();face.set_anchors_and_offsets_preset(PRESET_FULL_RECT);face.offset_left=20;face.offset_right=-20;face.offset_top=18;face.offset_bottom=-18;face.add_theme_constant_override("separation",10);face.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(face);faces.append(face)
  var top=HBoxContainer.new();top.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(top)
  var rarity_name=[game.db.ui("COMMON","普通"),game.db.ui("RARE","稀有"),game.db.ui("EPIC","史诗"),game.db.ui("LEGENDARY","传说")][rarity]
  var rarity_label=label(top,rarity_name,16);rarity_label.add_theme_color_override("font_color",accent);rarity_label.size_flags_horizontal=SIZE_EXPAND_FILL
  label(top,"0%d"%(i+1),15).add_theme_color_override("font_color",Color("91a1b3"))
  var image=TextureRect.new();image.texture=game.db.reward_sprite(reward);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size.y=112;image.size_flags_vertical=SIZE_EXPAND_FILL;image.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(image)
  var name_label=label(face,game.db.title(reward),23);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;name_label.custom_minimum_size.y=56
  var rule=HSeparator.new();rule.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(rule)
  var effect=label(face,effect_text(reward),17);effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;effect.custom_minimum_size.y=72;effect.max_lines_visible=4;effect.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;effect.add_theme_color_override("font_color",Color("516b86"));effect_labels.append(effect)
  var action=game.db.ui("Select · choose a mount →","选择 · 安放模块 →") if reward.get("class")=="BlockReward" else game.db.ui("Select · apply immediately →","选择 · 立即生效 →")
  if b.disabled:action=game.db.ui("Unavailable · keep for later","当前不可选 · 可暂存")
  var action_label=label(face,action,17);action_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;action_label.add_theme_color_override("font_color",accent)
  if b.disabled:face.modulate=Color(1,1,1,.55)
 if not offers.any(func(r):return game.run.can_reward(r)):
  var message=label(stack,game.db.ui("No available choice. Your pack is kept for later.","当前无可选项，奖励包会保留，可暂存后继续战斗。"),17);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",16);stack.add_child(footer)
 postpone_button=Button.new();postpone_button.text=game.db.ui("Keep for later · Esc","暂存并继续 · Esc");postpone_button.pressed.connect(game.postpone_rewards);footer.add_child(postpone_button)
 var gap=Control.new();gap.size_flags_horizontal=SIZE_EXPAND_FILL;footer.add_child(gap)
 recycle_button=Button.new();recycle_button.text=game.db.ui("Recycle this pack","回收此奖励包");recycle_button.pressed.connect(func():game.recycle_reward(epoch));footer.add_child(recycle_button)
 resized.connect(layout_board);layout_board.call_deferred()
func effect_text(reward:Dictionary)->String:
 var description=""
 if reward.get("rewardDesc") is String:description=game.db.text(reward.rewardDesc)
 if description==str(reward.get("rewardDesc")):description=""
 match str(reward.get("class","")):
  "PercentBasicReward":return game.db.title(reward)+" %+.0f%%"%(float(reward.get("percent",0))*100)+( "\n"+description if not description.is_empty() else "")
  "CrusedReward":return game.db.title(reward)
  "CountBasicReward":return game.db.ui("Build actions ×%d","建造操作次数 ×%d")%int(reward.get("rewardCount",1))+("\n"+description if not description.is_empty() else "")
  "MainCoreDroneReward":return game.db.ui("Add %d head drones.","增加 %d 架头部无人机。")%int(reward.get("dronesCount",1))+("\n"+description if not description.is_empty() else "")
  "MainCoreTurretReward":return game.db.ui("Equip the head weapon.","替换蜈蚣头部武器。")+("\n"+description if not description.is_empty() else "")
 if not description.is_empty():return description
 if reward.get("class")=="BlockReward":return game.db.ui("Add %d modules. Choose an empty mount after selection.","获得 %d 个模块，选择后放入体节空位。")%int(reward.get("coresCount",1))
 return game.db.ui("Upgrade applies immediately after selection.","选择后立即应用此项强化。")
func label(parent:Node,value:String,px:int)->Label:
 var l=Label.new();l.text=value;l.add_theme_font_size_override("font_size",px);l.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func layout_board():
 board.size=Vector2(minf(1120,size.x-64),minf(650,size.y-64));board.position=(size-board.size)*.5
func focus_first():
 for b in buttons:
  if not b.disabled:b.grab_focus();return
 postpone_button.grab_focus()
