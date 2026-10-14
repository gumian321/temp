extends RefCounted
## Deform the existing transparent artwork, keeping its UVs and mounted root.
## Cosmetic only: poses never feed targeting, projectile origins or collisions.
const Ink=preload("res://scripts/blue_ink.gd")
const COLS=8
const ROWS=8
const WINGS=["sonic","cloak","drone_unit","repair_drone","scrap_drone"]
const SACS=["cannon","flak","nuke","flame","rocket","emp","blackhole","mine","mine_spawner","fuel","pack"]
const JAWS=["shotgun","gatling","sniper","tesla"]
var meshes:Dictionary={}
var used:Dictionary={}
static var indices=PackedInt32Array()

func begin_frame():
	end_frame();used.clear()
func end_frame():
	for key in meshes.keys():
		if not used.has(key):meshes.erase(key)

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

func paint(canvas:CanvasItem,key:String,texture:Texture2D,at:Vector2,bounds:Vector2,angle:float,variant:String,clock:float,pulse:float=0.0,tint:Color=Color.WHITE,seed:float=0.0,activity:float=0.0):
	if texture==null:return
	used[key]=true
	var extent=Ink.fitted_size(texture,bounds)
	var source=texture
	var region=Rect2(Vector2.ZERO,texture.get_size())
	if texture is AtlasTexture:
		source=texture.atlas;region=texture.region
	var vertices=PackedVector3Array();var uvs=PackedVector2Array()
	for row in range(ROWS+1):
		for col in range(COLS+1):
			var uv=Vector2(float(col)/COLS,float(row)/ROWS)
			var point=deform(uv,variant,clock,pulse,seed,activity)*extent
			vertices.append(Vector3(point.x,point.y,0))
			uvs.append((region.position+Vector2.ONE*0.5+uv*(region.size-Vector2.ONE))/source.get_size())
	if indices.is_empty():
		for row in ROWS:
			for col in COLS:
				var a=row*(COLS+1)+col;var b=a+COLS+1
				indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	if not meshes.has(key):meshes[key]=ArrayMesh.new()
	var mesh:ArrayMesh=meshes[key];mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	canvas.draw_set_transform(at,angle)
	canvas.draw_mesh(mesh,source,Transform2D.IDENTITY,tint)
	canvas.draw_set_transform(Vector2.ZERO)
