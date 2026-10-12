extends SceneTree
var checks=[]
var game
func check(value:bool,name:String):
 checks.append({'name':name,'passed':value})
 if not value:push_error(name)
func press(button:int):
 var event=InputEventJoypadButton.new();event.device=0;event.button_index=button;event.pressed=true;Input.parse_input_event(event)
 await process_frame
 event=InputEventJoypadButton.new();event.device=0;event.button_index=button;event.pressed=false;Input.parse_input_event(event)
 await process_frame
func _initialize():call_deferred('execute')
func execute():
 game=load('res://main.tscn').instantiate();root.add_child(game);await process_frame;await process_frame
 game.test_mode=false;game.save.path='user://controller-isolated.json';game.save.fresh()
 await press(JOY_BUTTON_A);await process_frame
 check(game.screen=='home','Controller skips original intro')
 check(root.gui_get_focus_owner()!=null,'Menu has initial controller focus')
 game.show_missions();await process_frame;await process_frame
 await press(JOY_BUTTON_B)
 check(game.screen=='home','Controller back returns from mission menu')
 game.start_run();await process_frame
 var event=InputEventJoypadMotion.new();event.device=0;event.axis=JOY_AXIS_LEFT_X;event.axis_value=1.0;Input.parse_input_event(event);await process_frame
 check(game.controls.movement().x>0.9,'Left joystick controls movement')
 event=InputEventJoypadMotion.new();event.device=0;event.axis=JOY_AXIS_RIGHT_X;event.axis_value=1.0;Input.parse_input_event(event);await process_frame
 check(game.controls.joy_aim().x>0.9,'Right joystick aims')
 game.save.state.settings.invert_x=true
 check(game.controls.joy_aim().x< -0.9,'Invert aim setting applies')
 await press(JOY_BUTTON_START);check(game.screen=='pause','Controller start pauses')
 await press(JOY_BUTTON_B);check(game.screen=='game','Controller back resumes pause')
 await press(JOY_BUTTON_B);check(game.screen=='build','Controller opens construction')
 game.show_game();await process_frame
 await press(JOY_BUTTON_A);check(game.radar_mode,'Source controller south button toggles radar')
 game.begin_run();await process_frame
 var tip=game.tip_index
 event=InputEventJoypadMotion.new();event.device=0;event.axis=JOY_AXIS_LEFT_X;event.axis_value=0;Input.parse_input_event(event);await process_frame
 event.axis_value=1;Input.parse_input_event(event);await process_frame
 check(game.screen=='loading' and game.tip_index!=tip,'Left stick advances source loading tip')
 event=InputEventJoypadMotion.new();event.device=0;event.axis=JOY_AXIS_TRIGGER_RIGHT;event.axis_value=1;Input.parse_input_event(event);await process_frame
 check(game.screen=='game','Right trigger continues from loading to gameplay')
 game.cursor_system.shutdown();game.audio_system.shutdown();game.queue_free();await process_frame
 var report={'method':'Godot Input.parse_input_event joystick events; no physical controller connected. Actual physical controller acceptance remains pending.','checks':checks,'passed':checks.all(func(c):return c.passed)}
 FileAccess.open('res://artifacts/controller-test-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
