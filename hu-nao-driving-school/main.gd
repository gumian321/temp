extends Node3D

var camera: Camera3D
var current_view := 0
const VIEWS := [
 [Vector3(6.0,2.6,8.6), Vector3(0,.92,-.6), 27.5],
 [Vector3(1.78,.66,2.13), Vector3(.70,.32,1.37), 20.9],
 [Vector3(-.33,1.16,-.03), Vector3(.13,.87,.76), 52.2]
]

func _ready() -> void:
 var corner := load("res://environment/environment_scene.tscn") as PackedScene
 if corner: add_child(corner.instantiate())
 var car_scene := load("res://car/Santana_Refined.glb") as PackedScene
 if car_scene:
  var car := car_scene.instantiate()
  car.name = "Verified_Original_Santana_Refined"
  add_child(car)
  _style_car(car)
 _lighting()
 camera = Camera3D.new()
 camera.name = "Visual_Inspection_Camera"
 camera.near = .015
 camera.far = 180
 add_child(camera)
 camera.current = true
 set_view(0)
 _interface()
 if FileAccess.file_exists("res://verification/enable_capture.flag"):
  _capture_visual_evidence.call_deferred()
 print("SANTANA_VISUAL_READY: real imported geometry, visual-only, no gameplay/network")

func _style_car(node: Node) -> void:
 if node is MeshInstance3D:
  var mesh_node := node as MeshInstance3D
  for i in range(mesh_node.mesh.get_surface_count()):
   var source := mesh_node.get_active_material(i)
   if not source is StandardMaterial3D: continue
   var mat := source.duplicate() as StandardMaterial3D
   var name_lower := mat.resource_name.to_lower()
   if "carpaint" in name_lower:
    mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
    mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    mat.roughness = .38
    mat.metallic = .10
    mat.metallic_specular = .42
    mat.clearcoat_enabled = true
    mat.clearcoat = .32
    mat.clearcoat_roughness = .26
    mat.rim_enabled = true
    mat.rim = .12
    mat.rim_tint = .30
   elif "windowglass" in name_lower:
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color.a = .16
    mat.roughness = .20
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
   elif "tire" in name_lower:
    mat.albedo_color = Color(.25,.265,.275,1.0)
    mat.roughness = .76
    mat.metallic_specular = .24
   elif "clearglass" in name_lower:
    mat.albedo_color = Color(.66,.68,.63,1.0)
    mat.roughness = .34
    mat.metallic = .12
    mat.metallic_specular = .26
   elif "rim" == name_lower or "chrome" == name_lower:
    mat.roughness = .34
    mat.metallic = .68
    mat.metallic_specular = .42
   elif "ink" in name_lower:
    mat.emission_enabled = true
    mat.emission_texture = mat.albedo_texture
    mat.emission = Color(.35,.38,.34,1.0)
    mat.emission_energy_multiplier = .36
    mat.roughness = .88
   elif "grained_plastic" in name_lower:
    mat.roughness = .84
    mat.metallic_specular = .24
   mesh_node.set_surface_override_material(i,mat)
 for child in node.get_children(): _style_car(child)

func _lighting() -> void:
 var world := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 var sky_mat := ProceduralSkyMaterial.new()
 sky_mat.sky_top_color = Color("7dabb8")
 sky_mat.sky_horizon_color = Color("d3daca")
 sky_mat.ground_bottom_color = Color("596b63")
 sky_mat.ground_horizon_color = Color("d3daca")
 sky.sky_material = sky_mat
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("bacbd7")
 env.ambient_light_energy = .52
 env.tonemap_mode = Environment.TONE_MAPPER_ACES
 env.tonemap_exposure = 1.05
 env.tonemap_white = 3.5
 env.adjustment_enabled = true
 env.adjustment_saturation = 1.06
 env.ssao_enabled = true
 env.ssao_radius = .28
 env.ssao_intensity = .70
 env.ssao_power = 1.2
 env.ssao_light_affect = .15
 env.fog_enabled = true
 env.fog_light_color = Color("b8ced3")
 env.fog_light_energy = .35
 env.fog_density = .004
 env.fog_sky_affect = .2
 world.environment = env
 add_child(world)
 var sun := DirectionalLight3D.new()
 sun.name = "Warm_Soft_Afternoon"
 sun.light_color = Color("ffe6cb")
 sun.light_energy = 1.05
 sun.rotation_degrees = Vector3(-48,-34,0)
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 20
 sun.shadow_bias = .05
 sun.light_angular_distance = 7
 add_child(sun)
 var car_fill := OmniLight3D.new()
 car_fill.name = "Cool_Car_Detail_Fill"
 car_fill.position = Vector3(3.4,1.7,3.6)
 car_fill.light_color = Color("d7e5ec")
 car_fill.light_energy = .85
 car_fill.omni_range = 5.2
 car_fill.omni_attenuation = 1.1
 car_fill.shadow_enabled = false
 add_child(car_fill)
 var cabin_fill := OmniLight3D.new()
 cabin_fill.position = Vector3(-.25,1.18,.12)
 cabin_fill.light_color = Color("dce2d7")
 cabin_fill.light_energy = .68
 cabin_fill.omni_range = 1.35
 cabin_fill.shadow_enabled = false
 add_child(cabin_fill)

func set_view(index: int) -> void:
 current_view = index
 var view: Array = VIEWS[index]
 camera.position = view[0]
 camera.look_at(view[1], Vector3.UP)
 camera.fov = view[2]

func _unhandled_key_input(event: InputEvent) -> void:
 if not event.is_pressed(): return
 if event is InputEventKey:
  match event.keycode:
   KEY_1: set_view(0)
   KEY_2: set_view(1)
   KEY_3: set_view(2)
   KEY_F12: _capture_visual_evidence()

func _capture_visual_evidence() -> void:
 var records: Array = []
 var names := ["Exterior", "Tire", "Cockpit"]
 for index in range(3):
  set_view(index)
  await get_tree().create_timer(4.0).timeout
  await RenderingServer.frame_post_draw
  var frame := get_viewport().get_texture().get_image()
  var output := "res://previews/Santana_%s_Godot_Verified.png" % names[index]
  var result := frame.save_png(output)
  records.append({
   "view": names[index],
   "image": output,
   "image_size_pixels": [frame.get_width(), frame.get_height()],
   "save_error": result,
   "fps_sample": Engine.get_frames_per_second(),
   "rendered_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
   "rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
   "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
  })
 var report := {
  "engine": Engine.get_version_info(),
  "adapter": RenderingServer.get_video_adapter_name(),
  "adapter_vendor": RenderingServer.get_video_adapter_vendor(),
  "renderer": RenderingServer.get_current_rendering_method(),
  "display_server": DisplayServer.get_name(),
  "logical_viewport_size": str(get_viewport().get_visible_rect().size),
  "captured_at_system_time": Time.get_datetime_string_from_system(),
  "views": records,
  "note": "Actual graphical viewport captures. FPS is a single settled runtime sample per view on this cloud machine, not target-device performance."
 }
 var report_file := FileAccess.open("res://verification/godot_runtime_report.json", FileAccess.WRITE)
 if report_file:
  report_file.store_string(JSON.stringify(report, "  "))
 print("SANTANA_GRAPHICAL_VERIFICATION_COMPLETE: ", JSON.stringify(report))

func _interface() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 var panel := VBoxContainer.new()
 panel.position = Vector2(44,34)
 panel.add_theme_constant_override("separation",8)
 layer.add_child(panel)
 var title := Label.new()
 title.text = "胡闹驾校"
 title.add_theme_font_size_override("font_size",32)
 title.add_theme_color_override("font_shadow_color",Color(0.07,0.12,0.13,.75))
 title.add_theme_constant_override("shadow_offset_x",1)
 title.add_theme_constant_override("shadow_offset_y",2)
 title.add_theme_color_override("font_color",Color("f2edda"))
 panel.add_child(title)
 var subtitle := Label.new()
 subtitle.text = "桑塔纳 1985  /  美术样片"
 subtitle.add_theme_font_size_override("font_size",15)
 subtitle.add_theme_color_override("font_shadow_color",Color(0.07,0.12,0.13,.85))
 subtitle.add_theme_constant_override("shadow_offset_y",1)
 subtitle.add_theme_color_override("font_color",Color("d3dfd5"))
 panel.add_child(subtitle)
 var row := HBoxContainer.new()
 row.position = Vector2(44,924)
 row.add_theme_constant_override("separation",12)
 layer.add_child(row)
 var names := ["1  整车", "2  轮胎细节", "3  驾驶舱"]
 for i in range(3):
  var button := Button.new()
  button.text = names[i]
  button.custom_minimum_size = Vector2(145,42)
  button.pressed.connect(set_view.bind(i))
  row.add_child(button)
