extends Button
const UI=preload("res://scripts/game_ui.gd")
var builder
var target:Dictionary={}
var payload:Dictionary={}
var selected=false
func setup(owner,t,p):
	builder=owner;target=t;payload=p;flat=true
	for state in ["normal","hover","pressed","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	tooltip_text=builder.db.title(builder.db.asset(payload.id))+" · 拖到身体上"
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	pressed.connect(func():builder.click(target,payload))
	mouse_entered.connect(func():builder.inspect(payload));mouse_exited.connect(func():builder.inspect({}))
func _draw():
	var texture=builder.db.core_sprite(builder.db.asset(payload.id))
	if texture!=null:draw_texture_rect(texture,Rect2(Vector2(10,8),Vector2(56,56)),false)
	if selected or has_focus() or is_hovered():draw_arc(size/2,34,0,TAU,40,UI.TEAL,2,true)
func _get_drag_data(_at):
	var preview=TextureRect.new();preview.texture=builder.db.core_sprite(builder.db.asset(payload.id));preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.size=Vector2(60,60);preview.position=Vector2(-30,-30)
	set_drag_preview(preview);builder.begin_drag(payload.duplicate());return payload.duplicate()
func _notification(what):
	if what==NOTIFICATION_DRAG_END and is_instance_valid(builder):builder.end_drag()
