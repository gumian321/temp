extends Control
## Field instruments: ivory paper, ink silhouettes and quiet edge-aligned readouts.
const UI=preload("res://scripts/game_ui.gd")
const INK=Color("173b55")
const QUIET=Color("647d86")
const PAPER=Color("f4f1e6")
const TEAL=Color("267f80")
const AMBER=Color("b58132")
const ALERT=Color("b94c3d")
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
var plaque:StyleBoxTexture

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
  icon.texture=UI.icon_texture(glyph)
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
  amount.text=value
  bar.value=clampf(current/limit,0,1) if is_finite(current) and is_finite(limit) and limit>0 else 0
  warning=(bar.value<=.25 if glyph in ["armor","fuel"] else current>=.8 if glyph=="threat" else false)
  amount.add_theme_color_override("font_color",ALERT if warning else INK)
  queue_redraw()
 func capacity(current:int,limit:int,unlimited:String):
  reading(current,limit,"%d / %d"%[maxi(0,current),limit] if limit>0 else "%d / %s"%[maxi(0,current),unlimited])

class ArmoryButton extends Button:
 func _ready():
  var icon=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture=UI.icon_texture("gear");icon.position=Vector2(7,8);icon.size=Vector2(26,26);icon.mouse_filter=MOUSE_FILTER_IGNORE;add_child(icon)
  var key=Label.new();key.text="E";key.position=Vector2(39,10);key.add_theme_font_size_override("font_size",15);key.add_theme_color_override("font_color",INK);key.mouse_filter=MOUSE_FILTER_IGNORE;add_child(key)

func setup(owner_game):
 game=owner_game;UI.protect(self);theme=UI.theme();plaque=rail_skin()
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
  style.modulate_color=Color.WHITE if state=="normal" else Color("d6ede7")
  style.content_margin_left=0;style.content_margin_right=0;style.content_margin_top=0;style.content_margin_bottom=0
  build_button.add_theme_stylebox_override(state,style)
 build_button.size=Vector2(60,42)
 radar_label=label(self,tr_text("扫描   TAB","SCAN   TAB"),11)
 keys=label(self,tr_text("WASD  移动    ⇧  推进    ESC  暂停","WASD  MOVE    ⇧  BOOST    ESC  PAUSE"),11)
 skill_icon=TextureRect.new();skill_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;skill_icon.texture=UI.icon_texture("evolution");skill_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;skill_icon.mouse_filter=MOUSE_FILTER_IGNORE;skill_icon.size=Vector2(42,42);add_child(skill_icon)
 skill_label=label(self,"",16)
 resized.connect(layout_hud);layout_hud.call_deferred();refresh()
func tr_text(zh:String,en:String)->String:return game.db.ui(en,zh)
func label(parent:Node,value:String,px:int)->Label:
 var l=Label.new();l.text=value;l.add_theme_font_size_override("font_size",px);l.add_theme_color_override("font_color",INK);l.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func meter(symbol:String,tint:Color,dimensions:Vector2):
 var m=Meter.new(symbol,tint,dimensions);add_child(m);return m
func layout_hud():
 mission.position=Vector2(66,18);mission.size=Vector2(190,18)
 health.position=Vector2(20,38);fuel.position=Vector2(66,76)
 timer.position=Vector2(size.x/2-100,18);timer.size=Vector2(200,32)
 danger.position=Vector2(size.x/2-68,54)
 counters.position=Vector2(size.x/2-95,78);counters.size=Vector2(190,19)
 modules.position=Vector2(size.x-284,34);drones.position=Vector2(size.x-182,34)
 build_button.position=Vector2(size.x-74,28)
 radar_label.position=Vector2(size.x-202,size.y-257);radar_label.size=Vector2(170,18)
 skill_icon.position=Vector2(456,size.y-90);skill_label.position=Vector2(506,size.y-82);skill_label.size=Vector2(360,30)
 keys.position=Vector2(24,size.y-32);keys.size=Vector2(400,20)
 queue_redraw()
func rail_skin()->StyleBoxTexture:
 var atlas=AtlasTexture.new();atlas.atlas=load("res://assets/ui_overhaul/light_hud_rail.png");atlas.region=Rect2(62,257,2048,196);atlas.filter_clip=true
 var image=atlas.get_image();image.resize(320,31,Image.INTERPOLATE_LANCZOS)
 var skin=StyleBoxTexture.new();skin.texture=ImageTexture.create_from_image(image)
 skin.texture_margin_left=17;skin.texture_margin_right=17;skin.texture_margin_top=6;skin.texture_margin_bottom=6
 return skin
func compact_skin()->StyleBoxTexture:
 # Scale the generated square plaque first, so corner art is never stretched
 # into long spikes. The 18px slices preserve its small organic frame.
 var image=UI.Art.panel_texture("panel").get_image()
 image.resize(112,100,Image.INTERPOLATE_LANCZOS)
 var skin=StyleBoxTexture.new();skin.texture=ImageTexture.create_from_image(image)
 skin.texture_margin_left=18;skin.texture_margin_right=18;skin.texture_margin_top=18;skin.texture_margin_bottom=18
 return skin
func plate(rect:Rect2):
 draw_style_box(plaque,rect)
func instrument_backings()->Array[Rect2]:
 return [Rect2(58,58,220,20),Rect2(size.x/2-84,52,168,25),Rect2(size.x-306,28,226,42)]
func _draw():
 if not is_instance_valid(fuel):return
 for rect in instrument_backings():plate(rect)


func refresh():
 if game.run==null:return
 var p=game.player;var run=game.run
 mission.text=game.db.title(game.selected_mission)
 var ability=game.combat.character_abilities.state()
 var cooldown=float(ability.get("cooldown",0))
 var binding="Y" if game.joy_ui else OS.get_keycode_string(int(game.save.state.settings.bindings.get("character_skill",KEY_SPACE)))
 var ready=tr_text("就绪","READY") if cooldown<=0 else "%.1fs"%cooldown
 if p.character_id=="beetle":ready+=tr_text("  甲 %d","  ARMOR %d")%roundi(float(ability.armor))
 if p.character_id=="spider" and not ability.threads.is_empty():ready+=tr_text("  丝 %d","  THREADS %d")%ability.threads.size()
 skill_label.text=binding+"  ·  "+str(p.character_config.skill_name)+"  ·  "+ready
 skill_label.add_theme_color_override("font_color",TEAL if cooldown<=0 else QUIET)
 skill_icon.modulate=Color.WHITE if cooldown<=0 else Color(1,1,1,.45)
 skill_label.tooltip_text=str(p.character_config.passive)+" · "+str(p.character_config.weakness)
 health.reading(p.parts[0].hp,p.parts[0].max_hp,"%d / %d"%[maxf(0,p.parts[0].hp),maxf(0,p.parts[0].max_hp)] if p.parts[0].max_hp>0 else "—")
 var percent=roundi(maxf(0,p.fuel)/p.max_fuel*100) if p.max_fuel>0 else 0
 fuel.visible=p.max_fuel>0
 fuel.reading(p.fuel,p.max_fuel,"%d%%"%percent if p.max_fuel>0 else tr_text("未装燃料箱","NO TANK"))
 danger.reading(run.heat,1.0,"%d%%"%roundi(maxf(0,run.heat)*100))
 modules.capacity(p.parts.size()-1,p.module_cap(),"∞")
 var count=game.combat.drones.filter(func(d):return d.owner==0).size()
 drones.capacity(count,int(game.db.stores.PlayerDataStore.maxHQDronesCount),"∞")
 var countdown=bool(game.selected_mission.get("isTimerCountingDown",false))
 var seconds=maxf(0,run.duration-run.elapsed) if countdown else maxf(0,run.elapsed)
 timer.text="%02d:%02d"%[int(seconds)/60,int(seconds)%60]
 timer.tooltip_text=tr_text("剩余时间","Time remaining") if countdown else tr_text("已进行时间","Time elapsed")
 counters.text="▣  %d    ◈  %d"%[run.packs,run.scraps]
 queue_redraw()
