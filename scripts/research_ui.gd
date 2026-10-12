extends Control
var db
var save
var close:Callable
var changed:Callable
var positions:Dictionary
var canvas:Control
var detail:Panel
var points:Label
var pan=Vector2(710,310)
var magnification=0.75
var dragging=false
var controller_navigation=false
var node_buttons:Dictionary={}
var video:VideoStreamPlayer
var selected_node:Dictionary={}
var selected_index=0
func setup(source,store,on_close:Callable,on_change:Callable):
 db=source;save=store;close=on_close;changed=on_change
 size=Vector2(1440,900);mouse_filter=Control.MOUSE_FILTER_STOP
 positions=db.read_json('research_layout')
 canvas=Control.new();add_child(canvas);canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
 rebuild()
func label(parent,text:String,at:Vector2,extent:Vector2,px:int=22)->Label:
 var l=Label.new();l.text=text;l.position=at;l.size=extent;l.add_theme_font_size_override('font_size',px);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func button(parent,text:String,at:Vector2,extent:Vector2,callback:Callable)->Button:
 var b=Button.new();b.text=text;b.position=at;b.size=extent;var style=StyleBoxFlat.new();style.bg_color=Color('344149');style.set_border_width_all(1);style.border_color=Color('6b7e85');b.add_theme_stylebox_override('normal',style);b.pressed.connect(callback);parent.add_child(b);return b
func icon(reward:Dictionary):
 for field in ['blockCore','core','turretCore']:
  if reward.get(field) is String:return db.core_sprite(db.asset(reward[field]))
 if reward.has('drone'):return db.sprite(db.asset(reward.drone).get('droneSprite',''))
 return db.sprite(reward.get('rewardSprite',''))
func rebuild():
 for child in canvas.get_children():child.queue_free()
 node_buttons.clear()
 for n in db.research:
  var pos:Dictionary=positions.get(n.id,{'x':0,'y':0})
  var b=button(canvas,'',Vector2(pos.x,pos.y)*48,Vector2(140,110),func():show_detail(n,0))
  b.focus_entered.connect(func():
   if not controller_navigation:return
   pan=Vector2(710,350)-(b.position+b.size/2)*magnification;canvas.position=pan;queue_redraw())
  b.pivot_offset=b.size/2
  b.icon=icon(db.asset(n.nodeRewardsList[0]));b.expand_icon=true;b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
  b.add_theme_constant_override('icon_max_width',60)
  b.text=db.title(db.asset(n.nodeRewardsList[0]))
  b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
  b.add_theme_font_size_override('font_size',15)
  var unlocked=n.nodeRewardsList.filter(func(id):return id in save.state.unlocked).size()
  b.modulate=Color.WHITE if unlocked>0 else Color(0.65,0.65,0.65)
  b.tooltip_text='%d / %d'%[unlocked,n.nodeRewardsList.size()]
  node_buttons[n.id]=b
 canvas.position=pan;canvas.scale=Vector2.ONE*magnification
 if not is_instance_valid(points):
  points=label(self,'',Vector2(1120,25),Vector2(290,50),28)
  label(self,db.text('Menu_Lab'),Vector2(35,25),Vector2(700,50),32)
  label(self,'Drag to pan · Mouse wheel to zoom',Vector2(35,825),Vector2(700,40),18)
  button(self,db.text('Option_Back'),Vector2(1170,810),Vector2(220,55),close)
 points.text='%d RP'%save.state.meta
 queue_redraw()
func _gui_input(event):
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   var before=(event.position-pan)/magnification
   magnification=clampf(magnification*(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.15),0.25,1.5)
   pan=event.position-before*magnification;canvas.position=pan;canvas.scale=Vector2.ONE*magnification;queue_redraw()
 if event is InputEventMouseMotion and dragging:pan+=event.relative;canvas.position=pan;queue_redraw()
func _draw():
 for n in db.research:
  var previous=str(int(n.get('previousUpgradeTreeNode',{}).get('fileID',0)))
  if node_buttons.has(previous) and node_buttons.has(n.id):
   var a=node_buttons[previous];var b=node_buttons[n.id]
   draw_line(pan+(a.position+a.size/2)*magnification,pan+(b.position+b.size/2)*magnification,Color(0.65,0.7,0.7),3)
func show_detail(n:Dictionary,index:int):
 selected_node=n;selected_index=index
 if is_instance_valid(detail):remove_child(detail);detail.queue_free()
 detail=Panel.new()
 var background=StyleBoxFlat.new();background.bg_color=Color("20272b");background.border_color=Color("97a6ae");background.set_border_width_all(3);detail.add_theme_stylebox_override('panel',background)
 detail.position=Vector2(150,90);detail.size=Vector2(1140,710);add_child(detail)
 var r:Dictionary=db.asset(n.nodeRewardsList[index])
 label(detail,db.title(r),Vector2(35,22),Vector2(1060,60),32)
 var desc=label(detail,db.text(r.get('rewardDesc','')),Vector2(620,105),Vector2(475,200),23);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var paths:Dictionary=db.read_json('videos')
 var path=paths.get(r.get('rewardVideoClip',''),'')
 if not path.is_empty() and ResourceLoader.exists(path):
  video=VideoStreamPlayer.new();video.position=Vector2(35,105);video.size=Vector2(550,320);video.expand=true;video.stream=load(path);video.loop=true;detail.add_child(video);video.play()
 var stats:Dictionary=r.get('rewardStats',{})
 var linked:Dictionary=db.asset(stats.get('LinkedReward','')).get('rewardStats',{})
 var keys=['HullDamage','ShieldDamage','Range','RateOfFire','PartsCount','DronesCount']
 var names=['Hull damage','Shield damage','Range','Rate of fire','Parts','Drones'] if db.language=='English' else ['船体伤害','护盾伤害','射程','射速','部件数量','无人机数量']
 var row=0
 for i in keys.size():
  var value=int(stats.get(keys[i],0));var added=0
  if stats.get('LevelUp',false) and not linked.is_empty() and keys[i]!='PartsCount':added=value;value=int(linked.get(keys[i],0))
  if value<=0:continue
  label(detail,names[i],Vector2(620,320+row*35),Vector2(180,30),18)
  for j in range(6):
   var bar=ColorRect.new();bar.position=Vector2(815+j*40,327+row*35);bar.size=Vector2(30,18)
   bar.color=Color('63b458') if j<value else (Color('6dd8ef') if j<value+added else Color('3e494e'))
   detail.add_child(bar)
  row+=1
 for i in range(n.nodeRewardsList.size()):
  var reward:Dictionary=db.asset(n.nodeRewardsList[i])
  var b=button(detail,('✓ ' if reward.id in save.state.unlocked else '🔒 ')+str(i+1),Vector2(35+i*110,465),Vector2(100,80),func():show_detail(n,i))
  b.icon=icon(reward);b.expand_icon=true;b.add_theme_constant_override('icon_max_width',42);b.tooltip_text=db.title(reward)
  if i==index:b.call_deferred('grab_focus')
 var unlocked=r.id in save.state.unlocked
 var cost=save.research_price(n,index)
 var allowed=save.state.meta>=cost
 for i in range(index):allowed=allowed and n.nodeRewardsList[i] in save.state.unlocked
 var previous=str(int(n.get('previousUpgradeTreeNode',{}).get('fileID',0)))
 for other in db.research:
  if other.id==previous:allowed=allowed and other.nodeRewardsList[0] in save.state.unlocked
 var buy=button(detail,db.text('Lab_Unlocked') if unlocked else db.text('Lab_Unlock')+' · %d RP'%cost,Vector2(35,590),Vector2(360,65),func():
  if save.unlock_research(n,index):changed.call();rebuild();show_detail(n,mini(index+1,n.nodeRewardsList.size()-1)))
 buy.disabled=unlocked or not allowed
 button(detail,db.text('Option_Back'),Vector2(880,590),Vector2(220,65),func():detail.queue_free())

func _input(event):
 if event is InputEventJoypadButton or event is InputEventJoypadMotion:controller_navigation=true
 elif event is InputEventKey and event.pressed:controller_navigation=true
 elif event is InputEventMouseButton or event is InputEventMouseMotion:controller_navigation=false
