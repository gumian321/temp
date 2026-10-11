extends SceneTree

var mesh_count := 0
var triangle_count := 0
var paint_count := 0
var textured_material_count := 0

func _initialize() -> void:
 var packed := load("res://main.tscn") as PackedScene
 if packed == null:
  push_error("MAIN_SCENE_MISSING")
  quit(2)
  return
 var scene := packed.instantiate()
 root.add_child(scene)
 await process_frame
 var car := scene.get_node("Verified_Original_Santana_Refined")
 scan(car)
 for i in range(3):
  scene.set_view(i)
  if not scene.camera.current or scene.camera.near <= 0:
   push_error("INVALID_CAMERA_PRESET")
   quit(2)
   return
 print("VERIFIED_CAR_MESHES=",mesh_count)
 print("VERIFIED_CAR_TRIANGLES=",triangle_count)
 print("VERIFIED_TOON_PAINT_SURFACES=",paint_count)
 print("VERIFIED_TEXTURED_SURFACES=",textured_material_count)
 print("VERIFIED_CAMERA_PRESETS=3")
 print("NOTE=Headless scene validation only; no actual rendered viewport available")
 if mesh_count < 140 or paint_count < 6 or textured_material_count < 8:
  push_error("ASSET_VALIDATION_INCOMPLETE")
  quit(2)
  return
 quit(0)

func scan(node: Node) -> void:
 if node is MeshInstance3D:
  var mesh_node := node as MeshInstance3D
  mesh_count += 1
  for i in range(mesh_node.mesh.get_surface_count()):
   var arrays := mesh_node.mesh.surface_get_arrays(i)
   if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
    triangle_count += arrays[Mesh.ARRAY_INDEX].size() / 3
   var material := mesh_node.get_active_material(i)
   if material is StandardMaterial3D:
    if material.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON:paint_count += 1
    if material.albedo_texture != null:textured_material_count += 1
 for child in node.get_children():scan(child)
