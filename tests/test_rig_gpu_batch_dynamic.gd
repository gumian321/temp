extends SceneTree
const GPU=preload("res://tests/rig_gpu_batch_probe.gd")
const Rig=preload("res://scripts/soft_insect_rig.gd")
const Soft=preload("res://scripts/soft_insect.gd")
const SPECIES=["grub","beetle","moth","sac","mantis","queen"]
var failures=[]
func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
 if not ok:failures.append(label);printerr("FAIL ",label)
func verify_geometry(rig,label:String):
 var batch=rig.get_meta("gpu_batch")
 check(batch!=null and batch.active,label+" GPU batch active")
 check(batch.texture==rig.art and batch.material==rig.hit_material,label+" exact artwork and shader")
 check(batch.get_bone_count()>0,label+" rigid bones bound")
func stats(v:Array)->Dictionary:
 v.sort();return {"p50":v[v.size()/2],"p95":v[mini(v.size()-1,int(v.size()*.95))]}
func diff(a:PackedByteArray,b:PackedByteArray)->Dictionary:
 var total=0;var changed=0;var maximum=0
 for i in a.size():
  var delta=absi(int(a[i])-int(b[i]));total+=delta;maximum=maxi(maximum,delta)
  if delta>0:changed+=1
 return {"max_channel_delta":maximum,"mean_channel_delta":float(total)/a.size(),"changed_channel_pct":100.0*changed/a.size()}
func execute():
 var native=DisplayServer.get_name()!="headless"
 if native:DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 root.size=Vector2i(1440,900)
 var rigs=[];var timings=[];var snapshots=[]
 for i in 6:
  var rig=Rig.new();rig.batch_appendages=false;root.add_child(rig)
  var entity={"uid":i+1,"kind":"AISwarmingUnit","position":Vector2(190+i%3*480,200+i/3*440),"angle":-.7,"hp":100.0,"max_hp":100.0,"radius":45.0,"brood_species":SPECIES[i]}
  rig.setup(entity);rig.position=entity.position;rig.scale=Vector2.ONE*100;rigs.append(rig)
  var gpu=GPU.new();gpu.setup(rig);rig.set_meta("gpu_batch",gpu)
 for frame in 120:
  var started=Time.get_ticks_usec()
  for i in rigs.size():
   var rig=rigs[i];var e=rig.entity
   e.position+=Vector2(cos(frame*.08+i),sin(frame*.07+i))*1.7;e.angle+=.03
   if frame==35:Soft.impact(e,e.position+Vector2(15,10),Vector2.RIGHT,40,"cannon")
   Soft.step(e,1.0/60.0);rig.position=e.position
   rig.pose(1.0/60.0,frame>=106)
  timings.append((Time.get_ticks_usec()-started)/1000.0)
  if frame in [0,30,36,60,110]:
   for rig in rigs:verify_geometry(rig,str(frame)+" "+rig.entity.brood_species)
   if native:
    var reference:PackedByteArray;var row={"frame":frame}
    for batched in [false,true]:
     for rig in rigs:rig.get_meta("gpu_batch").set_enabled(batched)
     await process_frame;await RenderingServer.frame_post_draw
     await process_frame;await RenderingServer.frame_post_draw
     var image=root.get_texture().get_image();var pixels=image.get_data()
     row["batched_draw_calls" if batched else "original_draw_calls"]=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
     if not batched:reference=pixels
     else:
      row.diff=diff(reference,pixels)
      check(row.diff.mean_channel_delta<.01 and row.diff.changed_channel_pct<.5,"Frame %d retains all geometry, alpha ordering and hit/death feedback"%frame)
     if frame in [30,36,110]:image.save_png("res://artifacts/rig-gpu-dynamic-%d-%s.png"%[frame,"batched" if batched else "original"])
    snapshots.append(row)
 for rig in rigs:
  rig.visible=false;rig.entity.position+=Vector2(300,200);rig.pose(1.0/60.0);rig.visible=true;verify_geometry(rig,"reentry")
  rig.queue_free()
 await process_frame
 for species in SPECIES:
  var packed=load("res://assets/blue_ink/brood/rigs/"+species+".tscn")
  var rig=packed.instantiate();rig.batch_appendages=false;root.add_child(rig);rig.set_process(false);rig.pose(1.0/60.0)
  var gpu=GPU.new();gpu.setup(rig);rig.set_meta("gpu_batch",gpu)
  verify_geometry(rig,"packed preview "+species);rig.queue_free()
 await process_frame
 var report={"passed":failures.is_empty(),"failures":failures,"native":native,"six_rig_pose_and_batch_ms":stats(timings),"snapshots":snapshots,"scope":"Six species: motion, turning, cannon impact, death, hidden/reentry and existing packed preview scenes; exact transformed vertices; native original/batched same-pose image and actual draw-call comparison."}
 var path=OS.get_environment("RBPEW_GPU_RIG_OUTPUT")
 if path.is_empty():path="res://artifacts/rig-gpu-batch-dynamic.json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("RIG_GPU_BATCH_DYNAMIC ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
