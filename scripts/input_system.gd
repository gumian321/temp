extends RefCounted
const DEFAULTS={"move_left":KEY_A,"move_right":KEY_D,"move_up":KEY_W,"move_down":KEY_S,"boost":KEY_SHIFT,"build":KEY_E,"radar":KEY_TAB,"pause":KEY_ESCAPE}
var save
var active_joy=-1
func observe(event):
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:active_joy=event.device
func joy_device()->int:
	var connected=Input.get_connected_joypads()
	return connected[0] if not connected.is_empty() else active_joy
func _init(persistence):
	save=persistence
	apply()
func apply():
	for action in DEFAULTS:
		if not InputMap.has_action(action):InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event=InputEventKey.new();event.physical_keycode=int(save.state.settings.get("bindings",{}).get(action,DEFAULTS[action]));InputMap.action_add_event(action,event)
	var joy_buttons={"build":JOY_BUTTON_B,"radar":JOY_BUTTON_A,"pause":JOY_BUTTON_START}
	var right_click=InputEventMouseButton.new();right_click.button_index=MOUSE_BUTTON_RIGHT;InputMap.action_add_event("radar",right_click)
	var trigger=InputEventJoypadMotion.new();trigger.axis=JOY_AXIS_TRIGGER_LEFT;trigger.axis_value=1.0;InputMap.action_add_event("boost",trigger)
	for action in joy_buttons:
		var event=InputEventJoypadButton.new();event.button_index=joy_buttons[action];InputMap.action_add_event(action,event)
func bind(action:String,key:int):
	if key==KEY_PRINT or key==0:return
	save.state.settings.bindings[action]=key
	save.save();apply()
func movement(raw_axes:bool=false)->Vector2:
	var value=Vector2(Input.get_axis("move_left","move_right"),Input.get_axis("move_up","move_down"))
	if joy_device()>=0:
		var id=joy_device()
		var stick=Vector2(Input.get_joy_axis(id,JOY_AXIS_LEFT_X),Input.get_joy_axis(id,JOY_AXIS_LEFT_Y))
		if stick.length()>0.15:value=stick
	return value if raw_axes else value.limit_length()
func joy_aim()->Vector2:
	if joy_device()<0:return Vector2.ZERO
	var id=joy_device()
	var left=bool(save.state.settings.get("left_aim",false))
	var value=Vector2(Input.get_joy_axis(id,JOY_AXIS_LEFT_X if left else JOY_AXIS_RIGHT_X),Input.get_joy_axis(id,JOY_AXIS_LEFT_Y if left else JOY_AXIS_RIGHT_Y))
	if save.state.settings.get("invert_x",false):value.x=-value.x
	if save.state.settings.get("invert_y",false):value.y=-value.y
	return value if value.length()>0.15 else Vector2.ZERO
func shooting()->bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):return true
	if joy_device()<0:return false
	var id=joy_device()
	return Input.get_joy_axis(id,JOY_AXIS_TRIGGER_RIGHT)>0.2
