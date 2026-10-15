extends CanvasLayer
var queue:Array=[]
var active=false
func enqueue(text:String):
 if text.is_empty():return
 queue.append(text)
 if not active:next()
func next():
 if queue.is_empty():active=false;return
 active=true
 var label=Label.new();label.text=queue.pop_front();label.size=Vector2(538,90);label.position=Vector2(451,236);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override('font_size',25);label.add_theme_color_override('font_outline_color',Color.BLACK);label.add_theme_constant_override('outline_size',4);add_child(label)
 var ui=preload('res://scripts/game_ui.gd')
 ui.protect(label);label.theme=ui.theme();label.add_theme_stylebox_override('normal',ui.hud_style())
 label.add_theme_color_override('font_color',ui.TEXT);label.add_theme_constant_override('outline_size',0)
 var tween=label.create_tween();tween.set_parallel(true);tween.tween_property(label,'position',Vector2(451,45),1.0);tween.tween_property(label,'modulate:a',0.0,1.0);tween.chain().tween_callback(func():label.queue_free();next())
func clear():
 queue.clear();active=false
 for child in get_children():child.queue_free()
