class_name SchoolCorner
extends Node3D
## Visual-only handcrafted school court. One Godot unit = one metre.
## Ground is y=0. The hero-car display space is centred on the origin.
## Own lighting and camera in the parent scene. No collision, controls or network.

var mats: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _bevel_cache: Dictionary = {}
var _foliage_cache: Array[ArrayMesh] = []

func _ready() -> void:
	if get_child_count() > 0:
		return
	build()

func build() -> void:
	rng.seed = 52971
	_make_materials()
	_make_ground()
	_make_architecture()
	_make_planting()
	_make_props()

func _mat(key: String, color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[key] = m
	return m

func _make_materials() -> void:
	_mat("plaster", Color("e1d9bd"))
	_mat("plaster_light", Color("e7d9b7"))
	_mat("plaster_inset", Color("cfc9ae"))
	_mat("stone", Color("b0b1a1"))
	_mat("stone_light", Color("c6c6b1"))
	_mat("teal", Color("375e56"))
	_mat("teal_light", Color("517568"))
	_mat("tile", Color("697b70"))
	_mat("tile_light", Color("859386"))
	_mat("metal", Color("3e514d"), 0.48, 0.35)
	_mat("wood", Color("a18a60"))
	_mat("wood_light", Color("bfaa79"))
	_mat("bark", Color("87724f"))
	_mat("bark_light", Color("aa8e62"))
	_mat("soil", Color("666248"))
	_mat("paint", Color("e5dbb6"))
	_mat("orange", Color("c96f28"), 0.72)
	_mat("rubber", Color("4c5752"))
	_mat("white", Color("efead0"))
	_mat("brass", Color("bdaf75"), 0.5, 0.45)
	_mat("lamp", Color("fff1bf"), 0.6)
	mats.lamp.emission_enabled = true
	mats.lamp.emission = Color("eedda8")
	mats.lamp.emission_energy_multiplier = 0.2
	var asphalt := ShaderMaterial.new()
	asphalt.shader = load("res://environment/asphalt.gdshader")
	mats["asphalt"] = asphalt
	var plaster := ShaderMaterial.new()
	plaster.shader = load("res://environment/plaster.gdshader")
	mats["plaster_textured"] = plaster
	var inset_plaster := plaster.duplicate() as ShaderMaterial
	inset_plaster.set_shader_parameter("plaster_color",Color("d7c5a3"))
	mats["plaster"] = inset_plaster
	for i in range(6):
		var leaf := ShaderMaterial.new()
		leaf.shader = load("res://environment/foliage.gdshader")
		leaf.set_shader_parameter("leaf_color", [Color("315e40"), Color("447547"), Color("608b50"), Color("739456"), Color("527949"), Color("809e60")][i])
		mats["leaf%d" % i] = leaf

func _mesh_instance(mesh: Mesh, pos: Vector3, material: Material, node_name: String = "Detail") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	add_child(node)
	return node

func _box(pos: Vector3, size: Vector3, key: String, bevel: float = 0.025, node_name: String = "ArchitecturalDetail") -> MeshInstance3D:
	var mesh: Mesh
	if bevel <= 0.001:
		var b := BoxMesh.new()
		b.size = size
		mesh = b
	else:
		var cache_key := str(size) + ":" + str(bevel)
		if not _bevel_cache.has(cache_key):
			_bevel_cache[cache_key] = _rounded_box(size, bevel)
		mesh = _bevel_cache[cache_key]
	return _mesh_instance(mesh, pos, mats[key], node_name)

func _rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	var h := size * 0.5
	var r := minf(radius, minf(h.x, minf(h.y, h.z)) * 0.85)
	var core := h - Vector3.ONE * r
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var faces := [
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP, h.x, h.z, h.y],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP, h.x, h.z, h.y],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, h.y, h.x, h.z],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, h.y, h.x, h.z],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP, h.z, h.x, h.y],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP, h.z, h.x, h.y]
	]
	for f in faces:
		var hu: float = f[4]
		var hv: float = f[5]
		var us: Array[float] = [-hu, -hu+r*0.3, -hu+r*0.7, -hu+r, hu-r, hu-r*0.7, hu-r*0.3, hu]
		var vs: Array[float] = [-hv, -hv+r*0.3, -hv+r*0.7, -hv+r, hv-r, hv-r*0.7, hv-r*0.3, hv]
		var base := vertices.size()
		for v in vs:
			for u in us:
				var p: Vector3 = f[0]*f[3] + f[1]*u + f[2]*v
				var close := p.clamp(-core, core)
				var normal := (p-close).normalized()
				vertices.append(close+normal*r)
				normals.append(normal)
		for y in range(7):
			for x in range(7):
				var a := base+y*8+x
				indices.append_array([a,a+8,a+1,a+1,a+8,a+9])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _cylinder(pos: Vector3, bottom: float, top: float, height: float, key: String, segments: int = 32) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	return _mesh_instance(mesh, pos, mats[key])

func _between(start: Vector3, finish: Vector3, r0: float, r1: float, key: String, segments: int = 16) -> MeshInstance3D:
	var n := _cylinder((start+finish)*0.5, r0, r1, start.distance_to(finish), key, segments)
	var direction := (finish-start).normalized()
	var axis := Vector3.UP.cross(direction)
	if axis.length() > 0.0001:
		n.quaternion = Quaternion(axis.normalized(), acos(clampf(Vector3.UP.dot(direction), -1.0, 1.0)))
	return n

func _sign(texture_path: String, position_: Vector3, size: Vector2, key: String = "white") -> MeshInstance3D:
	var plane := QuadMesh.new()
	plane.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(texture_path)
	m.roughness = 0.88
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return _mesh_instance(plane, position_, m, "SchoolSign")

func _make_ground() -> void:
	_box(Vector3(0,-0.10,1), Vector3(48,0.2,48), "asphalt", 0, "AsphaltCourt")
	# Warm stone pedestrian apron against the compound wall
	_box(Vector3(0,0.065,-5.5), Vector3(20.4,0.13,2.6), "stone", 0.04, "Sidewalk")
	for i in range(34):
		_box(Vector3(-10.05+i*0.61,0.12,-4.24), Vector3(0.59,0.22,0.27), "stone_light", 0.025, "RoundedKerbstone")
		# Real paving joints break up the sidewalk without heavy texture noise.
		if i % 2 == 0:
			_box(Vector3(-9.8+i*0.61,0.136,-5.47), Vector3(0.012,0.008,2.15), "stone", 0)
	# Hero training bay: enough margin around a real 4.5-m sedan
	for x in [-2.35,2.35]:
		_box(Vector3(x,0.0015,0.3),Vector3(0.095,0.0025,6.5),"paint",0)
	_box(Vector3(0,0.0015,-2.95),Vector3(4.79,0.0025,0.095),"paint",0)
	for x in [-1.65,1.65]:
		_box(Vector3(x,0.0018,3.53),Vector3(1.35,0.0025,0.095),"paint",0)
	# Dashed approach lane and a delicate amber edge line
	for i in range(5):
		_box(Vector3(-5.3,0.0015,0.25+i*2.8),Vector3(0.08,0.0025,1.3),"paint",0)
	for i in range(5):
		_box(Vector3(5.0,0.0015,-0.6+i*2.8),Vector3(0.08,0.0025,1.3),"paint",0)
	var stencil := _sign("res://environment/assets/road-stencil.png",Vector3(0,0.003,5.2),Vector2(2.55,0.59))
	stencil.rotation_degrees.x = -90
	# drainage slots are tucked beside the curb, away from the car
	_box(Vector3(3.7,0.016,-3.85),Vector3(1.8,0.02,0.26),"metal",0.015)
	for i in range(16):
		_box(Vector3(2.9+i*0.105,0.032,-3.85),Vector3(0.045,0.018,0.23),"stone",0.008)

func _make_architecture() -> void:
	# Layered, gently bevelled warm plaster wall with recessed fields.
	_box(Vector3(-3.7,1.32,-6.33),Vector3(12.5,2.46,0.48),"plaster_textured",0.06,"WarmPlasterWall")
	_box(Vector3(-3.7,0.26,-6.0),Vector3(12.6,0.36,0.63),"stone",0.025)
	_box(Vector3(-3.7,0.47,-5.985),Vector3(12.68,0.065,0.67),"stone_light",0.015)
	_box(Vector3(-3.7,2.49,-6.3),Vector3(12.66,0.09,0.62),"plaster_light",0.025)
	_box(Vector3(-3.7,2.62,-6.3),Vector3(12.82,0.17,0.78),"tile",0.04)
	_box(Vector3(-3.7,2.73,-6.3),Vector3(12.9,0.065,0.86),"tile_light",0.025)
	for x in [-8.5,-5.75,-3.0,-0.25]:
		_box(Vector3(x,1.39,-6.04),Vector3(2.44,1.49,0.04),"plaster_inset",0.018)
		_box(Vector3(x,1.41,-6.005),Vector3(2.3,1.35,0.045),"plaster",0.018)
		_box(Vector3(x,0.73,-5.98),Vector3(2.45,0.08,0.08),"plaster_light",0.015)
	for x in [-9.98,-7.14,-4.39,-1.64,2.49]:
		_box(Vector3(x,1.43,-6.23),Vector3(0.22,2.48,0.69),"plaster_light",0.025)
		_box(Vector3(x,0.30,-6.14),Vector3(0.36,0.44,0.73),"stone_light",0.035)
	# School sign is an enamel plaque above a shallow raised surround.
	_box(Vector3(-3.05,3.03,-6.32),Vector3(8.36,1.25,0.42),"teal",0.06,"MonumentSignSurround")
	_box(Vector3(-3.05,3.03,-6.085),Vector3(8.13,1.04,0.065),"brass",0.025)
	_sign("res://environment/assets/school-sign.png",Vector3(-3.05,3.03,-6.045),Vector2(7.99,0.985))
	# Simple roof coping with individual ceramic ridge seams and sloping edge.
	_box(Vector3(-3.05,3.74,-6.27),Vector3(8.8,0.13,0.91),"tile",0.04)
	_box(Vector3(-3.05,3.84,-6.29),Vector3(8.86,0.085,0.59),"tile_light",0.035)
	for i in range(31):
		_box(Vector3(-7.3+i*0.284,3.817,-6.27),Vector3(0.026,0.056,0.84),"tile_light",0.012)
	# Open entry portal at the right, with recessed timber screen beyond it.
	for x in [2.93,8.45]:
		_box(Vector3(x,1.72,-6.24),Vector3(0.62,3.25,0.68),"plaster_textured",0.055,"GatePier")
		_box(Vector3(x,0.37,-6.17),Vector3(0.77,0.62,0.87),"stone_light",0.045)
		_box(Vector3(x,3.38,-6.26),Vector3(0.84,0.12,0.98),"plaster_light",0.03)
		_box(Vector3(x,3.53,-6.24),Vector3(0.88,0.21,1.07),"tile",0.035)
	_box(Vector3(5.7,3.46,-6.28),Vector3(6.32,0.32,0.65),"teal",0.035)
	_box(Vector3(5.7,3.69,-6.27),Vector3(6.62,0.16,1.19),"tile",0.035)
	_box(Vector3(5.7,3.81,-6.27),Vector3(6.74,0.10,0.89),"tile_light",0.035)
	for i in range(23):
		_box(Vector3(2.5+i*0.29,3.79,-6.27),Vector3(0.034,0.07,1.13),"tile_light",0.012)
	# An open pocket in the entry preserves believable depth rather than filling it with a box.
	for x in [3.40,3.65,3.9,7.45,7.7,7.95]:
		_box(Vector3(x,1.23,-6.38),Vector3(0.11,2.08,0.14),"wood",0.018,"GateTimberSlat")
	for x in [3.65,7.7]:
		for y in [0.39,2.12]:
			_box(Vector3(x,y,-6.46),Vector3(0.86,0.07,0.12),"metal",0.01)
	# Subtle warm lanterns on piers
	for x in [2.93,8.45]:
		_box(Vector3(x,2.30,-5.81),Vector3(0.27,0.43,0.22),"metal",0.025)
		_box(Vector3(x,2.30,-5.678),Vector3(0.185,0.30,0.02),"lamp",0.006)
		_box(Vector3(x,2.55,-5.79),Vector3(0.36,0.07,0.32),"tile",0.02)
		for h in [-0.12,0.12]:
			_box(Vector3(x+h,2.30,-5.66),Vector3(0.025,0.34,0.04),"metal",0.006)
	# The compound continues behind the gate with an understated garden and timber screen.
	_box(Vector3(5.45,0.17,-9.35),Vector3(7.3,0.26,4.1),"stone",0.03)
	for i in range(24):
		_box(Vector3(2.5+i*0.265,1.1,-10.9),Vector3(0.09,1.8,0.10),"wood",0.017)
	for y in [0.40,1.92]:
		_box(Vector3(5.55,y,-10.96),Vector3(6.55,0.09,0.12),"teal",0.015)
	# Left return, low enough to leave an airy silhouette.
	_box(Vector3(-10.05,0.82,-2.7),Vector3(0.5,1.45,7.4),"plaster_textured",0.045)
	_box(Vector3(-10.05,1.57,-2.7),Vector3(0.75,0.13,7.6),"tile",0.03)
	_box(Vector3(-10.05,0.23,-2.7),Vector3(0.64,0.29,7.5),"stone",0.02)

func _leaf_blob(seed_index: int) -> ArrayMesh:
	if seed_index < _foliage_cache.size():
		return _foliage_cache[seed_index]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var longitude := 24
	var latitude := 16
	var phase := float(seed_index) * 1.73
	for j in range(latitude+1):
		var t := float(j)/float(latitude)*PI
		for i in range(longitude+1):
			var p := float(i)/float(longitude)*TAU
			var radial := Vector3(sin(t)*cos(p),cos(t),sin(t)*sin(p))
			var lobes := 1.0 + 0.075*sin(p*5.0+phase)*sin(t)*sin(t) + 0.043*sin(t*7.0+p*3.0+phase) + 0.025*cos(p*9.0-t*5.0)
			vertices.append(radial*lobes)
			# Soft coherent volume lighting, lifted slightly to avoid round plastic lobes.
			normals.append((radial + Vector3.UP*0.21).normalized())
			var tone := 0.74 + 0.26*(radial.y*0.5+0.5)
			colors.append(Color(tone,tone,tone,1))
	for j in range(latitude):
		for i in range(longitude):
			var a := j*(longitude+1)+i
			indices.append_array([a,a+longitude+1,a+1,a+1,a+longitude+1,a+longitude+2])
	# Pointed leaf blades break the spherical silhouette and articulate each spray.
	# They share this mesh/material, so there is no per-leaf scene-node overhead.
	for leaf_index in range(72):
		var fy := -0.75 + 1.73 * float(leaf_index) / 71.0
		var fa := float(leaf_index) * 2.399963 + phase + sin(float(leaf_index)*27.13)*0.18
		var fr := sqrt(maxf(0.001, 1.0-fy*fy))
		var radial := Vector3(cos(fa)*fr,fy,sin(fa)*fr)
		var leaf_normal := (radial*0.76+Vector3.UP*0.44).normalized()
		var along := radial-leaf_normal*radial.dot(leaf_normal)
		if along.length() < 0.1:
			along = Vector3(cos(fa),0,sin(fa))
		along = along.normalized().rotated(leaf_normal,sin(float(leaf_index)*13.1+phase)*0.7)
		var side := leaf_normal.cross(along).normalized()
		var leaf_root := radial*0.92
		var middle := leaf_root+along*0.12+radial*0.06
		var tip := leaf_root+along*0.27+radial*0.10
		var points: Array[Vector3] = [leaf_root,middle-side*0.093,tip,middle+side*0.093,middle+leaf_normal*0.022]
		var base := vertices.size()
		var leaf_tone := 0.90 + 0.09*(sin(fa*2.1)*0.5+0.5)
		for k in range(5):
			vertices.append(points[k])
			normals.append((radial+Vector3.UP*0.30).normalized())
			var tone := leaf_tone + (0.035 if k==4 else 0.0)
			colors.append(Color(tone,tone,tone,1))
		for face in [[0,1,4],[1,2,4],[2,3,4],[3,0,4]]:
			var a: int = face[0]
			var b: int = face[1]
			var c: int = face[2]
			if (points[b]-points[a]).cross(points[c]-points[a]).dot(leaf_normal)>0.0:
				indices.append_array([base+a,base+c,base+b])
			else:
				indices.append_array([base+a,base+b,base+c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_foliage_cache.append(result)
	return result

func _foliage(position_: Vector3, size: Vector3, tone: int = 1) -> void:
	var mesh := _leaf_blob(rng.randi_range(0,5))
	var n := _mesh_instance(mesh,position_,mats["leaf%d" % tone],"SculptedLeafCluster")
	n.scale = size
	n.rotation.y = rng.randf_range(-PI,PI)

func _tree(base: Vector3, scale_: float, variation: int = 0) -> void:
	var s := scale_
	var trunk_top := base + Vector3(0.13*s,2.9*s,-0.02*s)
	_between(base,base+Vector3(-0.06*s,1.3*s,0),0.17*s,0.115*s,"bark",20)
	_between(base+Vector3(-0.06*s,1.3*s,0),trunk_top,0.115*s,0.060*s,"bark",20)
	for i in range(6):
		var a := float(i)/6.0*TAU+0.3
		var root_end := base+Vector3(cos(a)*0.48*s,0.028,sin(a)*0.48*s)
		_between(root_end,base+Vector3(0,0.23*s,0),0.045*s,0.10*s,"bark",12)
	for i in range(7):
		var a := float(i)/7.0*TAU+0.6
		var anchor := base+Vector3(0,1.55*s+float(i%3)*0.29*s,0)
		var tip := base+Vector3(cos(a)*1.22*s,3.24*s+float(i%3)*0.20*s,sin(a)*1.10*s)
		_between(anchor,tip,0.067*s,0.026*s,"bark",14)
	# The silhouette is built from thirty overlapping shaped leaf sprays, never a giant polygon sphere.
	for layer in range(3):
		var count: int = [11,10,7][layer]
		var radius: float = [1.27,1.10,0.63][layer]*s
		for j in range(count):
			var angle := float(j)/float(count)*TAU+float(layer)*0.77
			var pos := base+Vector3(cos(angle)*radius, (3.00+float(layer)*0.62+rng.randf_range(-0.12,0.12))*s,sin(angle)*radius*0.82)
			var width := rng.randf_range(0.61,0.87)*s
			var tone := clampi(variation+mini(layer,1)+rng.randi_range(0,1),0,5)
			_foliage(pos,Vector3(width,rng.randf_range(0.45,0.64)*s,width*0.85),tone)
	# Finer separated sprays along the crown's perimeter lend a leafy edge.
	for j in range(19):
		var angle := float(j)/19.0*TAU
		var pos := base+Vector3(cos(angle)*1.91*s, (3.1+0.16*sin(angle*3.0))*s,sin(angle)*1.64*s)
		_foliage(pos,Vector3(0.26,0.21,0.3)*s,clampi(variation+rng.randi_range(0,2),0,5))

func _planter(center: Vector3, size: Vector2) -> void:
	_box(center+Vector3(0,0.23,0),Vector3(size.x,0.36,size.y),"stone",0.045,"GardenPlanter")
	_box(center+Vector3(0,0.425,0),Vector3(size.x+0.08,0.095,size.y+0.08),"stone_light",0.025)
	_box(center+Vector3(0,0.478,0),Vector3(size.x-0.16,0.01,size.y-0.16),"soil",0)

func _shrubs(center: Vector3, length_: float, scale_: float = 1.0) -> void:
	var count := int(length_/0.34)
	for i in range(count):
		var x := -length_*0.5+float(i)*0.34
		_foliage(center+Vector3(x,rng.randf_range(0.1,0.35)*scale_,rng.randf_range(-0.15,0.15)),Vector3(0.41,0.32+rng.randf()*0.15,0.39)*scale_,rng.randi_range(1,2))
	# Fine upright leaf sprays and sparse grass blades accent the planter edges.
	for i in range(count*2):
		var x := rng.randf_range(-length_*0.5,length_*0.5)
		var pos := center+Vector3(x,-0.22,-0.2+rng.randf()*0.4)
		for j in range(3):
			_between(pos,pos+Vector3(rng.randf_range(-0.13,0.13),rng.randf_range(0.24,0.4),rng.randf_range(-0.13,0.13)),0.018,0.004,"teal_light",6)

func _make_planting() -> void:
	for i in range(6):
		_leaf_blob(i)
	# Garden beds frame the school signage; nothing obscures the hero car.
	_planter(Vector3(-5.10,0.13,-5.08),Vector2(7.75,0.86))
	_shrubs(Vector3(-5.1,0.73,-5.08),7.15,0.85)
	_planter(Vector3(8.93,0.13,-4.97),Vector2(1.15,1.1))
	_shrubs(Vector3(8.93,0.72,-4.97),0.6,0.9)
	_tree(Vector3(-8.58,0.02,-8.58),1.35,1)
	_tree(Vector3(9.02,0.02,-8.1),1.44,0)
	_tree(Vector3(5.68,0.22,-10.04),0.92,1)
	# Far-left canopy breaks the return wall edge, with a sculpted garden bed.
	_planter(Vector3(-8.4,0.02,-0.78),Vector2(1.7,1.85))
	_tree(Vector3(-8.4,0.46,-0.78),1.13,0)
	for offset in [Vector3(-0.47,0,0.44),Vector3(0.4,0,0.4),Vector3(0.44,0,-0.37)]:
		_foliage(Vector3(-8.4,0.79,-0.78)+offset,Vector3(0.43,0.35,0.42),2)
	# Smaller grasses and natural stones anchor planting to the curb.
	for i in range(8):
		var pos := Vector3(-9.3+rng.randf()*1.7,0.15,-3.5+rng.randf()*1.25)
		var stone := SphereMesh.new()
		stone.radius = 1.0
		stone.height = 2.0
		stone.radial_segments = 18
		stone.rings = 10
		var n := _mesh_instance(stone,pos,mats["stone"],"GardenStone")
		n.scale = Vector3(rng.randf_range(0.13,0.23),0.10,rng.randf_range(0.10,0.2))

func _cone(position_: Vector3, spin: float) -> void:
	var start_count := get_child_count()
	_box(position_+Vector3(0,0.035,0),Vector3(0.48,0.07,0.48),"rubber",0.038,"ConeBevelledFoot")
	_box(position_+Vector3(0,0.075,0),Vector3(0.36,0.035,0.36),"orange",0.025)
	_cylinder(position_+Vector3(0,0.327,0),0.172,0.045,0.50,"orange",40)
	_cylinder(position_+Vector3(0,0.283,0),0.132,0.111,0.08,"white",40)
	_cylinder(position_+Vector3(0,0.435,0),0.094,0.074,0.08,"white",40)
	_cylinder(position_+Vector3(0,0.585,0),0.044,0.035,0.026,"orange",32)
	_cylinder(position_+Vector3(0,0.60,0),0.019,0.019,0.008,"rubber",24)
	for i in range(start_count,get_child_count()):
		get_child(i).rotation.y = spin

func _make_props() -> void:
	# Slatted waiting bench and legs, with individually rounded edges.
	var bench := Vector3(-5.9,0,-3.55)
	for x in [-0.94,0.94]:
		_box(bench+Vector3(x,0.27,0),Vector3(0.09,0.52,0.41),"metal",0.022)
		_box(bench+Vector3(x,0.03,0),Vector3(0.26,0.045,0.55),"metal",0.018)
	for z in [-0.20,-0.065,0.07,0.205]:
		_box(bench+Vector3(0,0.53,z),Vector3(2.22,0.065,0.105),"wood_light",0.021)
	for y in [0.79,0.95]:
		_box(bench+Vector3(0,y,-0.22),Vector3(2.22,0.12,0.065),"wood",0.019)
	for x in [-0.94,0.94]:
		_box(bench+Vector3(x,0.77,-0.255),Vector3(0.045,0.52,0.045),"metal",0.01)
	# A framed practice-zone plaque, carefully kept outside the car silhouette.
	_box(Vector3(1.35,1.56,-5.49),Vector3(0.98,1.23,0.095),"teal",0.035,"PracticePlaqueFrame")
	_sign("res://environment/assets/practice-sign.png",Vector3(1.35,1.56,-5.435),Vector2(0.9,1.12))
	for x in [1.05,1.65]:
		_box(Vector3(x,0.64,-5.52),Vector3(0.055,1.04,0.08),"metal",0.015)
	_cone(Vector3(3.16,0,-2.47),0.14)
	_cone(Vector3(3.12,0,2.3),-0.1)
	_cone(Vector3(-3.17,0,-2.58),0.23)
	# Rounded protective entry bollards with collars.
	for x in [4.37,6.72]:
		_cylinder(Vector3(x,0.52,-5.0),0.074,0.074,0.83,"teal",32)
		_cylinder(Vector3(x,0.12,-5.0),0.115,0.115,0.09,"stone_light",32)
		_cylinder(Vector3(x,0.79,-5.0),0.077,0.077,0.05,"brass",32)
		var cap := SphereMesh.new()
		cap.radius = 0.078
		cap.height = 0.156
		cap.radial_segments = 24
		cap.rings = 12
		_mesh_instance(cap,Vector3(x,0.94,-5.0),mats["teal"])
	# Small wall-mounted service box gives the entrance functional detail.
	_box(Vector3(8.45,1.38,-5.815),Vector3(0.20,0.33,0.16),"metal",0.025)
	_box(Vector3(8.45,1.42,-5.724),Vector3(0.12,0.07,0.012),"teal_light",0.008)
