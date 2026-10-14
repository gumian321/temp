extends SceneTree
# Frozen native-renderer PoC: only merge rigid appendages, never the soft skin.
# No production edits. Each polygon's triangle order, UV and transform retained.
const Rig=preload("res://scripts/soft_insect_rig.gd")
func _initialize():call_deferred("execute")
func collect(node:Node,result:Array):
 if node is Polygon2D:result.append(node)
 for child in node.get_children():collect(child,result)
func merge_appendages(rig)->MeshInstance2D:
 var pieces=[];collect(rig.limb_skeleton,pieces)
 var vertices=PackedVector3Array();var uvs=PackedVector2Array();var indices=PackedInt32Array()
 var inverse=rig.global_transform.affine_inverse()
 for piece in pieces:
  assert(piece.material==rig.hit_material and piece.texture==rig.art and piece.z_index==0)
  var transform=inverse*piece.global_transform;var base=vertices.size()
  for point in piece.polygon:
   var p=transform*point;vertices.append(Vector3(p.x,p.y,0))
  for uv in piece.uv:uvs.append(uv/rig.art.get_size())
  var triangles=Geometry2D.triangulate_polygon(piece.polygon)
  for index in triangles:indices.append(base+index)
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var instance=MeshInstance2D.new();instance.name="MergedAppendageDiagnostic";instance.mesh=mesh;instance.texture=rig.art;instance.material=rig.hit_material
 instance.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 rig.add_child(instance);rig.move_child(instance,0);instance.visible=false
 return instance
func summary(values:Array)->Dictionary:
 values.sort();return {"p50":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))]}
func image_diff(a:PackedByteArray,b:PackedByteArray)->Dictionary:
 var changed=0;var total=0;var maximum=0
 for i in a.size():
  var delta=absi(int(a[i])-int(b[i]));total+=delta;maximum=maxi(maximum,delta)
  if delta>0:changed+=1
 return {"pixel_identical":a==b,"changed_channel_pct":100.0*changed/maxi(1,a.size()),"mean_channel_delta":float(total)/maxi(1,a.size()),"max_channel_delta":maximum}
func execute():
 if DisplayServer.get_name()=="headless":print("APPENDAGE_BATCH_NATIVE_REQUIRED");quit(1);return
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 root.size=Vector2i(1440,900);Engine.max_fps=0
 var report={"renderer":RenderingServer.get_video_adapter_name(),"scope":"Frozen 64 rigs. Only rigid appendages merged in original scene-tree triangle order. Soft body, hit shader, textures, all bones unchanged. Diagnostic only; no per-frame update production path.","fixtures":[]}
 for species_mode in ["beetle","mixed"]:
  var container=Node2D.new();root.add_child(container);var rigs=[];var merged=[]
  for i in 64:
   var species=["grub","beetle","moth","sac","mantis","queen"][i%6] if species_mode=="mixed" else "beetle"
   var at=Vector2(90+(i%8)*178,60+(i/8)*110)
   var entity={"uid":i+1,"kind":"AISwarmingUnit","position":at,"angle":-PI/2+sin(i)*.25,"hp":100.0,"max_hp":100.0,"radius":30.0,"brood_species":species}
   var rig=Rig.new();rig.batch_appendages=false;container.add_child(rig);rig.setup(entity);rig.position=at;rig.scale=Vector2.ONE*40
   entity.soft_body.pose_clock=1.27;rig.pose(1.0/60.0);rigs.append(rig)
  # Let Bone2D/Skeleton2D transforms settle before reading their globals.
  await process_frame;await RenderingServer.frame_post_draw
  var prepare_start=Time.get_ticks_usec()
  for rig in rigs:merged.append(merge_appendages(rig))
  var prepare_ms=(Time.get_ticks_usec()-prepare_start)/1000.0
  var reference:PackedByteArray;var results=[]
  for mode in ["original","merged_rigid_appendages"]:
   for i in rigs.size():rigs[i].limb_skeleton.visible=mode=="original";merged[i].visible=mode!="original"
   var calls=[];var objects=[];var times=[]
   for frame in 40:
    var started=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
    if frame>=10:
     calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME));times.append((Time.get_ticks_usec()-started)/1000.0)
   var image=root.get_texture().get_image();var pixels=image.get_data()
   if mode=="original":reference=pixels
   var row={"mode":mode,"draw_calls":summary(calls),"objects":summary(objects),"frame_ms":summary(times),"visual_diff":image_diff(reference,pixels)}
   var prefix=OS.get_environment("RBPEW_APPENDAGE_OUTPUT").get_basename()
   if prefix.is_empty():prefix="res://artifacts/rig-appendage-batching"
   image.save_png(prefix+"-"+species_mode+"-"+mode+".png")
   results.append(row);print("APPENDAGE_BATCH_CASE ",species_mode," ",JSON.stringify(row))
  report.fixtures.append({"species":species_mode,"mesh_prepare_ms":prepare_ms,"results":results})
  container.queue_free();await process_frame;await process_frame
 var path=OS.get_environment("RBPEW_APPENDAGE_OUTPUT")
 if path.is_empty():path="res://artifacts/rig-appendage-batching.json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("APPENDAGE_BATCH_REPORT ",JSON.stringify(report));quit()
