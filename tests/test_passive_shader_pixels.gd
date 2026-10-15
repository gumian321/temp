extends SceneTree
var checks=[]
func _initialize():call_deferred("execute")
func check(ok,title):
 checks.append({"name":title,"passed":ok})
 if not ok:printerr("FAIL: ",title)
func execute():
 if DisplayServer.get_name()=="headless":
  printerr("ERROR: Native shader renderer required");quit(1);return
 root.size=Vector2i(1440,900)
 var canvas=Node2D.new();root.add_child(canvas)
 var backdrop=ColorRect.new();backdrop.color=Color("e8e5d8");backdrop.size=Vector2(1440,900);backdrop.z_index=-1;canvas.add_child(backdrop)
 var passive=load("res://scripts/passive_feedback.gd").new();passive.setup(canvas);passive.card.hide();passive.stat_readout.hide()
 var living=passive.living;living.begin(0);living.set_viewport(Vector2(1440,900))
 for i in 6:
  var at=Vector2(240+(i%3)*480,240+(i/3)*420)
  var label=Label.new();label.text=living.KEYS[i].to_upper();label.position=at-Vector2(85,170);label.add_theme_color_override("font_color",Color("203a4a"));label.add_theme_font_size_override("font_size",26);canvas.add_child(label)
  living.add(i,at,Vector2(270,270),0,Color(1,0,1,1),Color(.5,0,0,0))
 living.finish()
 var images=[]
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/round14/passive-frames"))
 for frame in 60:
  for node in living.nodes:node.material.set_shader_parameter("sim_time",float(frame)/15)
  await process_frame
  await RenderingServer.frame_post_draw
  var image=root.get_texture().get_image()
  if frame in [0,23]:images.append(image)
  check(image.save_png("res://artifacts/round14/passive-frames/frame-%04d.png"%frame)==OK,"Captured passive shader frame %d"%frame)
 var pixels=[]
 for i in 6:
  var at=Vector2i(240+(i%3)*480,240+(i/3)*420)
  var changed=0
  for y in range(at.y-140,at.y+140):
   for x in range(at.x-140,at.x+140):
    if images[0].get_pixel(x,y)!=images[1].get_pixel(x,y):changed+=1
  pixels.append({"mode":living.KEYS[i],"changed_pixels":changed})
  check(changed>20,living.KEYS[i]+" frozen instance pixels change using only sim_time uniform")
 var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"pixels":pixels,"renderer":RenderingServer.get_video_adapter_name(),"frames":60,"fps":15,"scope":"Six production instanced materials, original atlas and fixed per-instance transforms/state. Only shader sim_time changes; no CPU geometry motion."}
 FileAccess.open("res://artifacts/round14/passive-shader-pixels-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
