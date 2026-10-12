extends Control
var sequence:Tween
func setup(db,finished:Callable):
 var background=ColorRect.new();background.size=Vector2(1440,900);background.color=Color.BLACK;add_child(background)
 var config:Dictionary=db.read_json('intro')
 sequence=create_tween()
 for entry in config.pages:
  var group=Control.new();add_child(group);group.modulate.a=0
  if entry.has('objImage'):
   var image=entry.objImage;var texture=db.sprite(image.sprite);var rect=TextureRect.new()
   rect.texture=texture;rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
   rect.size=texture.get_size()/float(db.sprites[image.sprite].ppu)*90*Vector2(image.pose[2],image.pose[3])
   rect.position=Vector2(720,450)+Vector2(image.pose[0],-image.pose[1])*90-rect.size/2
   group.add_child(rect)
  if entry.has('objText'):
   var text=entry.objText;var label=Label.new();label.text=text.text;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   label.position=Vector2(120,450-text.pose[1]*90-40);label.size=Vector2(1200,80);label.add_theme_font_size_override('font_size',36);group.add_child(label)
  sequence.tween_property(group,'modulate:a',1.0,float(config.half_duration))
  sequence.tween_property(group,'modulate:a',0.0,float(config.half_duration))
 sequence.tween_callback(finished)
