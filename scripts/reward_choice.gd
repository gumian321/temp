extends Control
const Ink=preload("res://scripts/blue_ink.gd")
var game
var board:PanelContainer
var buttons:Array[Button]=[]
var postpone_button:Button
var recycle_button:Button
var epoch=0
func setup(owner_game,offers:Array,token:int):
 game=owner_game;epoch=token
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 theme=Ink.theme()
 board=PanelContainer.new();add_child(board)
 var style=Ink.box(Color("f9f6ee"),Color("9cb2c9"),1);style.set_corner_radius_all(16)
 style.content_margin_left=26;style.content_margin_right=26;style.content_margin_top=22;style.content_margin_bottom=22
 board.add_theme_stylebox_override("panel",style)
 var stack=VBoxContainer.new();stack.add_theme_constant_override("separation",18);board.add_child(stack)
 var heading=HBoxContainer.new();stack.add_child(heading)
 var title=label(heading,game.db.ui("Choose one reward","选择一项奖励"),30);title.size_flags_horizontal=SIZE_EXPAND_FILL
 label(heading,game.db.ui("Queued: %d","待领 %d 包")%game.run.packs,18)
 label(stack,game.db.ui("Combat paused · Choose a module, then place it. Other rewards apply immediately.","战斗已暂停 · 选择模块后直接安放，属性与操作奖励立即生效。"),18)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",18);row.size_flags_vertical=SIZE_EXPAND_FILL;stack.add_child(row)
 for reward in offers:
  var b=Button.new();b.size_flags_horizontal=SIZE_EXPAND_FILL;b.custom_minimum_size=Vector2(0,270);b.disabled=not game.run.can_reward(reward);row.add_child(b)
  b.pressed.connect(func():game.choose_reward(reward,epoch));buttons.append(b)
  var face=VBoxContainer.new();face.set_anchors_and_offsets_preset(PRESET_FULL_RECT);face.offset_left=18;face.offset_right=-18;face.offset_top=20;face.offset_bottom=-20;face.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(face)
  var image=TextureRect.new();image.texture=game.db.reward_sprite(reward);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size.y=115;image.size_flags_vertical=SIZE_EXPAND_FILL;image.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(image)
  var name_label=label(face,game.db.title(reward),22);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  var action=game.db.ui("Select → place","选择 → 安放") if reward.get("class")=="BlockReward" else game.db.ui("Select → apply","选择 → 生效")
  if b.disabled:action=game.db.ui("Currently unavailable","当前不可选")
  var action_label=label(face,action,17);action_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 if not offers.any(func(r):return game.run.can_reward(r)):
  var message=label(stack,game.db.ui("No available choice. This pack is retained; you can continue or recycle it yourself.","当前无可选奖励。本包会保留，可稍后继续或自行回收。"),19);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",16);stack.add_child(footer)
 postpone_button=Button.new();postpone_button.text=game.db.ui("Keep for later · Esc","暂存并继续 · Esc");postpone_button.pressed.connect(game.postpone_rewards);footer.add_child(postpone_button)
 var gap=Control.new();gap.size_flags_horizontal=SIZE_EXPAND_FILL;footer.add_child(gap)
 recycle_button=Button.new();recycle_button.text=game.db.ui("Recycle this pack","回收此奖励包");recycle_button.pressed.connect(func():game.recycle_reward(epoch));footer.add_child(recycle_button)
 resized.connect(layout_board);layout_board.call_deferred()
func label(parent:Node,value:String,px:int)->Label:
 var l=Label.new();l.text=value;l.add_theme_font_size_override("font_size",px);l.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func layout_board():
 board.size=Vector2(minf(1120,size.x-64),minf(480,size.y-80));board.position=(size-board.size)*.5
func focus_first():
 for b in buttons:
  if not b.disabled:b.grab_focus();return
 postpone_button.grab_focus()
