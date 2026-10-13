extends Control
## Lightweight orbital instruments. Values are read-only; simulation is untouched.
const UI=preload("res://scripts/game_ui.gd")
const Symbols=preload("res://scripts/build_symbols.gd")
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
var cards:Array[PanelContainer]=[]

class Meter extends Control:
 var caption:Label
 var amount:Label
 var bar:ProgressBar
 var glyph="armor"
 var accent=UI.TEAL
 func _init(title:String,symbol:String,tint:Color):
  glyph=symbol;accent=tint;size=Vector2(120,124);mouse_filter=MOUSE_FILTER_IGNORE
  caption=Label.new();caption.text=title;caption.position=Vector2(0,78);caption.size=Vector2(120,20);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",13);caption.add_theme_color_override("font_color",UI.MUTED);caption.mouse_filter=MOUSE_FILTER_IGNORE;add_child(caption)
  amount=Label.new();amount.position=Vector2(-14,99);amount.size=Vector2(148,23);amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;amount.add_theme_font_size_override("font_size",15);amount.add_theme_color_override("font_color",UI.TEXT);amount.mouse_filter=MOUSE_FILTER_IGNORE;add_child(amount)
  bar=ProgressBar.new();bar.min_value=0;bar.max_value=1;bar.step=.001;bar.visible=false;add_child(bar)
 func _draw():
  var at=Vector2(60,40)
  draw_circle(at,37,Color(UI.BG,.95),true,-1,true)
  for i in 20:
   var a=-PI*.8+i*TAU*.8/20
   draw_arc(at,34,a,a+TAU*.8/20*.66,5,accent if float(i)/20<bar.value else Color(UI.MUTED,.22),4,true)
  Symbols.draw(self,glyph,at,1.1,accent)
 func reading(current:float,limit:float,value:String):
  amount.text=value
  bar.value=clampf(current/limit,0,1) if is_finite(current) and is_finite(limit) and limit>0 else 0
  queue_redraw()
 func capacity(current:int,limit:int,unlimited:String):
  reading(current,limit,"%d / %d"%[maxi(0,current),limit] if limit>0 else "%d / %s"%[maxi(0,current),unlimited])

func setup(owner_game):
 game=owner_game;UI.protect(self);theme=UI.theme()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE
 mission=label(self,game.db.title(game.selected_mission),17)
 health=meter(tr_text("甲壳","CARAPACE"),"armor",UI.TEAL)
 fuel=meter(tr_text("推进","THRUST"),"damage",UI.AMBER)
 danger=meter(tr_text("威胁","THREAT"),"range",Color("ff8275"))
 modules=meter(tr_text("体节","SEGMENTS"),"grid",UI.TEAL)
 drones=meter(tr_text("蜂群","SWARM"),"rate",UI.AMBER)
 timer=label(self,"",23);timer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 counters=label(self,"",16);counters.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 build_button=UI.button(self,tr_text("武装  E","ARMORY  E"),Rect2(0,0,190,44),game.show_build,"grid")
 build_button.add_theme_font_size_override("font_size",16)
 for state in ["normal","hover","pressed","focus"]:
  build_button.add_theme_stylebox_override(state,UI.style(UI.PANEL if state=="normal" else Color("21434b"),UI.TEAL,12,8))
 build_button.size=Vector2(190,44)
 radar_label=label(self,tr_text("扫描  TAB","SCAN  TAB"),13)
 keys=label(self,tr_text("WASD  移动     ⇧  推进     E  武装     ESC  暂停","WASD  MOVE     ⇧  BOOST     E  ARMORY     ESC  PAUSE"),13)
 resized.connect(layout_hud);layout_hud.call_deferred();refresh()
func tr_text(zh:String,en:String)->String:return game.db.ui(en,zh)
func label(parent:Node,value:String,px:int)->Label:
 var l=Label.new();l.text=value;l.add_theme_font_size_override("font_size",px);l.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func meter(title:String,symbol:String,tint:Color):
 var m=Meter.new(title,symbol,tint);add_child(m);return m
func layout_hud():
 mission.position=Vector2(32,18)
 health.position=Vector2(20,50);fuel.position=Vector2(142,50)
 danger.position=Vector2((size.x-120)/2,65)
 timer.position=Vector2(size.x/2-150,16);timer.size=Vector2(300,32)
 counters.position=Vector2(size.x/2-150,49);counters.size=Vector2(300,24)
 modules.position=Vector2(size.x-262,20);drones.position=Vector2(size.x-140,20)
 build_button.position=Vector2(size.x-234,151)
 radar_label.position=Vector2(size.x-187,size.y-265)
 keys.position=Vector2(32,size.y-39)
 queue_redraw()
func _draw():
 draw_style_box(UI.style(Color(UI.BG,.88),Color(UI.TEAL,.2),14),Rect2(14,10,258,171))
 draw_style_box(UI.style(Color(UI.BG,.88),Color(UI.TEAL,.2),14),Rect2(size.x-274,10,260,136))
 draw_style_box(UI.style(Color(UI.BG,.9),Color(UI.TEAL,.2),12),Rect2(size.x/2-162,10,324,65))
 draw_style_box(UI.style(Color(UI.BG,.9),Color(UI.TEAL,.2),18),Rect2(size.x/2-65,75,130,119))
 draw_style_box(UI.style(Color(UI.BG,.9),Color.TRANSPARENT,9),Rect2(20,size.y-45,keys.size.x+24,34))
 draw_style_box(UI.style(Color(UI.BG,.88),Color(UI.TEAL,.2),8),Rect2(size.x-205,size.y-272,170,32))
func refresh():
 if game.run==null:return
 var p=game.player;var run=game.run
 mission.text=game.db.title(game.selected_mission)
 health.reading(p.parts[0].hp,p.parts[0].max_hp,"%d / %d"%[maxf(0,p.parts[0].hp),maxf(0,p.parts[0].max_hp)] if p.parts[0].max_hp>0 else "—")
 var percent=roundi(maxf(0,p.fuel)/p.max_fuel*100) if p.max_fuel>0 else 0
 fuel.reading(p.fuel,p.max_fuel,"%d / %d · %d%%"%[maxf(0,p.fuel),p.max_fuel,percent] if p.max_fuel>0 else tr_text("未装燃料箱","NO TANK"))
 danger.reading(run.heat,1.0,"%d%%"%roundi(maxf(0,run.heat)*100))
 modules.capacity(p.parts.size()-1,int(game.db.stores.PlayerDataStore.maxBuiltCores),tr_text("无上限","∞"))
 var count=game.combat.drones.filter(func(d):return d.owner==0).size()
 drones.capacity(count,int(game.db.stores.PlayerDataStore.maxHQDronesCount),tr_text("无上限","∞"))
 var countdown=bool(game.selected_mission.get("isTimerCountingDown",false))
 var seconds=maxf(0,run.duration-run.elapsed) if countdown else maxf(0,run.elapsed)
 timer.text=(tr_text("剩余 ","TIME LEFT ") if countdown else tr_text("已进行 ","ELAPSED "))+"%02d:%02d"%[int(seconds)/60,int(seconds)%60]
 counters.text=tr_text("▣  %d     ◈  %d","▣  %d     ◈  %d")%[run.packs,run.scraps]
