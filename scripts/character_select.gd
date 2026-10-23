extends Control
const UI=preload("res://scripts/game_ui.gd")
const Roster=preload("res://scripts/character_roster.gd")
const Art=preload("res://scripts/character_art.gd")
var game
var cards:Dictionary={}
var content:Control
var status:Label
var debug_unlock_button:Button
func setup(owner_game):
 game=owner_game;UI.protect(self);theme=UI.theme()
 set_anchors_and_offsets_preset(PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_STOP
 resized.connect(layout_content);rebuild()
func layout_content():
 if not is_instance_valid(content):return
 var factor=minf(size.x/1440.0,size.y/900.0)
 content.scale=Vector2.ONE*factor;content.position=(size-Vector2(1440,900)*factor)/2
func rebuild():
 for child in get_children():remove_child(child);child.queue_free()
 cards.clear();content=Control.new();content.size=Vector2(1440,900);add_child(content);UI.backdrop(content)
 UI.header(content,game.db.ui("INSECT NEST","虫巢"),game.show_menu)
 UI.label(content,game.db.ui("CHOOSE YOUR INSTINCT","选择你的生存本能"),Vector2(72,119),22,UI.MUTED)
 debug_unlock_button=UI.button(content,game.db.ui("DEBUG · UNLOCK 2 CHARACTERS","DEBUG · 解锁双角色"),Rect2(990,103,380,52),unlock_debug_characters,"",UI.AMBER)
 debug_unlock_button.add_theme_font_size_override("font_size",20)
 debug_unlock_button.tooltip_text=game.db.ui("Unlock Centipede and Spider for this save.","一键开放蜈蚣、蜘蛛，自动保存。")
 var selected=str(game.save.state.selected_character)
 var row_width=Roster.ids().size()*424+(Roster.ids().size()-1)*18
 var row_left=(1440.0-row_width)/2.0
 for i in Roster.ids().size():
  var id:String=Roster.ids()[i];var data=Roster.config(id)
  var unlocked=game.save.character_unlocked(id);var chosen=selected==id
  var card=Button.new();card.position=Vector2(row_left+i*442,180);card.size=Vector2(424,554);card.clip_contents=true;card.mouse_default_cursor_shape=CURSOR_POINTING_HAND
  for state in ["normal","hover","pressed","hover_pressed"]:card.add_theme_stylebox_override(state,UI.card_style(chosen or state!="normal"))
  card.add_theme_stylebox_override("focus",UI.card_focus_style())
  content.add_child(card);cards[id]=card;card.pressed.connect(func():choose(id))
  var portrait=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.texture=Art.portrait(id);portrait.position=Vector2(22,66);portrait.size=Vector2(380,244);portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=MOUSE_FILTER_IGNORE;portrait.modulate=Color.WHITE if unlocked else Color(.72,.65,.8,.72);card.add_child(portrait)
  UI.label(card,str(data.display_name),Vector2(28,21),34)
  UI.label(card,"✓  "+game.db.ui("SELECTED","已选择") if chosen else game.db.ui("AVAILABLE","已解锁") if unlocked else game.db.ui("LOCKED","未解锁"),Vector2(276,32),18,UI.TEAL if unlocked else UI.MUTED)
  UI.label(card,str(data.label),Vector2(28,306),25)
  UI.label(card,str(data.skill_name)+"  ·  "+{"centipede":"蜷缩聚火","spider":"织网聚怪"}[id],Vector2(28,349),20,UI.TEAL)
  UI.label(card,game.db.ui("UP TO %d MOUNTS","最多 %d 个挂点")%int(data.slot_cap),Vector2(28,391),19,UI.MUTED)
  var weakness=UI.label(card,str(data.weakness),Vector2(28,421),16,UI.MUTED);weakness.size=Vector2(368,40);weakness.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  var goal=UI.label(card,"",Vector2(28,467),17);goal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;goal.clip_text=true;goal.max_lines_visible=3;goal.text=unlock_text(id) if not unlocked else str(data.equipment_rule);goal.size=Vector2(368,80)
  card.tooltip_text=str(data.equipment_rule)+"\n"+str(data.weakness)
 status=UI.label(content,game.db.ui("Selection applies to your next expedition.","选择将在下一次出击生效。"),Vector2(72,774),21,UI.MUTED)
 UI.button(content,game.db.ui("DEPLOY  →","前往远征  →"),Rect2(1060,770,310,68),game.show_missions,"play",UI.AMBER)
 layout_content()
func unlock_text(id:String)->String:
 var progress:Dictionary=game.save.state.roster_progress
 if id=="spider":return game.db.ui("Centipede: acquire 3 support modules in one run\nBEST  %d / 3","蜈蚣单局获得 3 个支援模块\n最佳  %d / 3")%mini(3,int(progress.get("support_modules_best",0)))
 return game.db.ui("Available from the start","初始角色")
func choose(id:String):
 if not game.save.character_unlocked(id):status.text=unlock_text(id).replace("\n","  ·  ");return
 if game.save.select_character(id):game.audio_system.play(70);rebuild()
 else:status.text=game.db.ui("Could not save selection. Please try again.","选择未能保存，请重试。")

func unlock_debug_characters():
 if not game.save.unlock_all_characters():
  status.text=game.db.ui("Could not save unlocks. Please try again.","解锁未能保存，请重试。")
  return
 game.audio_system.play(70);rebuild()
 status.text=game.db.ui("Both characters unlocked. Choose one, then deploy.","双角色已解锁，选好角色后前往远征。")
