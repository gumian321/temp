extends Polygon2D
## One GPU-skinned draw for the original rigid cutouts, in painter order.
## Every vertex has weight 1 on its original bone: legs remain rigid, not rubbery.
## The existing Skeleton2D owns all animation; there is no per-pose CPU vertex work.
var source:Skeleton2D
var rig:Node2D
var pieces:Array=[]
var bindings:Array=[]
var active=false
static var triangulations:Dictionary={}

func _collect(node:Node,ordered:Array):
	if node!=self and node is Polygon2D:ordered.append(node)
	for child in node.get_children():_collect(child,ordered)

func setup(owner_rig:Node2D)->bool:
	rig=owner_rig;source=rig.limb_skeleton
	var ordered:Array=[];_collect(source,ordered)
	if ordered.is_empty():return false
	var points=PackedVector2Array();var uvs=PackedVector2Array()
	var triangles:Array[PackedInt32Array]=[];var owners:Array=[];var bones:Array=[]
	for piece in ordered:
		# New independently styled/z-sorted cutouts conservatively retain the original
		# renderer. Validate everything before hiding any source artwork.
		var bone=piece.get_parent() as Bone2D
		if bone==null or piece.texture!=rig.art or piece.material!=rig.hit_material or piece.z_index!=0 or piece.color!=Color.WHITE or piece.modulate!=Color.WHITE or piece.self_modulate!=Color.WHITE or piece.invert_enabled or piece.antialiased or not piece.polygons.is_empty() or piece.offset!=Vector2.ZERO or not piece.visible:return false
		var ancestor:Node=bone
		while ancestor!=source:
			if not ancestor is Node2D or ancestor.z_index!=0 or ancestor.modulate!=Color.WHITE or ancestor.self_modulate!=Color.WHITE:return false
			ancestor=ancestor.get_parent()
			if ancestor==null:return false
		var polygon:PackedVector2Array=piece.polygon
		if not triangulations.has(polygon):
			if triangulations.size()>=2048:triangulations.clear()
			triangulations[polygon]=Geometry2D.triangulate_polygon(polygon)
		var indices:PackedInt32Array=triangulations[polygon]
		if indices.size()!=(piece.polygon.size()-2)*3 or piece.uv.size()!=piece.polygon.size():return false
		if not bones.has(bone):bones.append(bone)
		var owner_index=bones.find(bone);var first=points.size()
		var bind_transform=bone.get_skeleton_rest()*piece.transform
		for point in piece.polygon:
			points.append(bind_transform*point);owners.append(owner_index)
		uvs.append_array(piece.uv)
		for i in range(0,indices.size(),3):triangles.append(PackedInt32Array([first+indices[i],first+indices[i+1],first+indices[i+2]]))
		bindings.append({"node":piece,"bone":bone,"first":first,"bone_index":owner_index})
	polygon=points;uv=uvs;polygons=triangles;texture=rig.art;material=rig.hit_material
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Skeletal motion can extend past bind-pose bounds. Keep partially visible
	# feet and antennae without per-frame CPU bounds/vertex updates.
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(),true,Rect2(-16,-16,32,32))
	# Child of the existing skeleton: recoil offset, tint, parent scale and death
	# alpha inherit exactly as before. Bone paths are relative to this skeleton.
	skeleton=NodePath("..")
	for i in bones.size():
		var weights=PackedFloat32Array();weights.resize(points.size())
		for v in points.size():weights[v]=1.0 if owners[v]==i else 0.0
		add_bone(source.get_path_to(bones[i]),weights)
	pieces=ordered;active=true;set_enabled(true)
	return true

func set_enabled(enabled:bool):
	if not active:return
	visible=enabled
	for piece in pieces:piece.visible=not enabled
