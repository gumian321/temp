extends Node
var textures:Dictionary={}
var idle=0.0
var current_type=1
func setup(_db):
 var arrow=load('res://assets/blue_ink/cursor_arrow.svg')
 var aim=load('res://assets/blue_ink/cursor_aim.svg')
 var hand=load('res://assets/blue_ink/cursor_hand.svg')
 textures={1:{'images':[arrow],'hotspot':Vector2(3,2)/arrow.get_size()},2:{'images':[aim],'hotspot':Vector2(0.5,0.5)},3:{'images':[aim],'hotspot':Vector2(0.5,0.5)},4:{'images':[hand],'hotspot':Vector2(13,2)/hand.get_size()}}
 set_cursor(1)
 Input.set_custom_mouse_cursor(hand,Input.CURSOR_POINTING_HAND,Vector2(13,2))
func set_cursor(type:int,count:int=0):
 if type==0:Input.mouse_mode=Input.MOUSE_MODE_HIDDEN;return
 if not textures.has(type):return
 current_type=type
 var data=textures[type];var image=data.images[clampi(count,0,data.images.size()-1)]
 Input.set_custom_mouse_cursor(image,Input.CURSOR_ARROW,image.get_size()*data.hotspot)
func _input(event):
 if event is InputEventMouseMotion and event.relative!=Vector2.ZERO:
  idle=0;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 elif event is InputEventJoypadButton or event is InputEventJoypadMotion:Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
func _process(dt):
 idle+=dt
 if idle>=3:Input.mouse_mode=Input.MOUSE_MODE_HIDDEN

func shutdown():
 Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
 Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
 textures.clear()
