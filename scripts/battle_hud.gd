extends Control
## Read-only presentation of live combat values; fill is clamped, simulation is not.
const Ink=preload("res://scripts/blue_ink.gd")
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

class Meter extends VBoxContainer:
 var caption:Label
 var amount:Label
 var bar:ProgressBar
 func _init(label:String):
  mouse_filter=Control.MOUSE_FILTER_IGNORE
  add_theme_constant_override("separation",4)
  var row=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(row)
  caption=Label.new();caption.text=label;caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(caption)
  amount=Label.new();amount.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(amount)
  bar=ProgressBar.new();bar.show_percentage=false;bar.min_value=0;bar.max_value=1;bar.step=0.001;bar.custom_minimum_size.y=7;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bar)
  var outline=Ink.box(Color("e6eceb"),Color("9db3c6"),1);outline.set_corner_radius_all(3)
  var fill=Ink.box(Ink.BLUE,Ink.BLUE,0);fill.set_corner_radius_all(3)
  bar.add_theme_stylebox_override("background",outline);bar.add_theme_stylebox_override("fill",fill)
 func reading(current:float,limit:float,value:String):
  amount.text=value
  bar.value=clampf(current/limit,0,1) if is_finite(current) and is_finite(limit) and limit>0 else 0
 func capacity(current:int,limit:int,unlimited:String):
  reading(current,limit,"%d / %d"%[maxi(0,current),limit] if limit>0 else "%d / %s"%[maxi(0,current),unlimited])

func setup(owner_game):
 game=owner_game
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 theme=Theme.new();theme.default_font=load("res://assets/fonts/NotoSansSC-Light.otf");theme.default_font_size=17
 theme.set_color("font_color","Label",Ink.INK)
 var left=card();mission=label(left,"",19);health=meter(left,tr_text("头部耐久","Head health"));fuel=meter(left,tr_text("燃料","Fuel"))
 var middle=card();timer=label(middle,"",22);danger=meter(middle,tr_text("危险度 · 累积","Danger · cumulative"));counters=label(middle,"",16)
 var right=card();modules=meter(right,tr_text("模块","Modules"));drones=meter(right,tr_text("头部无人机","Head drones"))
 build_button=Button.new();build_button.text=tr_text("逐节装塔 [E]","Build [E]");build_button.custom_minimum_size.y=36;build_button.pressed.connect(game.show_build);right.add_child(build_button)
 for state in ["normal","hover","pressed","focus"]:build_button.add_theme_stylebox_override(state,Ink.box(Color("e7eeef") if state!="normal" else Ink.PAPER,Ink.BLUE,1))
 for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:build_button.add_theme_color_override(state,Ink.INK)
 radar_label=label(self,tr_text("战场雷达 · Tab","Radar · Tab"),16)
 keys=label(self,tr_text("WASD 移动 · 鼠标瞄准 / 左键射击 · Shift 加速 · E 装塔 · Esc 暂停","WASD move · Mouse aim / fire · Shift boost · E build · Esc pause"),16)
 resized.connect(layout_hud);layout_hud.call_deferred();refresh()
func tr_text(zh:String,en:String)->String:return game.db.ui(en,zh)
func label(parent:Node,value:String,px:int)->Label:
 var l=Label.new();l.text=value;l.add_theme_font_size_override("font_size",px);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func card()->VBoxContainer:
 var panel=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel);cards.append(panel)
 var style=Ink.box(Color(0.965,0.949,0.906,0.90),Color("bbccd5"),1);style.set_corner_radius_all(9)
 style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=10;style.content_margin_bottom=10;panel.add_theme_stylebox_override("panel",style)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",8);column.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(column);return column
func meter(parent:Node,title:String):
 var m=Meter.new(title);parent.add_child(m);return m
func layout_hud():
 var width=minf(300,(size.x-96)/3.0)
 for i in cards.size():
  cards[i].size=Vector2(width,0)
  cards[i].position=Vector2(24 if i==0 else ((size.x-width)*.5 if i==1 else size.x-width-24),20)
 radar_label.position=Vector2(size.x-210,size.y-267)
 keys.position=Vector2(24,size.y-38)
func refresh():
 if game.run==null:return
 var p=game.player;var run=game.run
 mission.text=game.db.title(game.selected_mission)
 health.reading(p.parts[0].hp,p.parts[0].max_hp,"%d / %d"%[maxf(0,p.parts[0].hp),maxf(0,p.parts[0].max_hp)] if p.parts[0].max_hp>0 else "—")
 var percent=roundi(maxf(0,p.fuel)/p.max_fuel*100) if p.max_fuel>0 else 0
 fuel.reading(p.fuel,p.max_fuel,"%d / %d · %d%%"%[maxf(0,p.fuel),p.max_fuel,percent] if p.max_fuel>0 else tr_text("未装燃料箱","No fuel tank"))
 danger.reading(run.heat,1.0,"%d%%"%roundi(maxf(0,run.heat)*100))
 modules.capacity(p.parts.size()-1,int(game.db.stores.PlayerDataStore.maxBuiltCores),tr_text("无上限","No limit"))
 var count=game.combat.drones.filter(func(d):return d.owner==0).size()
 drones.capacity(count,int(game.db.stores.PlayerDataStore.maxHQDronesCount),tr_text("无上限","No limit"))
 var countdown=bool(game.selected_mission.get("isTimerCountingDown",false))
 var seconds=maxf(0,run.duration-run.elapsed) if countdown else maxf(0,run.elapsed)
 timer.text=(tr_text("剩余 ","Remaining ") if countdown else tr_text("已进行 ","Elapsed "))+"%02d:%02d"%[int(seconds)/60,int(seconds)%60]
 counters.text=tr_text("奖励包 %d   ·   废料 %d","Packs %d   ·   Scrap %d")%[run.packs,run.scraps]
