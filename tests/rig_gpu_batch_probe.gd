extends Polygon2D
# Independent GPU rigid-skinning PoC. All vertices retain exactly one bone.
var pieces:Array=[]
var active=false
func collect(node:Node):
 if node is Polygon2D:pieces.append(node)
 for child in node.get_children():collect(child)
func setup(rig):
 collect(rig.limb_skeleton)
 var points=PackedVector2Array();var uvs=PackedVector2Array();var triangles:Array[PackedInt32Array]=[]
 var owners=[];var bone_nodes=[]
 for piece in pieces:
  var bone=piece.get_parent() as Bone2D
  assert(bone!=null)
  if not bone_nodes.has(bone):bone_nodes.append(bone)
  var owner_index=bone_nodes.find(bone)
  var transform=bone.get_skeleton_rest()*piece.transform;var first=points.size()
  for point in piece.polygon:points.append(transform*point);owners.append(owner_index)
  uvs.append_array(piece.uv)
  var indices=Geometry2D.triangulate_polygon(piece.polygon)
  for i in range(0,indices.size(),3):triangles.append(PackedInt32Array([first+indices[i],first+indices[i+1],first+indices[i+2]]))
 polygon=points;uv=uvs;polygons=triangles;texture=rig.art;material=rig.hit_material
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 # As child of the existing skeleton, source offset/tint are inherited exactly.
 rig.limb_skeleton.add_child(self);skeleton=NodePath("..")
 for i in bone_nodes.size():
  var weights=PackedFloat32Array();weights.resize(points.size())
  for v in points.size():weights[v]=1.0 if owners[v]==i else 0.0
  add_bone(rig.limb_skeleton.get_path_to(bone_nodes[i]),weights)
 active=true;set_enabled(true)
func set_enabled(enabled:bool):
 visible=enabled
 for piece in pieces:piece.visible=not enabled
