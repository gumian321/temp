extends Control
const UI=preload('res://scripts/game_ui.gd')
var db
var save
var view
var config:Dictionary
var entries:Array=[]
var groups:Array=[]
var draft:Dictionary={}
var back:Callable
var sound:Callable
var cards:Array[Button]=[]
var count_label:Label
var points:Label
var apply_button:Button
var unlock_button:Button
var all_button:Button
var none_button:Button
var selected_title:Label
var selected_desc:Label
var selected_art:TextureRect
var selected_state:Label
var selected=0
func setup(source,store,on_back:Callable,on_sound:Callable):
 db=source;save=store;back=on_back;sound=on_sound;size=Vector2(1440,900);UI.backdrop(self);theme=UI.theme()
 var layout:Dictionary=db.read_json('ui_layouts')['MainMenuScene/ResearchesCanvas']
 config=layout.components.ToggleResearchUIManager;collect_groups(layout)
 for node in db.research:
  if not node.get('project_added',false):continue
  var group:Array=node.nodeRewardsList.duplicate()
  if group.is_empty() or draft.has(group[0]):continue
  groups.append(group);entries.append({});draft[group[0]]=group[0] not in save.state.disabled
 UI.header(self,db.ui('LOOT CODEX','战利品图鉴'),func():action('BackButton','',{}))
 points=UI.label(self,'',Vector2(1050,38),24,UI.AMBER)
 points.size=Vector2(150,38);points.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;points.clip_text=true;points.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 UI.panel(self,Rect2(36,116,952,644),Color(UI.MUTED,.35))
 var scroll=ScrollContainer.new();scroll.position=Vector2(56,136);scroll.size=Vector2(912,604);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;add_child(scroll)
 var grid=GridContainer.new();grid.columns=7;grid.add_theme_constant_override('h_separation',12);grid.add_theme_constant_override('v_separation',12);scroll.add_child(grid)
 for i in groups.size():
  var reward:Dictionary=db.asset(groups[i][0]);var card=Button.new();card.custom_minimum_size=Vector2(116,130);card.icon=db.reward_sprite(reward);card.expand_icon=true;card.add_theme_constant_override('icon_max_width',78);card.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;card.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;card.add_theme_font_size_override('font_size',16);card.mouse_default_cursor_shape=CURSOR_POINTING_HAND;grid.add_child(card)
  for state in ["hover","pressed","hover_pressed"]:card.add_theme_stylebox_override(state,UI.card_style(true))
  card.add_theme_stylebox_override("focus",UI.card_focus_style())
  card.pressed.connect(func():
   selected=i
   if save.state.systems.get('ToggleResearches',false) and groups[i][0] in save.state.unlocked:draft[groups[i][0]]=not draft[groups[i][0]];sound.call()
   refresh())
  card.mouse_entered.connect(func():selected=i;show_selection())
  card.focus_entered.connect(func():selected=i;show_selection())
  cards.append(card)
 UI.panel(self,Rect2(1012,116,392,644),UI.TEAL)
 UI.label(self,'SPECIMEN / ARCHIVE',Vector2(1040,144),16,UI.TEAL)
 selected_art=TextureRect.new();selected_art.position=Vector2(1050,190);selected_art.size=Vector2(316,235);selected_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;selected_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;selected_art.mouse_filter=MOUSE_FILTER_IGNORE;add_child(selected_art)
 selected_title=UI.label(self,'',Vector2(1040,450),27);selected_title.size=Vector2(330,72);selected_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 selected_state=UI.label(self,'',Vector2(1040,534),16,UI.AMBER)
 selected_desc=UI.label(self,'',Vector2(1040,582),18,UI.MUTED);selected_desc.size=Vector2(330,130);selected_desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selected_desc.clip_text=true
 count_label=UI.label(self,'',Vector2(50,800),24,UI.TEAL)
 all_button=UI.button(self,db.ui('ALL','全选'),Rect2(300,785,168,60),func():action('ToggleAllButton','',{}),'check')
 none_button=UI.button(self,db.ui('CLEAR','清空'),Rect2(484,785,122,60),func():action('ToggleNoneButton','',{}))
 apply_button=UI.button(self,db.ui('APPLY','应用'),Rect2(1050,785,354,60),func():action('ApplyButton','',{}),'check',UI.AMBER)
 unlock_button=UI.button(self,db.ui('UNLOCK','解锁'),Rect2(788,785,616,60),func():action('ResearchSystem','',{}),'research',UI.AMBER)
 refresh();get_viewport().size_changed.connect(fit_screen);fit_screen()
func collect_groups(node:Dictionary):
 for entry in node.get('components',{}).values():
  if not entry.has('rewardsList') or not entry.has('rewardButton') or entry.rewardsList.is_empty():continue
  var group=[]
  for reward in entry.rewardsList:
   if not db.asset(reward.guid).get('retired',false):group.append(reward.guid)
  if group.is_empty() or draft.has(group[0]):continue
  groups.append(group);entries.append(entry);draft[group[0]]=group[0] not in save.state.disabled
 for child in node.get('children',[]):collect_groups(child)
func ref(entry:Dictionary,key:String)->String:return str(int(entry.get(key,{}).get('fileID',0)))
func refresh():
 var unlocked=save.state.systems.get('ToggleResearches',false);var count=0;var available=0
 for i in groups.size():
  var first=groups[i][0];var known=first in save.state.unlocked
  if known:available+=1
  if known and draft[first]:count+=1
  cards[i].text=db.ui('ACTIVE','启用') if known and draft[first] else (db.ui('OFF','排除') if known else db.ui('LOCKED','未发现'))
  cards[i].add_theme_color_override("icon_normal_color",Color.WHITE if known else Color(UI.MUTED,.7))
  cards[i].add_theme_color_override("font_color",UI.TEXT if known and draft[first] else UI.MUTED)
  cards[i].add_theme_stylebox_override('normal',UI.card_style(known and draft[first]))
  cards[i].tooltip_text=db.title(db.asset(first))+" · "+(db.ui("Active","已启用") if known and draft[first] else (db.ui("Excluded","已排除") if known else db.ui("Undiscovered","未发现")))
 count_label.text='%02d / %02d'%[count,available]+db.ui(' ACTIVE',' 已启用')
 count_label.tooltip_text=db.ui('Keep at least five discovered groups active. Changes are saved only with Apply.','至少启用 5 组已发现奖励。点击应用后才会保存。')
 points.text='%d RP'%save.state.meta
 apply_button.visible=unlocked;all_button.visible=unlocked;none_button.visible=unlocked;unlock_button.visible=not unlocked
 apply_button.disabled=count<5
 apply_button.tooltip_text=db.ui('Keep at least five groups active.','至少启用 5 组奖励。') if count<5 else ''
 unlock_button.text=db.ui('UNLOCK FILTER  %d RP','解锁筛选  %d RP')%int(config.researchCost)
 unlock_button.disabled=save.state.meta<int(config.researchCost);show_selection()
func show_selection():
 if groups.is_empty():return
 var reward:Dictionary=db.asset(groups[selected][0]);selected_art.texture=db.reward_sprite(reward);selected_title.text=db.title(reward)
 selected_desc.text=db.text(reward.get('rewardDesc',''));selected_desc.tooltip_text=selected_desc.text
 selected_state.text=db.ui('%d EVOLUTION TIERS','%d 个进化阶段')%groups[selected].size()
func action(method:String,_id:String,_args:Dictionary):
 sound.call()
 match method:
  'BackButton':back.call()
  'ResearchSystem':save.unlock_reward_pool(int(config.researchCost));refresh()
  'ToggleAllButton','ToggleNoneButton':
   if not save.state.systems.get('ToggleResearches',false):return
   for key in draft:draft[key]=method=='ToggleAllButton'
   refresh()
  'ApplyButton':
   if save.apply_reward_pool(groups,draft):back.call()

func fit_screen():
 var viewport_size=get_viewport_rect().size
 var factor=minf(viewport_size.x/1440.0,viewport_size.y/900.0)
 scale=Vector2.ONE*factor;position=(viewport_size-Vector2(1440,900)*factor)*.5
 # Artwork fills the physical viewport while interactive content stays uniformly fitted.
 var background:Control=get_child(0)
 background.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 background.position=-position/factor;background.size=viewport_size/factor;background.queue_redraw()

func _exit_tree():
 var viewport=get_viewport()
 if viewport.size_changed.is_connected(fit_screen):viewport.size_changed.disconnect(fit_screen)
