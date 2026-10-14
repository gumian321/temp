extends SceneTree
const Rig=preload("res://scripts/soft_insect_rig.gd")
func _initialize():call_deferred("execute")
func build_2d(batch)->PackedVector2Array:
 var result=PackedVector2Array();var inverse=batch.rig.global_transform.affine_inverse()
 for binding in batch.bindings:
  var piece={"node":binding.node,"points":binding.node.polygon}
  var transform=inverse*piece.node.global_transform
  result.append_array(transform*piece.points)
 return result
func build_3d(batch)->PackedVector3Array:
 var result=PackedVector3Array();var inverse=batch.rig.global_transform.affine_inverse()
 for binding in batch.bindings:
  var transform=inverse*binding.node.global_transform
  for point in binding.node.polygon:
   var p=transform*point;result.append(Vector3(p.x,p.y,0))
 return result
func stats(a:Array)->Dictionary:
 a.sort();return {"p50":a[a.size()/2],"p95":a[int(a.size()*.95)]}
func execute():
 var rigs=[];var slow=[];var fast=[];var max_error=0.0
 for i in 64:
  var rig=Rig.new();root.add_child(rig);rig.setup({"uid":i+1,"kind":"AISwarmingUnit","position":Vector2(i*12,0),"angle":i*.1,"hp":100.0,"max_hp":100.0,"radius":30.0,"brood_species":["grub","beetle","moth","sac","mantis","queen"][i%6]});rig.pose(.016);rigs.append(rig)
 for frame in 40:
  var start=Time.get_ticks_usec()
  for rig in rigs:build_3d(rig.appendage_batch)
  var split=Time.get_ticks_usec()
  for rig in rigs:build_2d(rig.appendage_batch)
  var end=Time.get_ticks_usec()
  if frame>=10:slow.append((split-start)/1000.0);fast.append((end-split)/1000.0)
 for rig in rigs:
  var v2=build_2d(rig.appendage_batch);var v3=build_3d(rig.appendage_batch)
  for i in v2.size():max_error=maxf(max_error,v2[i].distance_to(Vector2(v3[i].x,v3[i].y)))
 var batch=rigs[0].appendage_batch;var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=build_2d(batch);arrays[Mesh.ARRAY_TEX_UV]=batch.uv
 var indices=PackedInt32Array()
 for triangle in batch.polygons:indices.append_array(triangle)
 arrays[Mesh.ARRAY_INDEX]=indices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
 var format=mesh.surface_get_format(0);var vertices2d=build_2d(rigs[0].appendage_batch);mesh.surface_update_vertex_region(0,0,vertices2d.to_byte_array())
 var report={"original_build_64_ms":stats(slow),"native_packed2d_build_64_ms":stats(fast),"max_vertex_error":max_error,"format_2d":(format&Mesh.ARRAY_FLAG_USE_2D_VERTICES)!=0,"vertex_bytes":vertices2d.to_byte_array().size(),"vertex_count":vertices2d.size(),"scope":"CPU transform/build only, not rendered output; all 64 rigs frozen. 2D mesh creates vertex format from PackedVector2Array, never writes 8-byte stride into old 3D mesh."}
 print("RIG_VERTEX_MODES ",JSON.stringify(report));FileAccess.open("res://artifacts/rig-vertex-modes.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit()
