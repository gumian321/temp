extends Node3D
const Rules = preload("res://game/rules.gd")
var car: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var school: Node3D
var mirror: Node3D
var toy: Node3D
var plane: MeshInstance3D
var view_mode := 0
var low := false
var glance := false
var comedy: Node3D
var font = preload("res://assets/fonts/chinese.otf")

func _ready() -> void:
 car = Node3D.new()
 car.name = "Santana"
 add_child(car)
 var imported = load("res://car/Santana_Refined.glb").instantiate()
 car.add_child(imported)
 var styler = load("res://main.gd").new()
 styler._style_car(imported)
 styler.free()
 _paint(imported)
 print("CAR_BATCH ", preload("res://game/batch.gd").merge(imported, true))
 _dress_car()
 comedy=preload("res://game/comedy.gd").new()
 car.add_child(comedy)
 school = load("res://environment/environment_scene.tscn").instantiate()
 school.position = Vector3(0, -.025, -27)
 add_child(school)
 print("SCHOOL_BATCH ", preload("res://game/batch.gd").merge(school))
 _box(self, Vector3(0, -.16, 0), Vector3(82, .25, 82), Color("606e70"))
 # Practice-lot boundary and lane dashes use shared MultiMesh geometry.
 var marks: Array[Transform3D] = []
 for i in range(-7, 8):
  for side in [-1, 1]:
   marks.append(Transform3D(Basis(), Vector3(i * 5, .008, side * 33)))
   marks.append(Transform3D(Basis(Vector3.UP, PI / 2), Vector3(side * 33, .008, i * 5)))
 var dash := BoxMesh.new()
 dash.size = Vector3(2.0, .015, .12)
 _multi(dash, _mat(Color("eee2bc")), marks)
 for pos in Rules.OBSTACLES:
  _box(self, Vector3(pos.x, .22, pos.y), Vector3(2.8, .44, 2.8), Color("e8b64d"))
  for i in [-1, 1]:
   var cone := CylinderMesh.new()
   cone.bottom_radius = .32
   cone.top_radius = .06
   cone.height = .8
   cone.radial_segments = 12
   _mesh(self, cone, Vector3(pos.x + i * .85, .8, pos.y), _mat(Color("ed6d40")))
 for side in [-1, 1]:
  _box(self, Vector3(side * 40, .45, 0), Vector3(.6, .9, 81), Color("a6bcb0"))
  _box(self, Vector3(0, .45, side * 40), Vector3(80, .9, .6), Color("a6bcb0"))
 var env := Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 var sky_mat := ProceduralSkyMaterial.new()
 sky_mat.sky_top_color = Color("79aebd")
 sky_mat.sky_horizon_color = Color("dedfca")
 sky_mat.ground_bottom_color = Color("6e8075")
 sky.sky_material = sky_mat
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("c5d5de")
 env.ambient_light_energy = .4
 env.tonemap_mode = Environment.TONE_MAPPER_ACES
 var world := WorldEnvironment.new()
 world.environment = env
 add_child(world)
 sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48, -34, 0)
 sun.light_color = Color("ffe7cf")
 sun.light_energy = .75
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 45
 add_child(sun)
 var fill := OmniLight3D.new()
 fill.position = Vector3(0, 1.3, 0)
 fill.omni_range = 2.0
 fill.light_energy = .6
 car.add_child(fill)
 camera = Camera3D.new()
 camera.near = .025
 camera.far = 140
 camera.current = true
 add_child(camera)

func _paint(node: Node) -> void:
 if node is MeshInstance3D:
  for i in range(node.mesh.get_surface_count()):
   var mat = node.get_active_material(i)
   if mat and "carpaint" in mat.resource_name.to_lower():
    var paint := ShaderMaterial.new()
    paint.shader = preload("res://game/livery.gdshader")
    node.set_surface_override_material(i, paint)
 for child in node.get_children(): _paint(child)

func _mat(color: Color, metal: float = 0.0) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.roughness = .48
 material.metallic = metal
 return material

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.mesh = mesh
 node.material_override = material
 node.position = pos
 parent.add_child(node)
 return node

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = size
 return _mesh(parent, mesh, pos, _mat(color))

func _label(parent: Node3D, caption: String, pos: Vector3, size: int, pixel: float, color: Color) -> Label3D:
 var label := Label3D.new()
 label.text = caption
 label.font = font
 label.font_size = size
 label.pixel_size = pixel
 label.position = pos
 label.modulate = color
 label.outline_size = 0
 parent.add_child(label)
 return label

func _dress_car() -> void:
 for side in [-1, 1]:
  var badge := _label(car, "胡闹驾校", Vector3(side * .846, .86, -.12), 64, .0021, Color("8f191d"))
  badge.rotation.y = side * PI / 2
  var number := _label(car, "训练用车  ·  1985", Vector3(side * .85, .69, -.12), 32, .0019, Color("fff2cf"))
  number.rotation.y = side * PI / 2
  # Front fender round auxiliary mirrors, including two-segment metal brackets.
  _box(car, Vector3(side * .79, 1.01, 1.28), Vector3(.045, .34, .045), Color("555e5e"))
  _box(car, Vector3(side * .84, 1.17, 1.28), Vector3(.14, .035, .035), Color("555e5e"))
  var disc := CylinderMesh.new()
  disc.top_radius = .105
  disc.bottom_radius = .105
  disc.height = .034
  disc.radial_segments = 32
  var mount := Node3D.new()
  mount.position = Vector3(side * .91, 1.18, 1.28)
  car.add_child(mount)
  if side == 1: mirror = mount
  var housing := _mesh(mount, disc, Vector3.ZERO, _mat(Color("323c3c"), .6))
  housing.rotation.x = PI / 2
  var glass := CylinderMesh.new()
  glass.top_radius = .089
  glass.bottom_radius = .089
  glass.height = .003
  glass.radial_segments = 32
  var face := _mesh(mount, glass, Vector3(0, 0, -.021), _mat(Color("8caab7"), .78))
  face.rotation.x = PI / 2
 for front in [-1, 1]:
  var height := .485 if front == 1 else .833
  var depth := 2.27 if front == 1 else -2.21
  _box(car, Vector3(0, height, depth), Vector3(.44, .16, .022), Color("f4c634"))
  var plate := _label(car, "虚构·学 008", Vector3(0, height, depth + front * .016), 40, .00145, Color("202e30"))
  if front == -1: plate.rotation.y = PI
 _box(car, Vector3(-.39, .20, .62), Vector3(.14, .05, .17), Color("de5b39"))
 _label(car, "副刹", Vector3(-.39, .24, .62), 30, .001, Color("fff0d0")).rotation.x = -PI / 2
 toy = Node3D.new()
 toy.position = Vector3(0, 1, .4)
 car.add_child(toy)
 var can := CylinderMesh.new()
 can.height = .19
 can.top_radius = .055
 can.bottom_radius = .055
 _mesh(toy, can, Vector3.ZERO, _mat(Color("e97937")))
 _label(toy, "汽水", Vector3(0, 0, -.057), 24, .0015, Color.WHITE).rotation.y = PI
 toy.visible = false
 var paper := SurfaceTool.new()
 paper.begin(Mesh.PRIMITIVE_TRIANGLES)
 for p in [Vector3(0,0,.22), Vector3(-.18,0,-.13), Vector3(0,.055,-.1), Vector3(0,0,.22), Vector3(0,.055,-.1), Vector3(.18,0,-.13)]: paper.add_vertex(p)
 paper.generate_normals()
 var paper_mat := _mat(Color("f5ead0"))
 paper_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 plane = _mesh(car, paper.commit(), Vector3(0,1.05,.45), paper_mat)
 plane.visible = false

func _multi(mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
 var multi := MultiMesh.new()
 multi.transform_format = MultiMesh.TRANSFORM_3D
 multi.mesh = mesh
 multi.instance_count = transforms.size()
 for i in range(transforms.size()): multi.set_instance_transform(i, transforms[i])
 var node := MultiMeshInstance3D.new()
 node.multimesh = multi
 node.material_override = material
 add_child(node)

func set_low(enabled: bool) -> void:
 low = enabled
 sun.shadow_enabled = not low
 get_viewport().scaling_3d_scale = .65 if low else 1.0
 get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X

func update_view(s: Dictionary, role: String, dt: float) -> void:
 car.position = Vector3(s.x, 0, s.z)
 car.rotation.y = s.yaw
 var in_room: bool = s.phase == "room"
 var local_pos := Vector3(.36 if role == "driver" else -.36, 1.18, -.08)
 var target_pos: Vector3
 var look: Vector3
 if in_room:
  target_pos = car.to_global(Vector3(5.2, 2.6, 7.3))
  look = car.to_global(Vector3(0, .8, 0))
  camera.fov = 42
 elif view_mode == 0:
  target_pos = car.to_global(local_pos)
  look = car.to_global(local_pos + Vector3(0, -.04, 5))
  camera.fov = 76
  if glance: look=car.to_global(Vector3(0,.99,.45))
 else:
  target_pos = car.to_global(Vector3(0, 3.5, -7.5))
  look = car.to_global(Vector3(0, .8, 2))
  camera.fov = 62
 camera.h_offset = -1.8 if in_room else 0.0
 camera.position = target_pos if view_mode == 0 else camera.position.lerp(target_pos, minf(1, dt * 12))
 camera.look_at(look)
 mirror.rotation.z = .65 if s.effects[2] > 0 else 0.0
 toy.visible = s.prank == 0 or s.effects[0] > 0
 plane.visible = s.prank == 1 or s.effects[1] > 0
 plane.position = Vector3(.15,1.12,.72) if s.effects[1] > 0 else Vector3(0,1.02,.35)
 plane.rotation.y = sin(Time.get_ticks_msec() * .009) * .2
 toy.rotation.z = sin(Time.get_ticks_msec() * .025) * .2
 toy.position.y = 1.02 + sin(Time.get_ticks_msec() * .02) * .025
