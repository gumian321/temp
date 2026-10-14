extends SceneTree
# Native-renderer-only, frozen-pose A/B experiment. Production files unchanged.
const Rig=preload("res://scripts/soft_insect_rig.gd")
const HitShader=preload("res://shaders/insect_hit.gdshader")
var polygons:Array=[]
var originals:Array=[]
func _initialize():call_deferred("execute")
func collect(node:Node):
 if node is Polygon2D:polygons.append(node);originals.append(node.material)
 for child in node.get_children():collect(child)
func summary(values:Array)->Dictionary:
 values.sort()
 return {"p50":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))]}
func execute():
 if DisplayServer.get_name()=="headless":
  print("RIG_MATERIAL_NATIVE_REQUIRED");quit(1);return
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 root.size=Vector2i(1440,900);Engine.max_fps=0
 var report={"renderer":RenderingServer.get_video_adapter_name(),"scope":"Frozen 64 complete insect rigs; geometry, ordering, bones and textures identical. Compare unique hit materials versus shared idle material. No production changes.","fixtures":[]}
 for species_mode in ["beetle","mixed"]:
  var container=Node2D.new();root.add_child(container);polygons.clear();originals.clear()
  for i in 64:
   var species=["grub","beetle","moth","sac","mantis","queen"][i%6] if species_mode=="mixed" else "beetle"
   var at=Vector2(90+(i%8)*178,60+(i/8)*110)
   var entity={"uid":i+1,"kind":"AISwarmingUnit","position":at,"angle":-PI/2,"hp":100.0,"max_hp":100.0,"radius":30.0,"brood_species":species}
   var rig=Rig.new();rig.batch_appendages=false;container.add_child(rig);rig.setup(entity);rig.position=at;rig.scale=Vector2.ONE*40;rig.pose(0)
  collect(container)
  var shared=ShaderMaterial.new();shared.shader=HitShader
  shared.set_shader_parameter("hit_flash",0.0);shared.set_shader_parameter("pressure",0.0)
  var reference:PackedByteArray;var results=[]
  for mode in ["unique","shared_idle","no_shader_diagnostic"]:
   for i in polygons.size():polygons[i].material=originals[i] if mode=="unique" else (shared if mode=="shared_idle" else null)
   var calls=[];var objects=[];var times=[]
   for frame in 40:
    var started=Time.get_ticks_usec()
    await process_frame;await RenderingServer.frame_post_draw
    if frame>=10:
     calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
     objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
     times.append((Time.get_ticks_usec()-started)/1000.0)
   var image=root.get_texture().get_image();var pixels=image.get_data()
   if mode=="unique":reference=pixels
   var row={"mode":mode,"draw_calls":summary(calls),"objects":summary(objects),"frame_ms":summary(times),"pixel_identical_to_unique":pixels==reference,"polygons":polygons.size()}
   results.append(row);print("RIG_MATERIAL_CASE ",species_mode," ",JSON.stringify(row))
  report.fixtures.append({"species":species_mode,"results":results})
  container.queue_free();await process_frame;await process_frame
 var path=OS.get_environment("RBPEW_RIG_MATERIAL_OUTPUT")
 if path.is_empty():path="res://artifacts/rig-material-batching.json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("RIG_MATERIAL_REPORT ",JSON.stringify(report));quit()
