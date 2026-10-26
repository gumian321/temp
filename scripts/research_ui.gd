extends Control
const UI=preload('res://scripts/game_ui.gd')
const Categories=preload('res://scripts/armament_categories.gd')
const NODE_SIZE=Vector2(104,134)
const NODE_ICON_CENTER=Vector2(52,44)
const DEFAULT_ZOOM=0.9
const SECTIONS=Categories.SECTIONS
const SECTION_PITCH=420.0
var section_bounds:Dictionary={}
var node_sections:Dictionary={}
var node_positions:Dictionary={}
var section_buttons:Dictionary={}
var db
var save
var close:Callable
var changed:Callable
var canvas:Control
var detail:Panel
var points:Label
var zoom_label:Label
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
   var cross=pair.size()>2 and bool(pair[2])
   var branch=pair.size()>3 and bool(pair[3])
   var points=PackedVector2Array([a,Vector2(a.x,mid.y),Vector2(b.x,mid.y),b]) if branch else PackedVector2Array([a,Vector2(mid.x,a.y),Vector2(mid.x,b.y),b])
   draw_polyline(points,Color(UI.MUTED,.12 if cross else .6),1 if cross else 2,true)
   if not cross:draw_circle(mid,3,Color(UI.TEAL,.7))

func setup(source,store,on_close:Callable,on_change:Callable):
 db=source;save=store;close=on_close;changed=on_change
 size=Vector2(1440,900);mouse_filter=MOUSE_FILTER_STOP;UI.protect(self);UI.backdrop(self);theme=UI.theme()
 world=Control.new();world.position=Vector2(30,160);world.size=Vector2(1380,620);world.clip_contents=true;world.mouse_filter=MOUSE_FILTER_PASS;add_child(world)
 canvas=Control.new();world.add_child(canvas);canvas.mouse_filter=MOUSE_FILTER_IGNORE
 UI.header(self,db.ui('EVOLUTION','进化'),close)
 for i in SECTIONS.size()+1:
  var key=str(SECTIONS[i].id) if i<SECTIONS.size() else 'support'
  var title=db.ui(str(SECTIONS[i].en),str(SECTIONS[i].zh)) if i<SECTIONS.size() else db.ui('SUPPORT','通用支援')
  var section_button=UI.button(self,title,Rect2(52+i*170,106,154,40),func():focus_section(key))
  section_button.add_theme_font_size_override('font_size',19)
  section_buttons[key]=section_button
 UI.label(self,db.ui('DRAG · ZOOM','拖动 · 缩放'),Vector2(52,800),16,UI.MUTED)
 UI.label(self,db.ui('LEVEL: CURRENT / MAX','等级：当前 / 上限'),Vector2(230,800),18,UI.MUTED)
 zoom_label=UI.label(self,'',Vector2(708,806),22,UI.MUTED)
 for step in [-1,1]:
  var zoom_button=UI.button(self,'−' if step<0 else '+',Rect2(810 if step<0 else 890,790,64,58),func():zoom_at(magnification*pow(1.2,step),world.size*.5))
  zoom_button.tooltip_text=db.ui('Zoom out','缩小') if step<0 else db.ui('Zoom in','放大')
  for state in ["normal","hover","pressed","hover_pressed","focus"]:
   var skin=zoom_button.get_theme_stylebox(state).duplicate()
   skin.content_margin_left=8;skin.content_margin_right=8
   zoom_button.add_theme_stylebox_override(state,skin)
 UI.button(self,db.ui('Overview','全图'),Rect2(990,790,170,58),fit_tree,'target')
 UI.button(self,db.ui('Recenter','归位'),Rect2(1200,790,170,58),focus_tree,'target')
 points=UI.label(self,'',Vector2(1050,38),24,UI.AMBER)
 points.size=Vector2(150,38);points.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;points.clip_text=true;points.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 rebuild();focus_tree();get_viewport().size_changed.connect(fit_screen);fit_screen()
func label(parent,text:String,at:Vector2,extent:Vector2,px:int=22)->Label:
 var l=UI.label(parent,text,at,px);l.size=extent;return l
func button(parent,text:String,at:Vector2,extent:Vector2,callback:Callable)->Button:return UI.button(parent,text,Rect2(at,extent),callback)
func icon(reward:Dictionary):return db.reward_sprite(reward)
func apply_view():
 canvas.position=pan;canvas.scale=Vector2.ONE*magnification
 if is_instance_valid(zoom_label):zoom_label.text='%d%%'%roundi(magnification*100)
func zoom_at(value:float,pivot:Vector2):
 if is_instance_valid(detail):return
 var before=(pivot-pan)/magnification
 magnification=clampf(value,0.35,2.0)
 pan=pivot-before*magnification;apply_view()
func focus_tree():
 focus_section('direct')
func focus_section(key:String):
 if not section_bounds.has(key):return
 var bounds:Rect2=section_bounds[key]
 magnification=DEFAULT_ZOOM
 var total_width=section_bounds.support.end.x
 pan.x=clampf(world.size.x*.5-bounds.get_center().x*magnification,minf(0,world.size.x-total_width*magnification),0)
 pan.y=4-bounds.position.y*magnification
 for id in section_buttons:
  section_buttons[id].add_theme_stylebox_override('normal',UI.card_style(id==key))
 apply_view()
func fit_tree():
 if node_buttons.is_empty():return
 var bounds:Rect2=node_buttons.values()[0].get_rect()
 for b in node_buttons.values():bounds=bounds.merge(b.get_rect())
 for section in section_bounds.values():bounds=bounds.merge(section)
 magnification=minf(1250/maxf(bounds.size.x,1),540/maxf(bounds.size.y,1))
 magnification=minf(magnification,1.0);pan=world.size*.5-bounds.get_center()*magnification
 apply_view()
func arrange_sections():
 node_positions.clear();node_sections.clear();section_bounds.clear()
 var groups:Dictionary={"support":[]}
 for section in SECTIONS:groups[section.id]=[]
 for node in db.research:
  var key=str(Categories.category(db,db.asset(node.nodeRewardsList[0])).id)
  groups[key].append(node);node_sections[node.id]=key
 var section_x=0.0
 for i in SECTIONS.size():
  var section:Dictionary=SECTIONS[i]
  var nodes:Array=groups[section.id]
  nodes.sort_custom(func(a,b):return section.variants.find(db.armament_variant(db.asset(a.nodeRewardsList[0])))<section.variants.find(db.armament_variant(db.asset(b.nodeRewardsList[0]))))
  var has_branches=nodes.any(func(node):return node.has('mutation_branch'))
  var roots=nodes.filter(func(node):return not node.has('mutation_branch'))
  var width=maxf(390,roots.size()*340+30) if has_branches else 390.0
  section_bounds[section.id]=Rect2(section_x,0,width,700)
  if has_branches:
   for index in roots.size():
    var parent:Dictionary=roots[index];var x=section_x+index*340
    node_positions[parent.id]=Vector2(x+118,100)
    var children=nodes.filter(func(node):return node.has('mutation_branch') and str(int(node.previousUpgradeTreeNode.fileID))==parent.id)
    for child in children.size():node_positions[children[child].id]=Vector2(x+33+child*170,340)
  else:
   for index in nodes.size():node_positions[nodes[index].id]=Vector2(section_x+52+(index%2)*178,100+(index/2)*196)
  section_x+=width+30
 section_bounds.support=Rect2(0,720,section_x-30,480)
 var support:Array=groups.support
 for i in support.size():node_positions[support[i].id]=Vector2(64+(i%7)*288,810+(i/7)*196)
func paint_sections():
 for i in SECTIONS.size()+1:
  var section:Dictionary=SECTIONS[i] if i<SECTIONS.size() else Categories.SUPPORT
  var bounds:Rect2=section_bounds[section.id]
  var panel=Panel.new();panel.position=bounds.position;panel.size=bounds.size;panel.mouse_filter=MOUSE_FILTER_IGNORE
  var skin=UI.flat_style(Color(UI.PANEL,.22),Color(UI.MUTED,.18),6);skin.shadow_size=0
  panel.add_theme_stylebox_override('panel',skin);canvas.add_child(panel)
  UI.label(panel,db.ui(str(section.en),str(section.zh)),Vector2(20,13),30,UI.TEXT)
  UI.label(panel,str(section.hint) if db.language.begins_with('Chinese') else str(section.en)+' / EVOLUTION',Vector2(20,55),16,UI.MUTED)
func rebuild():
 for child in canvas.get_children():canvas.remove_child(child);child.queue_free()
 node_buttons.clear()
 arrange_sections()
 paint_sections()
 var veins=Veins.new();veins.name='EvolutionConnections';veins.size=section_bounds.support.end;veins.mouse_filter=MOUSE_FILTER_IGNORE;canvas.add_child(veins)
 for n in db.research:
  var unlocked=n.nodeRewardsList.filter(func(id):return id in save.state.unlocked).size()
  var maximum=n.nodeRewardsList.size()
  var b=button(canvas,'',node_positions[n.id],NODE_SIZE,func():show_detail(n,0))
  for state in ["normal","hover","pressed","hover_pressed","focus"]:
   var skin=UI.card_focus_style() if state=="focus" else UI.card_style(unlocked>0 or state!="normal")
   skin.content_margin_top=10;skin.content_margin_bottom=56
   b.add_theme_stylebox_override(state,skin)
  b.focus_entered.connect(func():
   if not controller_navigation:return
   pan=world.size*.5-(b.position+NODE_ICON_CENTER)*magnification;apply_view())
  b.expand_icon=true;b.add_theme_constant_override('icon_max_width',62);b.icon=icon(db.asset(n.nodeRewardsList[0]));b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;b.size=NODE_SIZE
  b.add_theme_color_override("icon_normal_color",Color.WHITE if unlocked>0 else Color(UI.MUTED,.82))
  var tags=Categories.reward_badge(db,db.asset(n.nodeRewardsList[0]))
  b.tooltip_text=str(tags.category)+' · '+str(tags.text)+'\n'+db.title(db.asset(n.nodeRewardsList[0]))+'\n'+db.ui('Current level: %d / Maximum level: %d','当前等级：%d / 最大等级：%d')%[unlocked,maximum]
  var progress=HBoxContainer.new();progress.name="EvolutionLevel";progress.position=Vector2(6,74);progress.size=Vector2(92,44);progress.alignment=BoxContainer.ALIGNMENT_CENTER;progress.add_theme_constant_override("separation",3);progress.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(progress)
  var current=UI.label(progress,str(unlocked),Vector2.ZERO,30,UI.TEAL if unlocked>0 else UI.MUTED);current.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  var limit=UI.label(progress,'/ %d'%maximum,Vector2.ZERO,22,UI.MUTED);limit.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  var pip_width=(NODE_SIZE.x-24-(maximum-1)*5)/maximum
  for i in maximum:
   var pip=ColorRect.new();pip.position=Vector2(12+i*(pip_width+5),124);pip.size=Vector2(pip_width,6);pip.color=UI.TEAL if i<unlocked else Color(UI.MUTED,.22);pip.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(pip)
  var name_label=UI.label(b,db.title(db.asset(n.nodeRewardsList[0])).replace(' ×1',''),Vector2(-28,138),18,UI.TEXT)
  name_label.size=Vector2(160,30);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.max_lines_visible=1;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  var effect_tag=UI.label(b,str(tags.text),Vector2(-28,168),14,tags.color);effect_tag.name='EvolutionEffectTag'
  effect_tag.size=Vector2(160,22);effect_tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;effect_tag.max_lines_visible=1;effect_tag.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  node_buttons[n.id]=b
  if n.has('mutation_branch'):
   var branch_hint=UI.label(b,db.ui('CHOOSE ONE PATH','本局二选一'),Vector2(-28,196),14,UI.MUTED)
   branch_hint.size=Vector2(160,22);branch_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 for n in db.research:
  var previous=str(int(n.get('previousUpgradeTreeNode',{}).get('fileID',0)))
  if node_buttons.has(previous) and node_buttons.has(n.id):
   if n.has('mutation_branch'):
    veins.lines.append([node_buttons[previous].position+Vector2(52,196),node_buttons[n.id].position+Vector2(52,-2),false,true])
   else:veins.lines.append([node_buttons[previous].position+NODE_ICON_CENTER,node_buttons[n.id].position+NODE_ICON_CENTER,node_sections.get(previous)!=node_sections.get(n.id)])
   var prior=db.research.filter(func(node):return node.id==previous)
   if not prior.is_empty():node_buttons[n.id].tooltip_text+='\n'+db.ui('Requires: ','前置：')+db.title(db.asset(prior[0].nodeRewardsList[0]))+' · '+str(int(n.get('prerequisite_level',1)))+'/'+str(prior[0].nodeRewardsList.size())
 veins.queue_redraw();apply_view()
 points.text='%d RP'%save.state.meta
func _gui_input(event):
 if is_instance_valid(detail):return
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed
  if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   var local=event.position-world.position
   zoom_at(magnification*(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.15),local)
 if event is InputEventMouseMotion and dragging:pan+=event.relative;apply_view()
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
  modal_blocker=ColorRect.new();modal_blocker.color=Color(UI.BG,.78);modal_blocker.mouse_filter=MOUSE_FILTER_STOP;add_child(modal_blocker)
  modal_blocker.position=-position/scale;modal_blocker.size=get_viewport_rect().size/scale
 detail=Panel.new();detail.position=Vector2(170,125);detail.size=Vector2(1100,620);detail.add_theme_stylebox_override('panel',UI.style(Color(UI.PANEL,.98),Color(UI.TEAL,.7),26));add_child(detail)
 var r:Dictionary=db.asset(n.nodeRewardsList[index])
 UI.panel(detail,Rect2(24,24,420,465),Color(UI.MUTED,.35))
 var tags=Categories.reward_badge(db,r)
 var tag_row=HBoxContainer.new();tag_row.name='EvolutionTags';tag_row.position=Vector2(44,32);tag_row.add_theme_constant_override('separation',8);tag_row.mouse_filter=MOUSE_FILTER_IGNORE;detail.add_child(tag_row)
 UI.badge(tag_row,str(tags.category),tags.color,false,16).name='EvolutionCategory'
 UI.badge(tag_row,str(tags.text),tags.color,true,18).name='EvolutionEffectTag'
 var art=TextureRect.new();art.name='EvolutionArt';art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.texture=icon(r);art.position=Vector2(64,72);art.size=Vector2(340,340);art.mouse_filter=MOUSE_FILTER_IGNORE;detail.add_child(art)
 var current_level=n.nodeRewardsList.filter(func(id):return id in save.state.unlocked).size()
 UI.label(detail,db.ui('LEVEL %d / %d · VIEWING TIER %d','当前等级 %d / %d · 查看阶段 %d')%[current_level,n.nodeRewardsList.size(),index+1],Vector2(480,34),18,UI.TEXT)
 var title=label(detail,db.title(r),Vector2(480,70),Vector2(560,65),32);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.size=Vector2(560,65)
 var desc=label(detail,db.text(r.get('rewardDesc','')),Vector2(480,150),Vector2(550,115),19);desc.name='EvolutionDescription';desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.clip_text=true;desc.size=Vector2(550,115);desc.tooltip_text=desc.text;desc.add_theme_color_override('font_color',UI.MUTED)
 var stats:Dictionary=r.get('rewardStats',{});var linked:Dictionary=db.asset(stats.get('LinkedReward','')).get('rewardStats',{})
 var keys=['HullDamage','ShieldDamage','Range','RateOfFire','PartsCount','DronesCount'];var names=['Lab_Damage','Lab_ShieldDamage','Lab_Range','Lab_RateOfFire','Lab_PartsCount','Lab_DronesCount'];var row=0
 for i in keys.size():
  var value=int(stats.get(keys[i],0));var added=0
  if stats.get('LevelUp',false) and not linked.is_empty() and keys[i]!='PartsCount':added=value;value=int(linked.get(keys[i],0))
  if value<=0:continue
  label(detail,db.text(names[i]),Vector2(480,282+row*32),Vector2(190,30),16)
  for j in range(6):
   var bar=ColorRect.new();bar.position=Vector2(700+j*48,289+row*32);bar.size=Vector2(36,10);bar.color=UI.TEAL if j<value else (UI.AMBER if j<value+added else Color(UI.MUTED,.2));bar.mouse_filter=MOUSE_FILTER_IGNORE;detail.add_child(bar)
  row+=1
 if r.has('mutation_branch'):
  var rule=label(detail,'',Vector2(480,288),Vector2(550,130),18);rule.name='BranchRules';rule.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rule.clip_text=true;rule.text=preload('res://scripts/mutation_branches.gd').rule_text(db,r);rule.size=Vector2(550,130);rule.add_theme_color_override('font_color',UI.AMBER)
  label(detail,db.ui('Research prerequisite: base weapon 3/3. Both paths can be researched.','研究前置：基础武器 3/3。两个分支都可以研究。'),Vector2(480,446),Vector2(550,50),17)
 for i in range(n.nodeRewardsList.size()):
  var reward:Dictionary=db.asset(n.nodeRewardsList[i])
  var b=button(detail,str(i+1),Vector2(40+i*75,420),Vector2(64,54),func():show_detail(n,i));b.tooltip_text=db.title(reward)
  b.add_theme_stylebox_override('normal',UI.card_style(i==index))
  if i==index:UI.focus_if_live.call_deferred(weakref(b))
 var unlocked=r.id in save.state.unlocked;var cost=save.research_price(n,index);var allowed=save.state.meta>=cost
 for i in range(index):allowed=allowed and n.nodeRewardsList[i] in save.state.unlocked
 allowed=allowed and save.research_prerequisite_met(n)
 var buy=UI.button(detail,db.ui('EVOLVED','已进化') if unlocked else db.ui('EVOLVE  %d RP','进化  %d RP')%cost,Rect2(480,526,430,62),func():
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

func _exit_tree():
 var viewport=get_viewport()
 if viewport.size_changed.is_connected(fit_screen):viewport.size_changed.disconnect(fit_screen)
