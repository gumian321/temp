extends Control
## Ink-black instruments framed by generated chalk chitin.
const UI=preload("res://scripts/game_ui.gd")
const CharcoalArt=preload("res://scripts/charcoal_art.gd")
const EncounterArt=preload("res://scripts/encounter_art.gd")
const INK=Color("efede4")
const QUIET=Color("aba9a3")
const PAPER=Color("080808")
const TEAL=Color("ff1764")
const AMBER=Color("d7d3c7")
const ALERT=Color("ff6c89")
var game
var health
var fuel
var danger
var modules
var drones
var mission:Label
var timer:Label
var counters:Label
var build_button:Button
var radar_label:Label
var keys:Label
var skill_icon:TextureRect
var skill_label:Label
var plaque:StyleBoxFlat
var streak_label:Label
var streak_detail:Label
var encounter_label:Label
var encounter_hint:Label
var supplies:Label
var escort_title:Label
var escort_status:Label
var escort_rule:Label
var escort_progress=0.0
var streak_fill=0.0

class Meter extends Control:
 var amount:Label
 var bar:ProgressBar
 var glyph="armor"
 var accent=TEAL
 var warning=false
 var icon:TextureRect
 func _init(symbol:String,tint:Color,dimensions:Vector2):
  glyph=symbol;accent=tint;custom_minimum_size=dimensions;size=dimensions;mouse_filter=MOUSE_FILTER_PASS
  amount=Label.new();amount.mouse_filter=MOUSE_FILTER_IGNORE;amount.add_theme_font_size_override("font_size",17);amount.add_theme_color_override("font_color",INK);add_child(amount)
  bar=ProgressBar.new();bar.min_value=0;bar.max_value=1;bar.step=.001;bar.visible=false;add_child(bar)
  if glyph=="armor":amount.position=Vector2(46,0);amount.size=Vector2(size.x-46,22)
  elif glyph=="fuel":amount.position=Vector2(20,0);amount.size=Vector2(size.x-20,16);amount.add_theme_font_size_override("font_size",12);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  elif glyph=="threat":amount.position=Vector2(size.x-40,0);amount.size=Vector2(40,18);amount.add_theme_font_size_override("font_size",12);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  else:amount.position=Vector2(30,2);amount.size=Vector2(size.x-30,24)
  amount.size.y=0
  icon=TextureRect.new();icon.mouse_filter=MOUSE_FILTER_IGNORE;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.texture=UI.icon_texture(glyph);icon.material=UI.icon_material()
  if glyph=="armor":icon.position=Vector2(0,0);icon.size=Vector2(40,38)
  elif glyph in ["fuel","threat"]:icon.position=Vector2(0,0);icon.size=Vector2(16,16)
  else:icon.position=Vector2(0,1);icon.size=Vector2(26,26)
  add_child(icon)
 func _draw():
  var tint=ALERT if warning else accent
  if glyph=="armor":
   track(Rect2(52,25,size.x-58,6),tint,10)
  elif glyph=="fuel":track(Rect2(20,7,size.x-104,3),tint,0)
  elif glyph=="threat":track(Rect2(21,8,size.x-67,3),tint,0)
 func track(rect:Rect2,tint:Color,divisions:int):
  draw_rect(rect,Color(INK,.15))
  draw_rect(Rect2(rect.position,Vector2(rect.size.x*bar.value,rect.size.y)),tint)
  if divisions>0:
   for i in range(1,divisions):
    var x=rect.position.x+rect.size.x*i/divisions
    draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),PAPER,1)
 func reading(current:float,limit:float,value:String):
  if amount.text!=value:amount.text=value
  var previous_fill=bar.value
  var previous_warning=warning
  bar.value=clampf(current/limit,0,1) if is_finite(current) and is_finite(limit) and limit>0 else 0
  warning=(bar.value<=.25 if glyph in ["armor","fuel"] else current>=.8 if glyph=="threat" else false)
  var text_color=ALERT if warning else INK
  if amount.get_theme_color("font_color")!=text_color:amount.add_theme_color_override("font_color",text_color)
  if bar.value!=previous_fill or warning!=previous_warning:queue_redraw()
 func capacity(current:int,limit:int,unlimited:String):
  reading(current,limit,"%d / %d"%[maxi(0,current),limit] if limit>0 else "%d / %s"%[maxi(0,current),unlimited])

class ArmoryButton extends Button:
 func _ready():
  var icon=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture=UI.icon_texture("gear");icon.material=UI.icon_material();icon.position=Vector2(7,8);icon.size=Vector2(26,26);icon.mouse_filter=MOUSE_FILTER_IGNORE;add_child(icon)
  var key=Label.new();key.text="E";key.position=Vector2(39,10);key.add_theme_font_size_override("font_size",15);key.add_theme_color_override("font_color",INK);key.mouse_filter=MOUSE_FILTER_IGNORE;add_child(key)

func setup(owner_game):
 game=owner_game;UI.protect(self);theme=UI.theme();plaque=rail_skin()
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE
 mission=label(self,game.db.title(game.selected_mission),13);mission.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 health=meter("armor",TEAL,Vector2(244,38));health.tooltip_text=tr_text("甲壳耐久","Carapace integrity")
 fuel=meter("fuel",AMBER,Vector2(198,23));fuel.tooltip_text=tr_text("推进燃料","Boost fuel")
 danger=meter("threat",AMBER,Vector2(136,23));danger.tooltip_text=tr_text("威胁等级","Threat level")
 modules=meter("body",TEAL,Vector2(96,30));modules.tooltip_text=tr_text("体节 / 上限","Body segments / limit")
 drones=meter("drone",AMBER,Vector2(90,30));drones.tooltip_text=tr_text("蜂群 / 上限","Head drones / limit")
 timer=label(self,"",24);timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 counters=label(self,"",12);counters.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;counters.tooltip_text=tr_text("补给箱 · 零件","Supply packs · scrap")
 build_button=ArmoryButton.new();add_child(build_button);build_button.size=Vector2(60,42);build_button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;build_button.pressed.connect(game.show_build);build_button.tooltip_text=tr_text("武装 [E]","Armory [E]")
 for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]:
  var style=compact_skin()
  style.bg_color=Color("080808",0.94) if state=="normal" else Color("36202a",0.96)
  style.border_color=Color(TEAL,0.6 if state=="normal" else 1.0)
  style.content_margin_left=0;style.content_margin_right=0;style.content_margin_top=0;style.content_margin_bottom=0
  build_button.add_theme_stylebox_override(state,style)
 build_button.size=Vector2(60,42)
 radar_label=label(self,tr_text("扫描   TAB","SCAN   TAB"),11)
 keys=label(self,tr_text("WASD  移动    ⇧  推进    ESC  暂停","WASD  MOVE    ⇧  BOOST    ESC  PAUSE"),11)
 skill_icon=TextureRect.new();skill_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;skill_icon.texture=UI.icon_texture("evolution");skill_icon.material=UI.icon_material();skill_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;skill_icon.mouse_filter=MOUSE_FILTER_IGNORE;skill_icon.size=Vector2(42,42);add_child(skill_icon)
 skill_label=label(self,"",16)
 streak_label=label(self,"",20);streak_detail=label(self,"",12)
 encounter_label=label(self,"",17);encounter_hint=label(self,"",13)
 encounter_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;encounter_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 supplies=label(self,"",14);supplies.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 escort_title=label(self,"",15);escort_status=label(self,"",14);escort_rule=label(self,"",12)
 for field in [escort_title,escort_status,escort_rule]:
  field.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;field.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;field.visible=false
 escort_title.add_theme_color_override("font_color",Color("83d9c1"))
 for field in [streak_label,streak_detail,encounter_label,encounter_hint,supplies]:field.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 resized.connect(layout_hud);layout_hud.call_deferred();refresh()
func tr_text(zh:String,en:String)->String:return game.db.ui(en,zh)
func label(parent:Node,value:String,px:int)->Label:
 var l=Label.new();l.text=value;l.add_theme_font_size_override("font_size",px);l.add_theme_color_override("font_color",INK);l.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func meter(symbol:String,tint:Color,dimensions:Vector2):
 var m=Meter.new(symbol,tint,dimensions);add_child(m);return m
func layout_hud():
 var narrow=size.x<1100
 mission.position=Vector2(66,18);mission.size=Vector2(190,18)
 health.position=Vector2(20,38);fuel.position=Vector2(66,76)
 timer.position=Vector2(size.x/2-100,12);timer.size=Vector2(200,36)
 danger.position=Vector2(size.x/2-68,48)
 counters.position=Vector2(size.x/2-95,71);counters.size=Vector2(190,23)
 modules.position=Vector2(size.x-284,34);drones.position=Vector2(size.x-182,34)
 build_button.position=Vector2(size.x-74,28)
 radar_label.position=Vector2(size.x-182,size.y-257);radar_label.size=Vector2(142,18)
 var skill_bounds=skill_panel_rect()
 skill_icon.position=skill_bounds.position+Vector2(12,8);skill_label.position=skill_bounds.position+Vector2(62,16);skill_label.size=Vector2(skill_bounds.size.x-92,30)
 skill_label.add_theme_font_size_override("font_size",14 if skill_bounds.size.x<360 else 16);skill_label.clip_text=true;skill_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 keys.position=Vector2(46,size.y-32);keys.size=Vector2(350,20)
 streak_label.autowrap_mode=TextServer.AUTOWRAP_OFF;streak_label.clip_text=true;streak_label.max_lines_visible=1
 streak_label.add_theme_font_size_override("font_size",16 if narrow else 20)
 streak_label.position=Vector2(24,114);streak_label.size=Vector2(192 if narrow else 284,28)
 streak_detail.add_theme_font_size_override("font_size",11 if narrow else 12)
 streak_detail.position=Vector2(24,147);streak_detail.size=Vector2(192 if narrow else 284,20)
 var event_width=minf(448,size.x-488) if narrow else 448.0
 encounter_label.position=Vector2((size.x-event_width)/2,113);encounter_label.size=Vector2(event_width,25)
 encounter_hint.position=Vector2((size.x-event_width)/2,141);encounter_hint.size=Vector2(event_width,20)
 supplies.position=Vector2(size.x-290,89);supplies.size=Vector2(252,24)
 escort_title.position=Vector2(size.x/2-232,180);escort_title.size=Vector2(464,23)
 escort_status.position=Vector2(size.x/2-232,205);escort_status.size=Vector2(464,23)
 escort_rule.position=Vector2(size.x/2-232,230);escort_rule.size=Vector2(464,20)
 queue_redraw()
func rail_skin()->StyleBoxFlat:
 var skin=UI.flat_style(Color("080808",0.94),Color(INK,0.7),8)
 skin.shadow_color=Color("090510",0.28);skin.shadow_size=4;skin.shadow_offset=Vector2(0,2)
 return skin
func compact_skin()->StyleBoxFlat:
 return UI.flat_style(Color("080808",0.94),Color(INK,0.7),8)
func plate(rect:Rect2,alert:bool=false):
 draw_style_box(CharcoalArt.panel_skin(alert,rect.size.y<=40),rect)
func instrument_backings()->Array[Rect2]:
 return [Rect2(12,10,270,88),Rect2(size.x/2-109,10,218,88),Rect2(size.x-306,22,296,56)]
func skill_panel_rect()->Rect2:
 var width=minf(432,maxf(240,size.x-496))
 return Rect2((size.x-width)/2,size.y-98,width,64)
func _draw():
 if not is_instance_valid(fuel):return
 for rect in instrument_backings():plate(rect)
 plate(skill_panel_rect())
 plate(Rect2(12,size.y-39,414,32))
 plate(Rect2(size.x-212,size.y-261,192,28))
 if is_instance_valid(streak_label) and streak_label.visible:
  var narrow=size.x<1100
  plate(Rect2(12,106,216 if narrow else 308,68))
  if streak_fill>0:draw_texture_rect(EncounterArt.decal("charge_lane"),Rect2(24,141,(192 if narrow else 284)*streak_fill,5),false,AMBER)
 if is_instance_valid(encounter_label) and encounter_label.visible:plate(Rect2(encounter_label.position-Vector2(12,7),Vector2(encounter_label.size.x+24,62)),true)
 if is_instance_valid(supplies) and supplies.visible:plate(Rect2(size.x-316,84,304,32))
 if is_instance_valid(escort_title) and escort_title.visible:
  draw_style_box(plaque,Rect2(size.x/2-244,176,488,80))
  draw_rect(Rect2(size.x/2-228,253,456*escort_progress,2),Color("83d9c1"))


func refresh():
 if game.run==null:return
 var p=game.player;var run=game.run
 mission.text=game.db.title(game.selected_mission)
 refresh_escort()
 var ability=game.combat.character_abilities.state()
 var cooldown=float(ability.get("cooldown",0))
 var binding="Y" if game.joy_ui else OS.get_keycode_string(int(game.save.state.settings.bindings.get("character_skill",KEY_SPACE)))
 var ready=tr_text("就绪","READY") if cooldown<=0 else "%.1fs"%cooldown
 if p.character_id=="beetle":ready+=tr_text("  甲 %d","  ARMOR %d")%roundi(float(ability.armor))
 if p.character_id=="spider" and not ability.threads.is_empty():ready+=tr_text("  丝 %d","  THREADS %d")%ability.threads.size()
 skill_label.text=binding+"  ·  "+str(p.character_config.skill_name)+"  ·  "+ready
 var skill_color=TEAL if cooldown<=0 else QUIET
 if skill_label.get_theme_color("font_color")!=skill_color:skill_label.add_theme_color_override("font_color",skill_color)
 skill_icon.modulate=Color.WHITE if cooldown<=0 else Color(1,1,1,.45)
 skill_label.tooltip_text=str(p.character_config.passive)+" · "+str(p.character_config.weakness)
 health.reading(p.parts[0].hp,p.parts[0].max_hp,"%d / %d"%[maxf(0,p.parts[0].hp),maxf(0,p.parts[0].max_hp)] if p.parts[0].max_hp>0 else "—")
 var percent=roundi(maxf(0,p.fuel)/p.max_fuel*100) if p.max_fuel>0 else 0
 fuel.visible=p.max_fuel>0
 fuel.reading(p.fuel,p.max_fuel,"%d%%"%percent if p.max_fuel>0 else tr_text("未装燃料箱","NO TANK"))
 danger.reading(run.heat,1.0,"%d%%"%roundi(maxf(0,run.heat)*100))
 modules.capacity(p.parts.size()-1,p.module_cap(),"∞")
 var count=0
 for drone in game.combat.drones:
  if drone.owner==0:count+=1
 drones.capacity(count,int(game.db.stores.PlayerDataStore.maxHQDronesCount),"∞")
 var countdown=bool(game.selected_mission.get("isTimerCountingDown",false))
 var seconds=maxf(0,run.duration-run.elapsed) if countdown else maxf(0,run.elapsed)
 timer.text="%02d:%02d"%[int(seconds)/60,int(seconds)%60]
 timer.tooltip_text=tr_text("剩余时间","Time remaining") if countdown else tr_text("已进行时间","Time elapsed")
 counters.text="▣  %d    ◈  %d"%[run.packs,run.scraps]
 var momentum=game.combat.momentum
 var old_status=[streak_label.visible,encounter_label.visible,supplies.visible,streak_fill]
 streak_label.visible=momentum.chain>=2 or momentum.burst_left>0
 streak_detail.visible=streak_label.visible
 if momentum.burst_left>0:
  streak_label.text=tr_text("狂热爆发  %.1f秒  ·  %d连杀","OVERDRIVE  %.1fs  ·  %d CHAIN")%[momentum.burst_left,momentum.chain]
  if size.x<1100:streak_label.text=tr_text("狂热 %.1f秒 · %d连杀","BURST %.1fs · %d CHAIN")%[momentum.burst_left,momentum.chain]
  if momentum.chain==0:streak_label.text=tr_text("狂热爆发  %.1f秒","OVERDRIVE  %.1fs")%momentum.burst_left
  streak_detail.text=tr_text("伤害 +25%  ·  装填 +35%","Damage +25%  ·  Reload +35%")
  streak_fill=momentum.burst_left/momentum.BURST_DURATION
 else:
  streak_label.text=tr_text("%d 连杀","%d CHAIN")%momentum.chain
  streak_detail.text=momentum.notice if momentum.notice_left>0 else (tr_text("再击杀 %d 触发狂热","%d more kills to overdrive")%maxi(0,momentum.next_burst-momentum.chain) if momentum.recovery<=0 else tr_text("狂热恢复  %.1f秒","Overdrive recharging  %.1fs")%momentum.recovery)
  streak_fill=momentum.remaining/momentum.CHAIN_WINDOW
 var encounter=run.encounters
 encounter_label.visible=encounter.phase!="quiet" or encounter.notice_left>0
 encounter_hint.visible=encounter_label.visible
 encounter_label.text=encounter.title(encounter.event_type)
 encounter_hint.text=encounter.notice if encounter.notice_left>0 else encounter.hint(encounter.event_type)
 for field in [streak_label,streak_detail,encounter_label,encounter_hint]:field.tooltip_text=field.text
 if encounter.phase=="warning":encounter_label.text+=tr_text(" · 即将出现"," · INCOMING")
 supplies.visible=run.packs>0 or not p.pending.is_empty()
 var build_key="B" if game.joy_ui else OS.get_keycode_string(int(game.save.state.settings.bindings.get("build",KEY_E)))
 supplies.text=tr_text("补给 ×%d · 待装 %d  [%s]","Supply ×%d · Pending %d  [%s]")%[run.packs,p.pending.size(),build_key]
 build_button.tooltip_text=tr_text("领取补给 / 身体装配 [%s]","Claim supplies / Armory [%s]")%build_key
 if old_status!=[streak_label.visible,encounter_label.visible,supplies.visible,streak_fill]:queue_redraw()

func refresh_escort():
 var brief:Dictionary=game.run.director.escort_brief()
 var was_visible=escort_title.visible;var previous=escort_progress
 for field in [escort_title,escort_status,escort_rule]:field.visible=not brief.is_empty()
 if brief.is_empty():
  if was_visible:queue_redraw()
  return
 escort_progress=brief.progress
 escort_title.text=tr_text("护航 · 商队 %d/%d  · 路程 %d%%  · 剩余 %d米","ESCORT · %d/%d  · %d%%  · %dm LEFT")%[brief.alive,brief.total,roundi(brief.progress*100),ceili(brief.distance/48)]
 match brief.state:
  "far":escort_status.text=tr_text("离队等待 · 返回商队旁（当前 %.1f米 / 范围 %.1f米）","WAITING · Return to convoy (%.1fm / %.1fm range)")%[brief.separation/48,brief.range/48]
  "regroup","blocked":escort_status.text=tr_text("等待领航 · 回到商队旁，沿已打通的路带队","REGROUP · Return to convoy and lead along an open tunnel")
  "ready":escort_status.text=tr_text("商队已集合 · 向终点箭头方向移动，带队开路","READY · Move toward the safe-zone arrow to lead the convoy")
  "arriving":escort_status.text=tr_text("正在进站 · 留在商队附近，守住最后一段路","ARRIVING · Stay close and defend the last stretch")
  _:escort_status.text=tr_text("正在跟随 · 保持靠近，清理沿路敌人","FOLLOWING · Stay close and clear enemies ahead") if brief.cave else tr_text("正在护送 · 靠近商队，它会自动前往终点","ESCORTING · Stay close while the convoy advances")
 if brief.state=="moving" and brief.separation>brief.range*.75:
  escort_status.text=tr_text("商队落后 · 放慢速度，超过 %.1f米会停下","SLOW DOWN · Convoy stops beyond %.1fm")%[brief.range/48]
 escort_rule.text=tr_text("绿色标记为商队 · 至少一艘抵达获胜，全部损失失败","Green markers: convoy · Deliver one to win; lose all and fail")
 if was_visible!=escort_title.visible or not is_equal_approx(previous,escort_progress):queue_redraw()
