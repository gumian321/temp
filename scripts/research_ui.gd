extends Control
const UI=preload('res://scripts/game_ui.gd')
var db
var save
var close:Callable
var changed:Callable
var positions:Dictionary
var canvas:Control
var detail:Panel
var points:Label
var pan=Vector2(710,350)
var magnification=0.75
var dragging=false
var controller_navigation=false
var node_buttons:Dictionary={}
var video:VideoStreamPlayer
var selected_node:Dictionary={}
var selected_index=0
var world:Control
var modal_blocker:Control
var background_focus:Dictionary={}

class Veins extends Control:
 var lines:Array=[]
 func _draw():
  for pair in lines:
   var a:Vector2=pair[0];var b:Vector2=pair[1]
   var mid=(a+b)*.5
   draw_polyline(PackedVector2Array([a,Vector2(mid.x,a.y),Vector2(mid.x,b.y),b]),Color('355e64'),3,true)
   draw_circle(mid,4,Color('55e3c1'))

func setup(source,store,on_close:Callable,on_change:Callable):
 db=source;save=store;close=on_close;changed=on_change
 size=Vector2(1440,900);mouse_filter=MOUSE_FILTER_STOP;UI.backdrop(self);theme=UI.theme()
 positions=db.read_json('research_layout')
 world=Control.new();world.position=Vector2(30,110);world.size=Vector2(1380,650);world.clip_contents=true;world.mouse_filter=MOUSE_FILTER_PASS;add_child(world)
 canvas=Control.new();world.add_child(canvas);canvas.mouse_filter=MOUSE_FILTER_IGNORE
 UI.header(self,db.ui('EVOLUTION','进化'),close)
 UI.label(self,db.ui('DRAG · ZOOM','拖动 · 缩放'),Vector2(52,800),16,UI.MUTED)
 UI.button(self,db.ui('Recenter','归位'),Rect2(1200,790,170,58),fit_tree,'target')
 points=UI.label(self,'',Vector2(1050,38),24,UI.AMBER)
 rebuild();fit_tree();get_viewport().size_changed.connect(fit_screen);fit_screen()
func label(parent,text:String,at:Vector2,extent:Vector2,px:int=22)->Label:
 var l=UI.label(parent,text,at,px);l.size=extent;return l
func button(parent,text:String,at:Vector2,extent:Vector2,callback:Callable)->Button:return UI.button(parent,text,Rect2(at,extent),callback)
func icon(reward:Dictionary):return db.reward_sprite(reward)
func fit_tree():
 if node_buttons.is_empty():return
 var bounds:Rect2=node_buttons.values()[0].get_rect()
 for b in node_buttons.values():bounds=bounds.merge(b.get_rect())
 magnification=minf(1250/maxf(bounds.size.x,1),540/maxf(bounds.size.y,1))
 magnification=minf(magnification,1.0);pan=world.size*.5-bounds.get_center()*magnification
 canvas.position=pan;canvas.scale=Vector2.ONE*magnification
func rebuild():
 for child in canvas.get_children():canvas.remove_child(child);child.queue_free()
 node_buttons.clear()
 var veins=Veins.new();veins.mouse_filter=MOUSE_FILTER_IGNORE;canvas.add_child(veins)
 for n in db.research:
  var pos:Dictionary=positions.get(n.id,{'x':0,'y':0})
  var b=button(canvas,'',Vector2(pos.x,pos.y)*42,Vector2(94,94),func():show_detail(n,0))
  b.focus_entered.connect(func():
   if not controller_navigation:return
   pan=Vector2(710,350)-(b.position+b.size/2)*magnification;canvas.position=pan)
  b.icon=icon(db.asset(n.nodeRewardsList[0]));b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;b.add_theme_constant_override('icon_max_width',62)
  var unlocked=n.nodeRewardsList.filter(func(id):return id in save.state.unlocked).size()
  b.add_theme_stylebox_override('normal',UI.style(Color('1d4948') if unlocked>0 else UI.PANEL,UI.TEAL if unlocked>0 else Color('385260'),32))
  b.modulate=Color.WHITE if unlocked>0 else Color(.66,.74,.77)
  b.tooltip_text=db.title(db.asset(n.nodeRewardsList[0]))+' · %d / %d'%[unlocked,n.nodeRewardsList.size()]
  for i in n.nodeRewardsList.size():
   var pip=ColorRect.new();pip.position=Vector2(15+i*13,83);pip.size=Vector2(8,3);pip.color=UI.AMBER if i<unlocked else UI.MUTED;pip.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(pip)
  node_buttons[n.id]=b
 for n in db.research:
  var previous=str(int(n.get('previousUpgradeTreeNode',{}).get('fileID',0)))
  if node_buttons.has(previous) and node_buttons.has(n.id):veins.lines.append([node_buttons[previous].position+Vector2(47,47),node_buttons[n.id].position+Vector2(47,47)])
 veins.queue_redraw();canvas.position=pan;canvas.scale=Vector2.ONE*magnification
 points.text='◈ %d'%save.state.meta
func _gui_input(event):
 if is_instance_valid(detail):return
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   var local=event.position-world.position
   var before=(local-pan)/magnification
   magnification=clampf(magnification*(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.15),0.25,1.5)
   pan=local-before*magnification;canvas.position=pan;canvas.scale=Vector2.ONE*magnification
 if event is InputEventMouseMotion and dragging:pan+=event.relative;canvas.position=pan
func remember_background_focus(node:Node):
 if node==detail or node==modal_blocker:return
 if node is Control and node.focus_mode!=Control.FOCUS_NONE:
  if not background_focus.has(node):background_focus[node]=node.focus_mode
  node.focus_mode=Control.FOCUS_NONE
 for child in node.get_children():remember_background_focus(child)
func confine_detail_focus():
 remember_background_focus(self)
 var ordered:Array=[]
 for child in detail.get_children():
  if child is Button and not child.disabled:ordered.append(child)
 for i in ordered.size():
  var b:Control=ordered[i]
  var next=b.get_path_to(ordered[(i+1)%ordered.size()])
  var previous=b.get_path_to(ordered[posmod(i-1,ordered.size())])
  b.focus_next=next;b.focus_previous=previous
  b.focus_neighbor_right=next;b.focus_neighbor_bottom=next
  b.focus_neighbor_left=previous;b.focus_neighbor_top=previous
func dismiss_detail():
 if is_instance_valid(detail):remove_child(detail);detail.queue_free();detail=null
 if is_instance_valid(modal_blocker):remove_child(modal_blocker);modal_blocker.queue_free();modal_blocker=null
 for control in background_focus:
  if is_instance_valid(control):control.focus_mode=background_focus[control]
 background_focus.clear()
 if node_buttons.has(selected_node.get('id','')):node_buttons[selected_node.id].grab_focus()
func show_detail(n:Dictionary,index:int):
 selected_node=n;selected_index=index;dragging=false
 if is_instance_valid(detail):remove_child(detail);detail.queue_free()
 if not is_instance_valid(modal_blocker):
  modal_blocker=Control.new();modal_blocker.mouse_filter=MOUSE_FILTER_STOP;add_child(modal_blocker)
  modal_blocker.position=-position/scale;modal_blocker.size=get_viewport_rect().size/scale
 detail=Panel.new();detail.position=Vector2(170,125);detail.size=Vector2(1100,620);detail.add_theme_stylebox_override('panel',UI.style(UI.BG,UI.TEAL,24));add_child(detail)
 var r:Dictionary=db.asset(n.nodeRewardsList[index])
 UI.panel(detail,Rect2(24,24,420,465),Color('315665'))
 var art=TextureRect.new();art.texture=icon(r);art.position=Vector2(64,72);art.size=Vector2(340,340);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=MOUSE_FILTER_IGNORE;detail.add_child(art)
 UI.label(detail,'EVOLUTION / %02d'%[index+1],Vector2(480,34),14,UI.TEAL)
 var title=label(detail,db.title(r),Vector2(480,70),Vector2(560,65),32);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var desc=label(detail,db.text(r.get('rewardDesc','')),Vector2(480,150),Vector2(550,115),19);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.clip_text=true;desc.tooltip_text=desc.text;desc.add_theme_color_override('font_color',UI.MUTED)
 var stats:Dictionary=r.get('rewardStats',{});var linked:Dictionary=db.asset(stats.get('LinkedReward','')).get('rewardStats',{})
 var keys=['HullDamage','ShieldDamage','Range','RateOfFire','PartsCount','DronesCount'];var names=['Lab_Damage','Lab_ShieldDamage','Lab_Range','Lab_RateOfFire','Lab_PartsCount','Lab_DronesCount'];var row=0
 for i in keys.size():
  var value=int(stats.get(keys[i],0));var added=0
  if stats.get('LevelUp',false) and not linked.is_empty() and keys[i]!='PartsCount':added=value;value=int(linked.get(keys[i],0))
  if value<=0:continue
  label(detail,db.text(names[i]),Vector2(480,282+row*32),Vector2(190,30),16)
  for j in range(6):
   var bar=ColorRect.new();bar.position=Vector2(700+j*48,289+row*32);bar.size=Vector2(36,10);bar.color=UI.TEAL if j<value else (UI.AMBER if j<value+added else Color('263e49'));bar.mouse_filter=MOUSE_FILTER_IGNORE;detail.add_child(bar)
  row+=1
 for i in range(n.nodeRewardsList.size()):
  var reward:Dictionary=db.asset(n.nodeRewardsList[i])
  var b=button(detail,str(i+1),Vector2(40+i*75,420),Vector2(64,54),func():show_detail(n,i));b.tooltip_text=db.title(reward)
  b.add_theme_stylebox_override('normal',UI.style(Color('28544d') if i==index else UI.PANEL,UI.TEAL if reward.id in save.state.unlocked else UI.MUTED))
  if i==index:b.call_deferred('grab_focus')
 var unlocked=r.id in save.state.unlocked;var cost=save.research_price(n,index);var allowed=save.state.meta>=cost
 for i in range(index):allowed=allowed and n.nodeRewardsList[i] in save.state.unlocked
 var previous=str(int(n.get('previousUpgradeTreeNode',{}).get('fileID',0)))
 for other in db.research:
  if other.id==previous:allowed=allowed and other.nodeRewardsList[0] in save.state.unlocked
 var buy=UI.button(detail,db.ui('EVOLVED','已进化') if unlocked else db.ui('EVOLVE  ◈ %d','进化  ◈ %d')%cost,Rect2(480,526,430,62),func():
  if save.unlock_research(n,index):changed.call();rebuild();show_detail(n,mini(index+1,n.nodeRewardsList.size()-1)), 'research',UI.AMBER)
 buy.disabled=unlocked or not allowed
 if not unlocked and not allowed:buy.tooltip_text=db.ui('Requires earlier evolutions and enough research points.','需要完成前置进化，并持有足够研究点。')
 UI.button(detail,'',Rect2(938,526,120,62),dismiss_detail,'back')
 confine_detail_focus()
func _input(event):
 if event is InputEventJoypadButton or event is InputEventJoypadMotion:controller_navigation=true
 elif event is InputEventKey and event.pressed:controller_navigation=true
 elif event is InputEventMouseButton or event is InputEventMouseMotion:controller_navigation=false
 if is_instance_valid(detail) and (event.is_action_pressed('ui_cancel') or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B)):
  dismiss_detail();get_viewport().set_input_as_handled()

func fit_screen():
 var viewport_size=get_viewport_rect().size
 var factor=minf(viewport_size.x/1440.0,viewport_size.y/900.0)
 scale=Vector2.ONE*factor;position=(viewport_size-Vector2(1440,900)*factor)*.5
 # Artwork fills the physical viewport while interactive content stays uniformly fitted.
 var background:Control=get_child(0)
 background.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 background.position=-position/factor;background.size=viewport_size/factor;background.queue_redraw()
 if is_instance_valid(modal_blocker):modal_blocker.position=-position/factor;modal_blocker.size=viewport_size/factor
