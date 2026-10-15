extends SceneTree
## Hover real production controls, including the exact launch-button regression.
const UI=preload("res://scripts/game_ui.gd")
var game
var checks=[]
var captures=[]
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
 checks.append({"name":title,"passed":ok})
 if not ok:push_error(title)
func settle():
 for i in 5:await process_frame
func tooltip_label(node:Node,text:String)->Label:
 if node is Label and node.text==text and node.is_visible_in_tree():return node
 for child in node.get_children(true):
  var found=tooltip_label(child,text)
  if found!=null:return found
 return null
func move(at:Vector2):
 var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
 Input.parse_input_event(motion)
func hover(control:Control,tag:String):
 move(Vector2(5,5));await settle()
 var focus=root.gui_get_focus_owner()
 move(control.get_global_rect().get_center())
 await create_timer(0.8).timeout
 await settle()
 var label=tooltip_label(root,control.tooltip_text)
 check(label!=null,"Native tooltip appears: "+tag)
 if label!=null:
  check(label.get_theme_color("font_color")==UI.TOOLTIP_TEXT,"Actual tooltip text is high contrast: "+tag)
  var panel=label.get_parent()
  check(panel is PopupPanel,"Tooltip is engine-generated popup: "+tag)
  if panel is PopupPanel:
   var box=panel.get_theme_stylebox("panel","TooltipPanel")
   check(box is StyleBoxFlat and box.bg_color==UI.TOOLTIP_BG,"Actual tooltip panel is opaque dark purple: "+tag)
   check(box.content_margin_left>=12 and box.content_margin_top>=8,"Actual tooltip has readable padding: "+tag)
  check(root.gui_get_focus_owner()==focus,"Hover preserves keyboard focus: "+tag)
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   var path="res://artifacts/tooltip-"+tag+".png"
   check(root.get_texture().get_image().save_png(path)==OK,"Capture hover: "+tag)
   captures.append(path)
 move(Vector2(5,5));await settle()
func execute():
 root.size=Vector2i(1440,900);root.gui_embed_subwindows=true
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle();game.set_process(false)
 game.save.fresh();game.test_mode=true;game.save.state.settings.skip_boss=true
 for skin in [UI.theme(),load("res://scripts/blue_ink.gd").theme()]:
  check(skin.get_stylebox("panel","TooltipPanel").bg_color==UI.TOOLTIP_BG,"Both theme paths explicitly use dark purple tooltips")
  check(skin.get_color("font_color","TooltipLabel")==UI.TOOLTIP_TEXT,"Both theme paths explicitly use white tooltip text")
 game.start_run();game.show_build_ui();await settle()
 game.build_ui.return_button.grab_focus()
 await hover(game.build_ui.return_button,"launch")
 game.run.rewards.enqueue(true);game.run.offers=game.db.kind("BlockReward").slice(0,3);game.show_rewards();await settle()
 await hover(game.reward_ui.buttons[0],"reward")
 game.show_lab();await settle()
 var lab=game.panel.get_child(0)
 await hover(lab.node_buttons.values()[0],"research")
 game.show_reward_pool();await settle()
 var pool=game.panel.get_child(0)
 await hover(pool.cards[0],"codex")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"captures":captures,"renderer":DisplayServer.get_name()}
 FileAccess.open("res://artifacts/tooltip-theme-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
