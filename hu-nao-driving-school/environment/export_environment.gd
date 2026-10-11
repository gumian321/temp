extends SceneTree
## Developer utility: exact procedural geometry exported for DCC preview.
## Run: godot --headless --path . --script environment/export_environment.gd
## Shader materials receive PBR approximations; render-engine lighting is not exported.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script = load("res://environment/SchoolCorner.gd")
	if not script:
		push_error("Environment script failed to load")
		quit(1)
		return
	var environment = script.new()
	environment.name = "SchoolCorner"
	root.add_child(environment)
	await process_frame
	print("ENVIRONMENT_BUILT: ", environment.get_child_count(), " visual nodes")
	var converted: Dictionary = {}
	for child in environment.get_children():
		if child is MeshInstance3D:
			var original = child.material_override
			if original is ShaderMaterial:
				if not converted.has(original):
					var replacement := StandardMaterial3D.new()
					replacement.cull_mode = BaseMaterial3D.CULL_DISABLED
					replacement.roughness = 0.94
					var leaf_color = original.get_shader_parameter("leaf_color")
					if leaf_color != null:
						replacement.albedo_color = leaf_color
						replacement.vertex_color_use_as_albedo = true
					elif str(original.shader.resource_path).contains("asphalt"):
						replacement.albedo_color = Color(0.303,0.350,0.340)
					else:
						replacement.albedo_color = Color(0.827,0.802,0.681)
					converted[original] = replacement
				child.material_override = converted[original]
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_scene(environment,state)
	if err != OK:
		push_error("GLTF append failed: "+str(err))
		quit(1)
		return
	err = document.write_to_filesystem(state,"res://environment/SchoolCorner.glb")
	print("ENVIRONMENT_EXPORT_RESULT: ",err)
	quit(0 if err == OK else 1)
