extends Control
const Ink=preload("res://scripts/blue_ink.gd")
const UI=preload("res://scripts/game_ui.gd")
var game
var board:PanelContainer
var buttons:Array[Button]=[]
var faces:Array[VBoxContainer]=[]
var effect_labels:Array[Label]=[]
var postpone_button:Button
var recycle_button:Button
var epoch=0
const RARITY_COLORS=[UI.TEAL,Color("79bdff"),Color("c1a0ff"),UI.AMBER]
func setup(owner_game,offers:Array,token:int):
 game=owner_game;epoch=token
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_STOP
 theme=UI.theme();UI.protect(self)
 queue_redraw()
 board=PanelContainer.new();add_child(board)
 var paper=UI.style(Color(UI.BG,.97),Color("28505a"),24)
 paper.content_margin_left=28;paper.content_margin_right=28;paper.content_margin_top=24;paper.content_margin_bottom=24
 board.add_theme_stylebox_override("panel",paper)
 var stack=VBoxContainer.new();stack.add_theme_constant_override("separation",16);board.add_child(stack)
 var heading=HBoxContainer.new();stack.add_child(heading)
 var title=label(heading,game.db.ui("EVOLVE","蜕变"),30);title.size_flags_horizontal=SIZE_EXPAND_FILL
 label(heading,game.db.ui("▣  %d","▣  %d")%game.run.packs,17)
 var subtitle=label(stack,game.db.ui("CHOOSE YOUR NEXT MUTATION","选择下一次进化"),17);subtitle.add_theme_color_override("font_color",UI.MUTED)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",18);row.size_flags_vertical=SIZE_EXPAND_FILL;stack.add_child(row)
 for i in offers.size():
  var reward:Dictionary=offers[i]
  var rarity=clampi(int(reward.get("rarity",0)),0,3);var accent=RARITY_COLORS[rarity]
  var b=Button.new();b.size_flags_horizontal=SIZE_EXPAND_FILL;b.custom_minimum_size=Vector2(0,405);b.disabled=not game.run.can_reward(reward);row.add_child(b)
  b.tooltip_text=game.db.title(reward)+"\n"+effect_text(reward)
  for key in ["normal","hover","pressed","disabled","focus"]:
   var fill=Color("132d38") if key=="normal" else Color("21434b")
   if key=="disabled":fill=Color("16232c")
   var style=UI.style(fill,Color(accent,.4) if key=="normal" else accent,18)
   style.set_corner_radius_all(12)
   if key=="focus":style.bg_color=Color.TRANSPARENT
   b.add_theme_stylebox_override(key,style)
  b.pressed.connect(func():game.choose_reward(reward,epoch));buttons.append(b)
  var face=VBoxContainer.new();face.set_anchors_and_offsets_preset(PRESET_FULL_RECT);face.offset_left=20;face.offset_right=-20;face.offset_top=18;face.offset_bottom=-18;face.add_theme_constant_override("separation",10);face.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(face);faces.append(face)
  var top=HBoxContainer.new();top.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(top)
  var rarity_name=[game.db.ui("COMMON","普通"),game.db.ui("RARE","稀有"),game.db.ui("EPIC","史诗"),game.db.ui("LEGENDARY","传说")][rarity]
  var rarity_label=label(top,rarity_name,16);rarity_label.add_theme_color_override("font_color",accent);rarity_label.size_flags_horizontal=SIZE_EXPAND_FILL
  label(top,"0%d"%(i+1),15).add_theme_color_override("font_color",UI.MUTED)
  var image=TextureRect.new();image.texture=game.db.reward_sprite(reward);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size.y=170;image.size_flags_vertical=SIZE_EXPAND_FILL;image.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(image)
  var name_label=label(face,game.db.title(reward),23);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;name_label.custom_minimum_size.y=54;name_label.max_lines_visible=2;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  var rule=HSeparator.new();rule.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(rule)
  var effect=label(face,short_effect(reward),27);effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;effect.custom_minimum_size.y=38;effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;effect.max_lines_visible=1;effect.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;effect.add_theme_color_override("font_color",UI.TEXT);effect_labels.append(effect)
  var action=game.db.ui("GROW  →","生长  →") if reward.get("class")=="BlockReward" else game.db.ui("EVOLVE  →","进化  →")
  if b.disabled:action=game.db.ui("UNAVAILABLE","暂不可用")
  var action_label=label(face,action,17);action_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;action_label.add_theme_color_override("font_color",accent)
  if b.disabled:face.modulate=Color(1,1,1,.55)
 if not offers.any(func(r):return game.run.can_reward(r)):
  subtitle.text=game.db.ui("NO AVAILABLE MUTATION · KEEP FOR LATER","暂无可用进化 · 奖励可暂存")
 var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",16);stack.add_child(footer)
 postpone_button=Button.new();postpone_button.text=game.db.ui("ESC  ·  LATER","ESC  ·  暂存");postpone_button.pressed.connect(game.postpone_rewards);footer.add_child(postpone_button)
 var gap=Control.new();gap.size_flags_horizontal=SIZE_EXPAND_FILL;footer.add_child(gap)
 recycle_button=Button.new();recycle_button.text=game.db.ui("RECYCLE  ↻","回收  ↻");recycle_button.pressed.connect(func():game.recycle_reward(epoch));footer.add_child(recycle_button)
 resized.connect(layout_board);layout_board.call_deferred()
func effect_text(reward:Dictionary)->String:
 if reward.get("class")=="BlockReward":return game.db.armament_description(reward)+"\n"+game.db.ui("One new element, one new segment. Drag to choose its position.","获得一个新元素，新增一节身体。拖放选择它的位置。")
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
 board.size=Vector2(minf(1120,size.x-64),minf(650,size.y-48));board.position=(size-board.size)*.5
func focus_first():
 for b in buttons:
  if not b.disabled:b.grab_focus();return
 postpone_button.grab_focus()

func short_effect(reward:Dictionary)->String:
 match str(reward.get("class","")):
  "BlockReward":return game.db.ui("+1 SEGMENT","+1  体节")
  "PercentBasicReward":return "%+.0f%%"%(float(reward.get("percent",0))*100)
  "CountBasicReward":return "×%d"%int(reward.get("rewardCount",1))
  "MainCoreDroneReward":return game.db.ui("+%d DRONES","+%d  蜂群")%int(reward.get("dronesCount",1))
  "MainCoreTurretReward":return game.db.ui("HEAD WEAPON","头部武装")
 return game.db.ui("MUTATION","变异强化")
func _draw():
 draw_rect(Rect2(Vector2.ZERO,size),Color(UI.BG,.84))
 for i in 16:
  var x=size.x*.5+(i-8)*90
  draw_line(Vector2(x,0),Vector2(x-240,size.y),Color(UI.TEAL,.035),1,true)

func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo:
  var index=int(event.keycode)-KEY_1
  if index>=0 and index<buttons.size() and not buttons[index].disabled:
   get_viewport().set_input_as_handled();buttons[index].pressed.emit()
