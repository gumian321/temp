extends SceneTree
## Native clock-only evidence: all geometry, effect lifetimes and positions frozen.
const Layer=preload("res://scripts/attack_shader_layer.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const Controls=preload("res://scripts/insect_attack_fx.gd")
var checks=[]
var per_family=[]
class Canvas extends Node2D:
 func world(at):return at
func _initialize():call_deferred("execute")
func check(ok,title):
 checks.append({"name":title,"passed":ok})
 if not ok:printerr("FAIL: ",title)
func execute():
 if DisplayServer.get_name()=="headless":
  printerr("ERROR: Shader proof requires native renderer");quit(1);return
 root.size=Vector2i(1440,900)
 var canvas=Canvas.new();root.add_child(canvas)
 var backdrop=ColorRect.new();backdrop.color=Color("142333");backdrop.size=Vector2(1440,900);backdrop.z_index=-1;canvas.add_child(backdrop)
 var layer=Layer.new();layer.trace_commands=true;layer.attach(canvas);layer.begin_frame(0.0)
 var fx=FX.new();fx.clock=0.33
 var db=load("res://scripts/source_db.gd").new()
 var keys=Layer.MODES.keys()
 for i in keys.size():
  var key=keys[i]
  var at=Vector2(140+(i%5)*280,150+(i/5)*195)
  var label=Label.new();label.text=key.to_upper();label.position=at+Vector2(-90,-73);label.add_theme_font_size_override("font_size",22);canvas.add_child(label)
  if key in ["repair_drone","scrap_drone"]:
   var painter=Layer.route(canvas,key,false)
   painter.draw_set_transform(at)
   painter.draw_texture_rect(db.sprite(db.named("Drones_Core_Engineer" if key=="repair_drone" else "Drones_Core_Scrapper").droneSprite),Rect2(-45,-28,90,56),false,Color.WHITE)
  elif key in ["silk","tendril"]:
   Controls.paint(canvas,[{"kind":key,"origin":at-Vector2(90,0),"target":{"position":at+Vector2(65,0),"hp":100,"radius":19},"life":0.65,"duration":1.0,"friendly":true}],1.0)
  elif key=="blackhole":fx.paint_hole(canvas,{"position":at,"radius":48,"friendly":true},1.0)
  elif key in ["rail","tesla","sonic","flame"]:
   fx.paint_effect(canvas,{"kind":"flame" if key=="flame" else "chain","position":at-Vector2(90,0),"end":at+Vector2(85,0),"fx_family":key,"life":0.65,"fx_duration":1.0,"friendly":true},1.3)
  elif key=="impact":
   fx.paint_effect(canvas,{"kind":"explosion","position":at,"fx_family":key,"radius":65,"life":0.65,"fx_duration":1.0,"friendly":true},1.0)
  else:
   fx.paint_projectile(canvas,{"position":at,"origin":at-Vector2(110,0),"previous":at-Vector2(5,0),"velocity":Vector2(300,0),"age":0.33,"radius":7,"fx_family":key,"friendly":true},0.33,2.6)
  check(layer.batches[key+"false"].batch.commands.size()>0,key+" production route populated")
 var initial_commands=layer.stats().commands
 var images=[]
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/round14/shader-frames"))
 for frame in range(60):
  for material in layer.materials.values():material.set_shader_parameter("clock",frame/15.0)
  await process_frame
  await RenderingServer.frame_post_draw
  var image=root.get_texture().get_image()
  if frame in [0,23,59]:images.append(image)
  check(image.save_png("res://artifacts/round14/shader-frames/frame-%04d.png"%frame)==OK,"Captured shader-only frame %d"%frame)
 check(layer.stats().commands==initial_commands,"No geometry rebuild or motion across shader-only movie")
 for i in keys.size():
  var rect=Rect2i(50+(i%5)*280,105+(i/5)*195,225,110)
  var changed=0
  for y in range(rect.position.y,rect.end.y):
   for x in range(rect.position.x,rect.end.x):
    if images[0].get_pixel(x,y)!=images[1].get_pixel(x,y):changed+=1
  per_family.append({"family":keys[i],"changed_pixels":changed,"sample_pixels":rect.size.x*rect.size.y})
  check(changed>5,keys[i]+" native pixels change when ONLY shader clock changes")
 var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"per_family":per_family,"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"frames":60,"fps":15,"frozen_geometry_commands":initial_commands,"scope":"Production material batches and production drawing entrypoints, fixed geometry/lifetimes/textures. Only uniform clock changes. Native OpenGL, no headless fallback."}
 FileAccess.open("res://artifacts/round14/shader-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report));quit(0 if report.passed else 1)
