extends RefCounted
## Bake all triangles by material, retaining every original vertex/index and transform.
## Transparent surfaces remain separate so Godot can sort their individual bounds.
static func merge(root: Node3D, by_name: bool = false) -> Dictionary:
 var groups := {}
 var originals := []
 var triangles := 0
 for node in root.find_children("*", "MeshInstance3D", true, false):
  if not node.mesh: continue
  var transparent := false
  for i in range(node.mesh.get_surface_count()):
   var m = node.get_active_material(i)
   if m is BaseMaterial3D and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: transparent = true
  if transparent: continue
  originals.append(node)
  for i in range(node.mesh.get_surface_count()):
   var mat = node.get_active_material(i)
   var key := str(mat.get_instance_id()) if mat else "none"
   if by_name and mat:
    key = mat.resource_name
    if mat is ShaderMaterial: key = mat.shader.resource_path
   if not groups.has(key):
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_material(mat)
    groups[key] = surface
   var surface: SurfaceTool = groups[key]
   surface.append_from(node.mesh, i, root.global_transform.affine_inverse() * node.global_transform)
   var arrays: Array = node.mesh.surface_get_arrays(i)
   triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
 for surface in groups.values():
  var merged := MeshInstance3D.new()
  merged.mesh = surface.commit()
  root.add_child(merged)
 for node in originals:
  node.get_parent().remove_child(node)
  node.free()
 return {"meshes_before": originals.size(), "meshes_after": groups.size(), "triangles_retained": triangles}
