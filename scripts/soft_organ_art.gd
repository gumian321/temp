extends RefCounted
## Deform the existing transparent artwork, keeping its UVs and mounted root.
## Cosmetic only: poses never feed targeting, projectile origins or collisions.
const Ink=preload("res://scripts/blue_ink.gd")
const COLS=8
const ROWS=8
const WINGS=["sonic","cloak","drone_unit","repair_drone","scrap_drone"]
const SACS=["cannon","flak","nuke","flame","rocket","emp","blackhole","mine","mine_spawner","fuel","pack","toxin","parasite"]
const JAWS=["shotgun","gatling","sniper","tesla","boneblade"]
var meshes:Dictionary={}
var used:Dictionary={}
var surfaces:Dictionary={}
# Dynamic VBO updates win in the native GL three-way benchmark. Retain the
# cached-surface rebuild switch for renderer diagnostics and compatibility checks.
var use_vertex_updates=true
var use_gpu=false
var gpu=preload("res://scripts/soft_organ_gpu.gd").new()
static var grid=PackedVector2Array()
static var grid_weight: Array[float]=[]
static var grid_tip: Array[float]=[]
static var grid_belly: Array[float]=[]
static var grid_wing: Array[float]=[]
static var indices=PackedInt32Array()

func begin_frame():
	end_frame();used.clear()
	gpu.begin_frame()
func end_frame():
	gpu.prune(used)
	for key in meshes.keys():
		if not used.has(key):
			meshes.erase(key);surfaces.erase(key)

static func deform(uv:Vector2,variant:String,clock:float,pulse_left:float,seed:float=0.0,activity:float=0.0)->Vector2:
	var p=uv-Vector2(0.5,0.5)
	if not is_finite(clock) or not is_finite(pulse_left):return p
	var phase=clock+seed*0.71
	var weight=clampf((0.5-p.y)/0.85,0,1)
	var age=(0.18-clampf(pulse_left,0,0.18))/0.18
	# Immediate compression on discharge, a softer overshoot, then full recovery.
	var kick=(1-age)*(1-age)*cos(age*PI*1.5) if pulse_left>0 else 0.0
	var breath=sin(phase*3.1)*0.035
	if variant in WINGS:
		var side=-1.0 if p.x<0 else 1.0
		var wing=smoothstep(0.07,0.40,absf(p.x))
		var flap=sin(phase*5.8+side*0.22-p.y*1.7)
		p.x*=1.0-wing*(0.24+0.22*flap)+wing*kick*0.15
		p.y+=wing*(0.10*flap+0.045*sin(phase*7.2-absf(p.x)*8)-kick*0.13)
		p.x+=wing*sin(phase*3.5-p.y*4)*0.025
	elif variant in SACS:
		var belly=sin(uv.y*PI)*weight
		var pumping=sin(phase*24)*0.045 if variant=="flame" and pulse_left>0 else 0.0
		p.x*=1+(breath+kick*0.32+pumping)*belly
		p.y+=(kick*0.17-breath*0.3)*weight
		p.x+=sin(phase*3.6-uv.y*5)*0.025*weight
	elif variant in JAWS:
		var tip=pow(weight,2)
		p.x*=1+(sin(phase*3.2)*0.055+kick*0.38)*tip
		p.y-=kick*0.20*tip
		p.x+=sin(phase*4.5-uv.y*4)*0.018*tip
	else:
		# Nests, shields and symbiotic chips breathe; work adds a local contraction.
		p.x*=1+(breath+kick*0.20+activity*sin(phase*8)*0.035)*weight
		p.y+=(breath*0.5+kick*0.09)*weight
	# The attachment row stays fixed; bending grows toward the free tip.
	p.x+=sin(phase*2.3)*0.016*weight
	return p

# Immutable grid terms and frame-wide oscillators are shared by all 81 points.
# deform() above remains the scalar reference used by geometry regression tests.
static func deformed_vertices(variant:String,clock:float,pulse:float,seed:float,activity:float,extent:Vector2)->PackedVector3Array:
	if grid.is_empty():
		for row in range(ROWS+1):
			for col in range(COLS+1):
				var uv=Vector2(float(col)/COLS,float(row)/ROWS)
				var p=uv-Vector2.ONE*.5
				var weight=clampf((.5-p.y)/.85,0,1)
				grid.append(uv)
				grid_weight.append(weight);grid_tip.append(pow(weight,2))
				grid_belly.append(sin(uv.y*PI)*weight);grid_wing.append(smoothstep(.07,.40,absf(p.x)))
	var vertices=PackedVector3Array();vertices.resize(grid.size())
	var phase=clock+seed*.71
	var age=(.18-clampf(pulse,0,.18))/.18
	var kick=(1-age)*(1-age)*cos(age*PI*1.5) if pulse>0 else 0.0
	var breath=sin(phase*3.1)*.035
	var bend=sin(phase*2.3)*.016
	var family=1 if variant in WINGS else (2 if variant in SACS else (3 if variant in JAWS else 0))
	var pumping=sin(phase*24)*.045 if variant=="flame" and pulse>0 else 0.0
	var jaw=sin(phase*3.2)*.055+kick*.38
	var contraction=breath+kick*.20+activity*sin(phase*8)*.035
	var valid=is_finite(clock) and is_finite(pulse)
	for i in grid.size():
		var uv:Vector2=grid[i];var p=uv-Vector2.ONE*.5
		var weight:float=grid_weight[i]
		if valid:
			match family:
				1:
					var wing:float=grid_wing[i]
					var flap=sin(phase*5.8+(-1.0 if p.x<0 else 1.0)*.22-p.y*1.7)
					p.x*=1.0-wing*(.24+.22*flap)+wing*kick*.15
					p.y+=wing*(.10*flap+.045*sin(phase*7.2-absf(p.x)*8)-kick*.13)
					p.x+=wing*sin(phase*3.5-p.y*4)*.025
				2:
					p.x*=1+(breath+kick*.32+pumping)*grid_belly[i]
					p.y+=(kick*.17-breath*.3)*weight
					p.x+=sin(phase*3.6-uv.y*5)*.025*weight
				3:
					var tip:float=grid_tip[i]
					p.x*=1+jaw*tip
					p.y-=kick*.20*tip
					p.x+=sin(phase*4.5-uv.y*4)*.018*tip
				_:
					p.x*=1+contraction*weight
					p.y+=(breath*.5+kick*.09)*weight
			p.x+=bend*weight
		p*=extent;vertices[i]=Vector3(p.x,p.y,0)
	return vertices

static func traction_point(point:Vector2,axis:Vector2,strain:float)->Vector2:
	if axis.is_zero_approx() or is_zero_approx(strain):return point
	axis=axis.normalized()
	strain=clampf(strain,-.24,.36)
	var normal=axis.orthogonal()
	# Stretch toward the tether, then squash on recoil, with the emission center fixed.
	return point+axis*point.dot(axis)*strain-normal*point.dot(normal)*strain*.42

func paint(canvas:CanvasItem,key:String,texture:Texture2D,at:Vector2,bounds:Vector2,angle:float,variant:String,clock:float,pulse:float=0.0,tint:Color=Color.WHITE,seed:float=0.0,activity:float=0.0,strain_axis:Vector2=Vector2.ZERO,strain:float=0.0):
	if texture==null:return
	used[key]=true
	if use_gpu and key.begins_with("player:"):
		var family=1 if variant in WINGS else (2 if variant in SACS else (3 if variant in JAWS else 0))
		var valid=is_finite(clock) and is_finite(pulse)
		meshes[key]=gpu.paint(canvas,key,texture,at,bounds,angle,family if valid else -1,clock if valid else 0.0,pulse if valid else 0.0,tint,seed,activity,variant=="flame",strain_axis,strain)
		return
	var extent=Ink.fitted_size(texture,bounds)
	var source=texture
	var region=Rect2(Vector2.ZERO,texture.get_size())
	if texture is AtlasTexture:
		source=texture.atlas;region=texture.region
	var vertices=deformed_vertices(variant,clock,pulse,seed,activity,extent)
	if not is_zero_approx(strain):
		for i in vertices.size():
			var p=traction_point(Vector2(vertices[i].x,vertices[i].y),strain_axis,strain)
			vertices[i]=Vector3(p.x,p.y,0)
	var rebuild=not surfaces.has(key)
	if not rebuild:
		var cached:Dictionary=surfaces[key]
		rebuild=cached.source!=source or cached.region!=region or cached.source_size!=source.get_size()
	if rebuild:
		var uvs=PackedVector2Array();uvs.resize((ROWS+1)*(COLS+1))
		for i in grid.size():uvs[i]=(region.position+Vector2.ONE*.5+grid[i]*(region.size-Vector2.ONE))/source.get_size()
		if indices.is_empty():
			for row in ROWS:
				for col in COLS:
					var a=row*(COLS+1)+col;var b=a+COLS+1
					indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
		surfaces[key]={"source":source,"region":region,"source_size":source.get_size(),"uvs":uvs}
	if rebuild or not use_vertex_updates:
		var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=surfaces[key].uvs;arrays[Mesh.ARRAY_INDEX]=indices
		if not meshes.has(key):meshes[key]=ArrayMesh.new()
		var mesh:ArrayMesh=meshes[key]
		mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE if use_vertex_updates else 0)
		# The vertex buffer is float xyz only. UV/index buffers never change during poses.
	else:
		meshes[key].surface_update_vertex_region(0,0,vertices.to_byte_array())
	# Updating a vertex buffer does not recompute its bounds. Keep culling conservative
	# across changing poses and mount sizes without rebuilding the surface.
	meshes[key].custom_aabb=AABB(Vector3(-extent.x,-extent.y,-1),Vector3(extent.x*2,extent.y*2,2))
	canvas.draw_set_transform(at,angle)
	canvas.draw_mesh(meshes[key],source,Transform2D.IDENTITY,tint)
	canvas.draw_set_transform(Vector2.ZERO)
