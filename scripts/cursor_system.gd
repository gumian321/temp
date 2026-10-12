extends Node
var textures:Dictionary={}
var idle=0.0
var current_type=1
func setup(db):
 for entry in db.read_json('cursors'):
  var list=[]
  for source in entry.cursorTexturesList:
   var texture=load(source.path)
   if texture.get_width()>256 or texture.get_height()>256:
    var image=texture.get_image();var factor=256.0/maxi(image.get_width(),image.get_height());image.resize(roundi(image.get_width()*factor),roundi(image.get_height()*factor),Image.INTERPOLATE_NEAREST);texture=ImageTexture.create_from_image(image)
   list.append(texture)
  textures[int(entry.curserType)]={'images':list,'hotspot':Vector2(entry.hotSpot.x,entry.hotSpot.y)}
 set_cursor(1)
 var hand=textures[4];var image=hand.images[0]
 Input.set_custom_mouse_cursor(image,Input.CURSOR_POINTING_HAND,image.get_size()*hand.hotspot)
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
