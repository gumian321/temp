extends Node2D
var db
var config:Dictionary
var ships:Array=[]
var camera_position=Vector2.ZERO
var camera_target=Vector2.ZERO
var zoom_size=9.0
var zoom_target=9.0
var camera_config:Dictionary={}
func setup(source):
 db=source;config=db.read_json('menu_background');camera_config=db.scene_config.get('MainMenuCameraManager',{})
 for i in int(config.objectsCount):ships.append(spawn_ship())
func spawn_ship()->Dictionary:
 var source=config.objects.pick_random()
 var start=Vector2(randf_range(config.XBorders.x,config.XBorders.y),-config.lowY)*48
 var target=Vector2(randf_range(config.XBorders.x,config.XBorders.y),-config.topY)*48
 if randf()>0.5:var temp=start;start=target;target=temp
 return {'position':start,'target':target,'direction':start.direction_to(target),'speed':float(source.speed)*48,'render':load('res://scripts/render_state.gd').instantiate(db.prefabs[source.prefab].render,ships.size()+int(start.x*100)), 'age':0.0}
func _process(dt):
 if not visible:return
 camera_position=camera_position.lerp(camera_target,minf(1,dt*float(camera_config.get("movingSpeed",4))))
 zoom_size=lerpf(zoom_size,zoom_target,minf(1,dt*float(camera_config.get("zoomingSpeed",8))))
 for i in ships.size():
  var ship=ships[i];ship.age+=dt;ship.position=ship.position.move_toward(ship.target,ship.speed*dt)
  if ship.position.distance_to(ship.target)<24:ships[i]=spawn_ship()
 queue_redraw()
func _draw():
 for ship in ships:
  var angle=Vector2(ship.direction).angle()
  for renderer in ship.render:
   var texture=db.sprite(renderer.sprite)
   if texture==null:continue
   var at=Vector2(720,450)+(ship.position-camera_position+Vector2(renderer.x,renderer.y).rotated(angle)*48)*(9.0/zoom_size)
   if at.x< -250 or at.x>1690 or at.y< -250 or at.y>1150:continue
   var size=texture.get_size()/float(db.sprites[renderer.sprite].get('ppu',100))*Vector2(renderer.sx,renderer.sy)*48*(9.0/zoom_size)
   draw_set_transform(at,angle+load("res://scripts/render_state.gd").angle(renderer,ship.age))
   draw_texture_rect(texture,Rect2(-size*0.5,size),false,load("res://scripts/render_state.gd").color(renderer,ship.age))
 draw_set_transform(Vector2.ZERO)

func set_menu(screen:String):
 var key={"home":["MainMenuManager","mainMenuCamPos"],"menu":["PlayUIManager","CamPos"],"options":["OptionMenuManager","OptionCamPos"],"controls":["ControlUIManager","OptionCamPos"],"lab":["UpgradeTreeManager","TreeCamPos"],"reward_pool":["ToggleResearchUIManager","CamPos"]}.get(screen,["MainMenuManager","mainMenuCamPos"])
 var position:Dictionary=db.scene_config.get(key[0],{}).get(key[1],{})
 camera_target=Vector2(float(position.get('x',0)),-float(position.get('y',0)))*48
 zoom_target=float(camera_config.get('zoomOutSize',9))
