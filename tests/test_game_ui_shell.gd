extends SceneTree
var game
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
 checks.append({"name":title,"passed":ok})
 if not ok:push_error(title)
func settle():
 await process_frame
 await process_frame
func capture(label:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/ui-overhaul-"+label+".png")
func execute():
 root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle();game.set_process(false)
 game.save.path="user://ui-shell-isolated.json";game.save.fresh()
 check(game.screen=="home" and game.panel.has_meta("game_ui"),"Home uses independent game UI theme")
 var buttons=[];game.collect_focus_buttons(game.panel,buttons)
 var navigation=buttons.filter(func(b):return b!=game.debug_unlock_button)
 check(navigation.size()==6 and buttons.has(game.debug_unlock_button) and root.gui_get_focus_owner()!=null,"Home retains six navigation controls plus the explicit debug unlock-all button")
 check(buttons[0].get_theme_color("font_color")==load("res://scripts/game_ui.gd").TEXT,"Deferred Ink styling does not overwrite new UI")
 await capture("home")
 var nest_buttons=buttons.filter(func(b):return b.text==game.db.ui("INSECT NEST","虫巢"))
 check(nest_buttons.size()==1,"Home includes one explicit Insect Nest entry")
 if nest_buttons.size()==1:
  var nest_click=InputEventMouseButton.new();nest_click.button_index=MOUSE_BUTTON_LEFT;nest_click.position=nest_buttons[0].get_global_rect().get_center();nest_click.global_position=nest_click.position;nest_click.pressed=true
  Input.parse_input_event(nest_click);await settle()
  nest_click=nest_click.duplicate();nest_click.pressed=false;Input.parse_input_event(nest_click);await settle()
  check(game.screen=="characters","Clicking the home Nest entry opens character selection")
 game.show_menu();await settle()
 game.show_options();await settle()
 check(not game.source_ui.visible,"Old option layout is hidden while backing source behavior is preserved")
 check(game.panel.has_meta("game_ui"),"Options has protected redesigned shell")
 var skin=game.panel.theme
 check(skin.get_stylebox("slider","HSlider").get_minimum_size().y>=8 and skin.get_stylebox("grabber_area","HSlider").get_minimum_size().y>=8,"Audio tracks and fill have visible eight-pixel thickness")
 check(skin.get_icon("grabber","HSlider").get_width()==26 and skin.has_icon("grabber_highlight","HSlider"),"Audio thumb has teal normal and amber highlighted artwork")
 await capture("options")
 game.show_controls();await settle()
 check(game.rebind_action=="","Control screen starts without pending rebind")
 await capture("controls")
 var control_buttons=[];game.collect_focus_buttons(game.panel,control_buttons)
 var bindings_before=game.save.state.settings.bindings.duplicate(true)
 control_buttons[1].pressed.emit()
 check(game.rebind_action!="","Selecting a binding starts key capture")
 control_buttons[0].pressed.emit();await settle()
 check(game.screen=="options" and game.rebind_action=="","Mouse Back cancels interrupted rebinding")
 var unrelated_key=InputEventKey.new();unrelated_key.physical_keycode=KEY_K;unrelated_key.pressed=true
 game._unhandled_input(unrelated_key);await settle()
 check(game.screen=="options" and game.save.state.settings.bindings==bindings_before,"Unrelated key after Back neither changes a binding nor reopens controls")
 game.show_controls();await settle();control_buttons.clear();game.collect_focus_buttons(game.panel,control_buttons)
 control_buttons[1].pressed.emit();game.show_controls();await settle()
 check(game.rebind_action=="","Rebuilding controls cancels an obsolete pending capture")
 for code in [KEY_TAB,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_ENTER,KEY_SPACE]:
  control_buttons.clear();game.collect_focus_buttons(game.panel,control_buttons)
  control_buttons[1].grab_focus();control_buttons[1].pressed.emit()
  var captured_key=InputEventKey.new();captured_key.keycode=code;captured_key.physical_keycode=code;captured_key.pressed=true
  Input.parse_input_event(captured_key);await settle()
  captured_key=InputEventKey.new();captured_key.keycode=code;captured_key.physical_keycode=code;captured_key.pressed=false
  Input.parse_input_event(captured_key);await settle()
  check(game.screen=="controls" and game.rebind_action=="" and int(game.save.state.settings.bindings.get("move_left",0))==code,"Rebinding captures "+OS.get_keycode_string(code)+" before GUI navigation")
 var before_escape=game.save.state.settings.bindings.duplicate(true)
 control_buttons.clear();game.collect_focus_buttons(game.panel,control_buttons);control_buttons[1].pressed.emit()
 var cancel_key=InputEventKey.new();cancel_key.keycode=KEY_ESCAPE;cancel_key.physical_keycode=KEY_ESCAPE;cancel_key.pressed=true
 Input.parse_input_event(cancel_key);await settle()
 cancel_key=InputEventKey.new();cancel_key.keycode=KEY_ESCAPE;cancel_key.physical_keycode=KEY_ESCAPE;cancel_key.pressed=false
 Input.parse_input_event(cancel_key);await settle()
 check(game.screen=="controls" and game.rebind_action=="" and game.save.state.settings.bindings==before_escape,"Escape cancels capture without rebinding or leaving controls")
 game.save.state.settings.bindings=bindings_before;game.controls.apply();game.save.save()
 game.start_run();game.show_pause();await settle()
 check(game.screen=="pause" and not game.source_ui.visible,"Pause uses new shell")
 await capture("pause")
 game.show_loading();await settle()
 check(is_instance_valid(game.tip_video) and game.tip_video.is_visible_in_tree(),"Loading video is attached to visible redesigned manual")
 await capture("manual")
 var manual_buttons=[];game.collect_focus_buttons(game.panel,manual_buttons)
 manual_buttons[1].grab_focus()
 var tip_before=game.tip_index
 var accept=InputEventKey.new();accept.keycode=KEY_ENTER;accept.physical_keycode=KEY_ENTER;accept.pressed=true
 Input.parse_input_event(accept);await settle()
 accept=InputEventKey.new();accept.keycode=KEY_ENTER;accept.physical_keycode=KEY_ENTER;accept.pressed=false
 Input.parse_input_event(accept);await settle()
 check(game.screen=="loading" and game.tip_index!=tip_before,"Enter on focused manual Next advances a page without deploying")
 tip_before=game.tip_index
 var joy_accept=InputEventJoypadButton.new();joy_accept.device=0;joy_accept.button_index=JOY_BUTTON_A;joy_accept.pressed=true
 Input.parse_input_event(joy_accept);await settle()
 joy_accept=InputEventJoypadButton.new();joy_accept.device=0;joy_accept.button_index=JOY_BUTTON_A;joy_accept.pressed=false
 Input.parse_input_event(joy_accept);await settle()
 check(game.screen=="loading" and game.tip_index!=tip_before,"Controller A respects focused manual Next")
 var deploy=InputEventJoypadMotion.new();deploy.device=0;deploy.axis=JOY_AXIS_TRIGGER_RIGHT;deploy.axis_value=1.0
 Input.parse_input_event(deploy);await settle()
 check(game.screen=="game","Manual retains right-trigger deployment shortcut")
 game.run.finish(false);game.show_result();await settle()
 check(game.screen=="result" and not game.source_ui.visible,"Result uses new rating and numeric summary shell")
 await capture("result")
 game.tutorials.reset_run();game.tutorials.show_tip("move");await settle()
 check(game.tutorials.cards.has("move") and game.tutorials.cards.move.visible,"Tutorial has icon/keycap card without replacing count semantics")
 game.show_menu();await settle();root.size=Vector2i(1280,720);await settle();await capture("home-720")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.queue_free();await process_frame
 var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
 FileAccess.open("res://artifacts/game-ui-shell-test-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
