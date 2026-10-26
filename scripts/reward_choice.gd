extends Control
const Branches=preload("res://scripts/mutation_branches.gd")
const Passive=preload("res://scripts/passive_feedback.gd")
const UI=preload("res://scripts/game_ui.gd")
const Categories=preload("res://scripts/armament_categories.gd")
var game
var board:PanelContainer
var buttons:Array[Button]=[]
var faces:Array[VBoxContainer]=[]
var effect_labels:Array[Label]=[]
var progress_labels:Array[Label]=[]
var postpone_button:Button
var recycle_button:Button
var epoch=0
const RARITY_COLORS=[UI.MUTED,Color("c6a7ff"),Color("ff83c8"),UI.AMBER]
func setup(owner_game,offers:Array,token:int):
 game=owner_game;epoch=token
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_STOP
 theme=UI.theme();UI.protect(self)
 queue_redraw()
 board=PanelContainer.new();add_child(board)
 var paper=UI.style(Color(UI.BG,.97),Color(UI.TEAL,.5),26)
 paper.content_margin_left=28;paper.content_margin_right=28;paper.content_margin_top=24;paper.content_margin_bottom=24
 board.add_theme_stylebox_override("panel",paper)
 var stack=VBoxContainer.new();stack.add_theme_constant_override("separation",16);board.add_child(stack)
 var heading=HBoxContainer.new();stack.add_child(heading)
 var title=label(heading,game.db.ui("EVOLVE","蜕变"),30);title.size_flags_horizontal=SIZE_EXPAND_FILL
 label(heading,game.db.ui("%d PACKS","%d  奖励包")%game.run.packs,18)
 var subtitle=label(stack,game.db.ui("CHOOSE YOUR NEXT MUTATION","选择下一次进化"),17);subtitle.add_theme_color_override("font_color",UI.MUTED)
 var row=HBoxContainer.new();row.add_theme_constant_override("separation",18);row.size_flags_vertical=SIZE_EXPAND_FILL;stack.add_child(row)
 for i in offers.size():
  var reward:Dictionary=offers[i]
  var rarity=clampi(int(reward.get("rarity",0)),0,3);var accent=RARITY_COLORS[rarity]
  var b=Button.new();b.size_flags_horizontal=SIZE_EXPAND_FILL;b.custom_minimum_size=Vector2(0,405);b.disabled=not game.run.can_reward(reward);row.add_child(b)
  b.tooltip_text=reward_title(reward)+"\n"+effect_text(reward)
  for key in ["normal","hover","pressed","disabled","focus"]:
   var style=UI.card_style(key not in ["normal","disabled"])
   if key=="disabled":
    style.bg_color=Color(UI.PANEL,.65);style.border_color=Color(UI.MUTED,.2);style.shadow_size=0
   if key=="focus":style=UI.card_focus_style()
   b.add_theme_stylebox_override(key,style)
  b.pressed.connect(func():game.choose_reward(reward,epoch));buttons.append(b)
  var face=VBoxContainer.new();face.set_anchors_and_offsets_preset(PRESET_FULL_RECT);face.offset_left=28;face.offset_right=-28;face.offset_top=26;face.offset_bottom=-26;face.add_theme_constant_override("separation",10);face.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(face);faces.append(face)
  var top=HBoxContainer.new();top.add_theme_constant_override("separation",12);top.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(top)
  var rarity_name=[game.db.ui("COMMON","普通"),game.db.ui("RARE","稀有"),game.db.ui("EPIC","史诗"),game.db.ui("LEGENDARY","传说")][rarity]
  var rarity_label=label(top,rarity_name,16);rarity_label.add_theme_color_override("font_color",accent);rarity_label.size_flags_horizontal=SIZE_EXPAND_FILL
  var category=Categories.reward_badge(game.db,reward)
  var category_name=str(category.text)
  var tags=VBoxContainer.new();tags.name="RewardTags";tags.add_theme_constant_override("separation",4);tags.mouse_filter=MOUSE_FILTER_IGNORE;top.add_child(tags)
  var broad=UI.badge(tags,str(category.category),category.color,false,16);broad.name="RewardCategory";broad.size_flags_horizontal=SIZE_SHRINK_END
  var effect_tag=UI.badge(tags,category_name,category.color,true,20 if game.db.language=="Chinese (simplified)" else 18);effect_tag.name="RewardEffectTag";effect_tag.size_flags_horizontal=SIZE_SHRINK_END
  b.tooltip_text=str(category.category)+" · "+category_name+" · "+b.tooltip_text
  var image=TextureRect.new();image.texture=reward_art(reward);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size.y=142;image.size_flags_vertical=SIZE_EXPAND_FILL;image.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(image)
  var name_label=label(face,reward_title(reward),23);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;name_label.custom_minimum_size.y=54;name_label.max_lines_visible=2;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  var rule=HSeparator.new();rule.mouse_filter=MOUSE_FILTER_IGNORE;face.add_child(rule)
  var effect=label(face,short_effect(reward),27);effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;effect.custom_minimum_size.y=38;effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;effect.max_lines_visible=1;effect.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;effect.add_theme_color_override("font_color",UI.TEXT);effect_labels.append(effect)
  if reward.has("mutation_branch"):
   effect.add_theme_font_size_override("font_size",21)
   face.add_theme_constant_override("separation",8);face.offset_top=22;face.offset_bottom=-22
   image.custom_minimum_size.y=52;name_label.custom_minimum_size.y=46;effect.custom_minimum_size.y=30
   var branch_desc=label(face,game.db.text(reward.rewardDesc),15);branch_desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;branch_desc.max_lines_visible=4;branch_desc.clip_text=true;branch_desc.custom_minimum_size.y=96;branch_desc.add_theme_constant_override("line_spacing",0);branch_desc.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;branch_desc.tooltip_text=branch_desc.text
  var action=game.db.ui("GROW  →","生长  →") if reward.get("class")=="BlockReward" else game.db.ui("EVOLVE  →","进化  →")
  if reward.get("class")=="CountBasicReward":action=game.db.ui("STORE CHARGES  →","领取次数  →")
  elif str(reward.get("class","")).ends_with("LevelUpReward") and game.player.reward_feedback(reward,game.combat.drones).status=="dormant":action=game.db.ui("STORE UPGRADE  →","储备升级  →")
  if b.disabled:action=game.db.ui("MAX LEVEL","已满级") if "LevelUp" in str(reward.get("class","")) and int(game.player.levels.get(reward.id,0))>=int(game.db.stores.PlayerDataStore.get("levelUpsAllowed",3)) else game.db.ui("UNAVAILABLE","暂不可用")
  var bottom=HBoxContainer.new();bottom.mouse_filter=MOUSE_FILTER_IGNORE;bottom.add_theme_constant_override("separation",8);face.add_child(bottom)
  if reward.has("mutation_branch"):action=game.db.ui("COMMIT PATH →","选定方向 →")
  var action_label=label(bottom,action,16);action_label.size_flags_horizontal=SIZE_EXPAND_FILL;action_label.add_theme_color_override("font_color",accent)
  var progress=progress_info(reward)
  var badge=label(bottom,progress.text,16 if reward.has("mutation_branch") else (21 if "LevelUp" in str(reward.get("class","")) else 15));badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;badge.add_theme_color_override("font_color",UI.TEXT);badge.tooltip_text=progress.tooltip;progress_labels.append(badge)
  b.tooltip_text+="\n"+progress.tooltip
  if b.disabled:face.modulate=Color(1,1,1,.72)
 if not offers.any(func(r):return game.run.can_reward(r)):
  subtitle.text=game.db.ui("NO AVAILABLE MUTATION · KEEP FOR LATER","暂无可用进化 · 奖励可暂存")
 var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",16);stack.add_child(footer)
 postpone_button=Button.new();postpone_button.custom_minimum_size=Vector2(190,52);postpone_button.add_theme_font_size_override("font_size",18);postpone_button.text=game.db.ui("ESC  ·  LATER","ESC  ·  暂存");postpone_button.pressed.connect(game.postpone_rewards);footer.add_child(postpone_button)
 var gap=Control.new();gap.size_flags_horizontal=SIZE_EXPAND_FILL;footer.add_child(gap)
 recycle_button=Button.new();recycle_button.custom_minimum_size=Vector2(128,52);recycle_button.add_theme_font_size_override("font_size",18);recycle_button.text=game.db.ui("RECYCLE","回收");recycle_button.pressed.connect(func():game.recycle_reward(epoch));footer.add_child(recycle_button)
 resized.connect(layout_board);layout_board.call_deferred()
func effect_text(reward:Dictionary)->String:
 if reward.has("mutation_branch"):return game.db.text(reward.rewardDesc)+"\n"+Branches.rule_text(game.db,reward)
 var kind=str(reward.get("class",""))
 if kind=="BlockReward":return game.db.armament_description(reward)+"\n"+(game.db.ui("New segment held in reserve. Open Armory and place it to activate.","获得待装新体节。进入身体装配，放入后才会生效。") if not compact_character() else game.db.ui("Module in reserve. Equip on an empty hardpoint or replace an old module.","获得待装模块。装入空挂点或替换旧模块。"))
 var description=""
 if reward.get("rewardDesc") is String:description=game.db.text(reward.rewardDesc)
 if description==str(reward.get("rewardDesc")):description=""
 match kind:
  "PercentBasicReward":return " · ".join(Passive.stat_fragments(game.db,{str(reward.rewardType):reward.percent}))+"\n"+game.db.ui("Applies to the corresponding global attribute immediately.","立即计入对应的全局属性。")
  "CrusedReward":return game.db.ui("BENEFIT: ","收益：")+" · ".join(Passive.stat_fragments(game.db,{str(reward.buffRewardType):reward.buffPercent}))+"\n"+game.db.ui("COST: ","代价：")+" · ".join(Passive.stat_fragments(game.db,{str(reward.debuffRewardType):reward.debuffPercent}))
  "CountBasicReward":return Passive.charge_text(game.db,{8:"swap",9:"duplicate",20:"move",21:"wall"}.get(int(reward.rewardType),"wall"),int(reward.get("count",reward.get("rewardCount",1))))+"\n"+game.db.ui("Receiving charges does not apply the action yet.","领取次数时不会自动执行操作。")
  "MainCoreDroneReward":return game.db.ui("Add %d head companions.","增加 %d 只头部伴生虫。")%int(reward.get("dronesCount",1))+"\n"+description
  "MainCoreTurretReward":return game.db.ui("Replace the head weapon immediately.","立即替换头部武器。")+"\n"+description
 var summary=Passive.upgrade_summary(game.db,reward)
 var status=game.player.reward_feedback(reward,game.combat.drones).status
 return summary+"\n"+Passive.status_text(game.db,status)+("\n"+description if not description.is_empty() else "")
func label(parent:Node,value:String,px:int)->Label:
 var l=Label.new();l.text=value;l.add_theme_font_size_override("font_size",px);l.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func layout_board():
 if not is_inside_tree() or is_queued_for_deletion():return
 # Keep the cards' text layout stable; shrinking the container alone lets its
 # minimum content height push actions into the footer on small windows.
 board.size=Vector2(1120,650)
 var factor=minf(1.0,minf((size.x-64)/1120.0,(size.y-64)/650.0))
 board.scale=Vector2.ONE*factor;board.position=(size-board.size*factor)*.5
func focus_first():
 for b in buttons:
  if not b.disabled:b.grab_focus();return
 postpone_button.grab_focus()

func short_effect(reward:Dictionary)->String:
 if reward.has("mutation_branch"):return Branches.brief(game.db,reward)
 match str(reward.get("class","")):
  "BlockReward":return game.db.ui("+1 SEGMENT","+1  体节") if not compact_character() else game.db.ui("+1 MODULE","+1  模块")
  "PercentBasicReward":return "%+.0f%%"%(float(reward.get("percent",0))*100)
  "CountBasicReward":return Passive.action_name(game.db,{8:"swap",9:"duplicate",20:"move",21:"wall"}.get(int(reward.rewardType),"wall"))+" ×%d"%int(reward.get("count",reward.get("rewardCount",1)))
  "CrusedReward":return "%+.0f%% / %+.0f%%"%[float(reward.buffPercent)*100,float(reward.debuffPercent)*100]
  "MainCoreDroneReward":return game.db.ui("+%d COMPANIONS","+%d  蜂群")%int(reward.get("dronesCount",1))
  "MainCoreTurretReward":return game.db.ui("HEAD WEAPON","头部武装")
 if str(reward.get("class","")).ends_with("LevelUpReward"):
  return game.db.ui("UPGRADE STORED","升级储备") if game.player.reward_feedback(reward,game.combat.drones).status=="dormant" else game.db.ui("LEVEL +1","等级 +1")
 return game.db.ui("MUTATION","变异强化")
func _draw():
 draw_rect(Rect2(Vector2.ZERO,size),Color(UI.BG,.84))
 # Broad, quiet pools of color keep the modal distinct from combat.
 draw_circle(Vector2(size.x*.24,size.y*.25),size.y*.4,Color(UI.TEAL,.035))
 draw_circle(Vector2(size.x*.78,size.y*.76),size.y*.48,Color(Color("b192ef"),.025))

func _unhandled_key_input(event:InputEvent):
 if event is InputEventKey and event.pressed and not event.echo:
  var index=int(event.keycode)-KEY_1
  if index>=0 and index<buttons.size() and not buttons[index].disabled:
   get_viewport().set_input_as_handled();buttons[index].pressed.emit()

func progress_info(reward:Dictionary)->Dictionary:
 var player=game.player
 var kind=str(reward.get("class",""))
 var data:Dictionary=game.db.stores.PlayerDataStore
 if reward.has("mutation_branch"):
  return {"text":game.db.ui("ONE PATH","本局二选一"),"tooltip":Branches.rule_text(game.db,reward)}
 if "LevelUp" in kind:
  var level=int(player.levels.get(reward.id,0));var cap=int(data.get("levelUpsAllowed",3))
  return {"text":"%d/%d"%[level,cap],"tooltip":game.db.ui("Current upgrade level / maximum level: %d / %d","当前升级等级 / 等级上限：%d / %d")%[level,cap]}
 if kind=="BlockReward":
  var occupied=player.parts.size()-1+player.pending.size()+(player.detached_module_count() if player.has_method("detached_module_count") else 0);var cap=player.module_cap() if player.has_method("module_cap") else int(data.maxBuiltCores)
  var owned=player.parts.filter(func(p):return p.id==reward.blockCore and p.hp>0).size()+player.pending.count(reward.blockCore)
  return {"text":game.db.ui("SLOTS %d/%d","槽位 %d/%d")%[occupied,cap],"tooltip":game.db.ui("Body slots used (including reserve) / total: %d / %d. This module owned: %d.","已用体节（含待装）/ 总上限：%d / %d。此模块持有：%d。")%[occupied,cap,owned]}
 if kind=="CountBasicReward":
  var action={8:"swap",9:"duplicate",20:"move",21:"wall"}.get(int(reward.rewardType),"")
  var count=int(player.actions.get(action,0))
  return {"text":game.db.ui("STORED %d","已存 %d")%count,"tooltip":Passive.action_name(game.db,action)+game.db.ui(" charges stored: %d. No storage limit; this is not an upgrade level.","已存次数：%d。次数储备无上限，此处不是升级等级。")%count}
 if kind=="MainCoreTurretReward":
  var equipped=1 if player.hq_weapon==reward.core else 0
  return {"text":game.db.ui("EQUIPPED %d/1","装备 %d/1")%equipped,"tooltip":game.db.ui("This head weapon equipped / head slot: %d / 1","此头部武器已装备 / 头部槽位：%d / 1")%equipped}
 if kind=="MainCoreDroneReward":
  var count=game.combat.drones.filter(func(d):return d.owner==0).size();var cap=int(data.maxHQDronesCount)
  return {"text":game.db.ui("SWARM %d/%d","蜂群 %d/%d")%[count,cap],"tooltip":game.db.ui("Head companions currently active / limit: %d / %d","当前头部伴生虫 / 上限：%d / %d")%[count,cap]}
 if kind in ["PercentBasicReward","CrusedReward"]:
  var stat=str(int(reward.get("rewardType",reward.get("buffRewardType",0))))
  var current=float(player.stats.get(stat,0))*100
  var amount=float(reward.get("percent",reward.get("buffPercent",0)))
  var cap=float(data.maxStatsPercentage if amount>=0 else data.minStatsPercentage)*100
  var result={"text":game.db.ui("STAT %+.0f%%","属性 %+.0f%%")%current,"tooltip":Passive.stat_name(game.db,stat)+game.db.ui(" accumulated / limit: %+.1f%% / %+.1f%%","累计 / 上限：%+.1f%% / %+.1f%%")%[current,cap]}
  if kind=="CrusedReward":
   var cost_stat=str(int(reward.debuffRewardType));var cost=float(player.stats.get(cost_stat,0))*100
   result.tooltip+="\n"+Passive.stat_name(game.db,cost_stat)+game.db.ui(" accumulated / lower limit: %+.1f%% / %+.1f%%","累计 / 下限：%+.1f%% / %+.1f%%")%[cost,float(data.minStatsPercentage)*100]
  return result
 return {"text":"—","tooltip":game.db.ui("No level counter","无等级计数")}

func reward_title(reward:Dictionary)->String:
 if reward.get("class")=="PercentBasicReward":return Passive.stat_name(game.db,str(int(reward.rewardType)))
 return game.db.title(reward)

func reward_art(reward:Dictionary)->Texture2D:
 if reward.get("class")=="CrusedReward":return UI.icon_texture("evolution")
 if reward.get("class")=="PercentBasicReward":
  match int(reward.rewardType):
   10,16:return UI.icon_texture("armor")
   11,12:return UI.icon_texture("fuel")
   2,13:return UI.icon_texture("rate")
   3,17:return UI.icon_texture("range")
   14,15:return game.db.core_sprite(game.db.named("Core_Gun_Cannon"))
  return UI.icon_texture("evolution")
 return game.db.reward_sprite(reward)

func compact_character()->bool:
 return game.player.get("character_id")!=null and game.player.get("character_id")!="centipede"
