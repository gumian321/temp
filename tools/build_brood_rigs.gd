extends SceneTree
## Rebuild the six editable Polygon2D + Skeleton2D scene assets.
const Brood=preload("res://scripts/brood_theme.gd")
const Rig=preload("res://scripts/soft_insect_rig.gd")
func _initialize():call_deferred("build")
func own_children(node:Node,scene_root:Node):
	for child in node.get_children():child.owner=scene_root;own_children(child,scene_root)
func build():
	DirAccess.make_dir_recursive_absolute(Brood.ROOT+"rigs")
	for species in Brood.SPECIES:
		var actor={"uid":1,"kind":"AISwarmingUnit","position":Vector2.ZERO,"angle":-PI/2,"hp":100.0,"max_hp":100.0,"radius":50.0,"brood_species":species}
		var rig=Rig.new();rig.name=species.to_pascal_case();root.add_child(rig);rig.setup(actor)
		rig.position=Vector2(320,300);rig.scale=Vector2.ONE*150;rig.preview_species=species
		own_children(rig,rig)
		var scene=PackedScene.new()
		if scene.pack(rig)!=OK:quit(1);return
		if ResourceSaver.save(scene,Brood.ROOT+"rigs/"+species+".tscn")!=OK:quit(1);return
		rig.free()
	print("Saved six editable insect meshes and skeletons.")
	quit(0)
