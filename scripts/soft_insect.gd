extends RefCounted
## Lightweight damped bone lattice. It affects the mesh, never combat collisions.
const Brood = preload("res://scripts/brood_theme.gd")
const Anatomy = preload("res://scripts/insect_anatomy.gd")
const REST = [
	Vector2(-0.68,-0.82), Vector2(0,-0.82), Vector2(0.68,-0.82),
	Vector2(-0.68,-0.4), Vector2(0,-0.4), Vector2(0.68,-0.4),
	Vector2(-0.68,0), Vector2(0,0), Vector2(0.68,0),
	Vector2(-0.68,0.42), Vector2(0,0.42), Vector2(0.68,0.42),
	Vector2(-0.68,0.82), Vector2(0,0.82), Vector2(0.68,0.82)
]
const ELASTICITY = {"grub":Vector2(72,6.5),"beetle":Vector2(160,10),"moth":Vector2(85,7),"sac":Vector2(52,6),"mantis":Vector2(115,8),"queen":Vector2(58,7)}
const MAX_OFFSET = 0.30
static var rests:Dictionary={}

static func rest_points(species:String)->PackedVector2Array:
	if rests.has(species):return rests[species]
	var border:PackedVector2Array=Anatomy.definition(species).body
	var low=1.0;var high=0.0
	for p in border:low=minf(low,p.y);high=maxf(high,p.y)
	var result=PackedVector2Array()
	for row in range(5):
		var y=lerpf(low+.045,high-.05,row/4.0)
		var left=.5;var right=.5
		for i in border.size():
			var a:Vector2=border[i];var b:Vector2=border[(i+1)%border.size()]
			if (a.y<=y and b.y>y) or (b.y<=y and a.y>y):
				var x=lerpf(a.x,b.x,(y-a.y)/(b.y-a.y))
				left=minf(left,x);right=maxf(right,x)
		for x in [lerpf(.5,left,.76),.5,lerpf(.5,right,.76)]:result.append(Vector2(x*2-1,y*2-1))
	rests[species]=result
	return result

static func prepare(e: Dictionary):
	if e.has("soft_body") and e.soft_body.has("rest"): return
	var offset = PackedVector2Array()
	var velocity = PackedVector2Array()
	offset.resize(REST.size()); velocity.resize(REST.size())
	var art:AtlasTexture=Brood.texture("enemy_"+Brood.species(e))
	var aspect=art.atlas.get_size()/maxf(art.atlas.get_width(),art.atlas.get_height())
	e.soft_body = {"offset":offset,"velocity":velocity,"rest":rest_points(Brood.species(e)),"aspect":aspect,"clock":0.0,"pose_clock":0.0,"flash":0.0,"hits":0,"peak":0.0,"hold":0.0,"shock":0.0,"recoil":Vector2.ZERO,"recoil_velocity":Vector2.ZERO,"lean":0.0,"lean_velocity":0.0,"direction":Vector2.RIGHT,"contact":Vector2.ZERO,"cue":0,"cue_age":10.0,"cue_strength":0.0,"cue_cooldown":0.0,"family":"impact"}

static func surface_point(state:Dictionary,point:Vector2,push:Vector2,species:String)->Vector2:
	var border:PackedVector2Array=Anatomy.definition(species).body
	if Geometry2D.is_point_in_polygon((point/state.aspect+Vector2.ONE)*.5,border):point-=push*.5
	var closest=Vector2.ZERO;var distance=INF
	for i in border.size():
		var a=(border[i]*2-Vector2.ONE)*state.aspect
		var b=(border[(i+1)%border.size()]*2-Vector2.ONE)*state.aspect
		var p=Geometry2D.get_closest_point_to_segment(point,a,b)
		if p.distance_squared_to(point)<distance:closest=p;distance=p.distance_squared_to(point)
	return closest

static func impact(e: Dictionary, point: Vector2, direction: Vector2, damage: float, family:String=""):
	if not Brood.eligible(e) or damage <= 0: return
	prepare(e)
	var state: Dictionary = e.soft_body
	var angle = float(e.get("angle",0)) + PI/2
	var push = direction.rotated(-angle).normalized()
	if push.is_zero_approx(): push = Vector2.DOWN
	var local = ((point-Vector2(e.position)).rotated(-angle)/(Brood.extent(e)*0.5)).limit_length(0.95)
	# Hitscan and beams can report their emitter as impact point. Put impact on the facing rim.
	if point.distance_to(e.position) > Brood.extent(e): local = -push * 0.75
	if family.is_empty():family=str(e.get("last_fx","impact"))
	var species=Brood.species(e)
	local=surface_point(state,local,push,species)
	var weight=float({"gatling":.78,"drone":.72,"flame":.4,"blackhole":.5,"shield":.35,"cannon":1.2,"rail":1.35,"nuke":1.45,"mine":1.15}.get(family,1.0))
	var strength=clampf(.6+sqrt(damage/maxf(1,float(e.get("max_hp",100))))*1.5,.65,1.65)*weight
	if species=="beetle":strength*=.78
	var uv_push=push/state.aspect
	var hit_uv=local/state.aspect
	var fresh=float(state.cue_cooldown)<=0
	state.hits += 1
	# Group body impulses too, not only sparks: sustained fire must permit recovery.
	if not fresh:return
	for i in state.rest.size():
		var falloff=exp(-Vector2(state.rest[i]).distance_squared_to(hit_uv)*10)
		# An immediate dent registers on the first rendered frame, before the spring advances.
		if fresh:state.offset[i]=(Vector2(state.offset[i])+uv_push*.16*strength*falloff).limit_length(MAX_OFFSET)
		state.velocity[i]=(Vector2(state.velocity[i])+uv_push*strength*(.10+falloff)*4.5).limit_length(5.5)
		state.peak=maxf(state.peak,Vector2(state.offset[i]).length())
	if fresh:
		state.contact=local;state.direction=push;state.family=family
		state.cue+=1;state.cue_age=0.0;state.cue_strength=strength
		state.cue_cooldown=.28 if family in ["flame","blackhole"] else .20
		state.hold=0 if family in ["flame","blackhole","shield"] else clampf(.035+strength*.014,.04,.06)
		state.shock=maxf(state.shock,minf(1.35,strength))
		state.recoil=(Vector2(state.recoil)+push*.16*strength).limit_length(.23)
		state.recoil_velocity=(Vector2(state.recoil_velocity)+push*strength*1.4).limit_length(3)
		var torque=clampf(local.cross(push)*.45+push.x*.065,-.18,.18)*strength
		state.lean=clampf(state.lean+torque,-.25,.25);state.lean_velocity+=torque*6
		state.flash=.07
	constrain_lattice(state)

static func constrain_lattice(state:Dictionary):
	# Keep neighboring rows/columns ordered under concentrated automatic fire.
	# Deep dents can compress the skin, but may not flip its triangles inside out.
	for row in range(5):
		var middle=row*3+1
		var center:Vector2=state.rest[middle]+state.offset[middle]
		for side in [-1,1]:
			var i=middle+side
			var minimum=absf(state.rest[i].x-state.rest[middle].x)*.32
			var p:Vector2=state.rest[i]+state.offset[i]
			if (p.x-center.x)*side<minimum:
				state.offset[i].x=center.x+side*minimum-state.rest[i].x
				state.velocity[i].x*=.25
	for row in range(4):
		for column in range(3):
			var i=row*3+column;var j=i+3
			var minimum=(state.rest[j].y-state.rest[i].y)*.38
			var gap=(state.rest[j].y+state.offset[j].y)-(state.rest[i].y+state.offset[i].y)
			if gap<minimum:
				var correction=(minimum-gap)*.5
				state.offset[i].y-=correction;state.offset[j].y+=correction
				state.velocity[i].y*=.4;state.velocity[j].y*=.4
	for i in state.offset.size():state.offset[i]=Vector2(state.offset[i]).limit_length(MAX_OFFSET)

static func step(e: Dictionary, dt: float):
	if not Brood.eligible(e): return
	prepare(e)
	var state: Dictionary = e.soft_body
	var remaining = clampf(dt,0,0.15)
	var elastic: Vector2 = ELASTICITY[Brood.species(e)]
	while remaining > 0.00001:
		var h = minf(remaining, 1.0/120.0)
		var held=float(state.hold)>0
		var previous: PackedVector2Array = state.offset.duplicate()
		for i in state.rest.size():
			if held:continue
			var coupling = Vector2.ZERO
			for j in [i-3,i+3]:
				if j>=0 and j<REST.size(): coupling += previous[j]-previous[i]
			var velocity: Vector2 = (state.velocity[i]+(-previous[i]*elastic.x+coupling*22.0)*h)*exp(-elastic.y*h)
			var offset: Vector2 = previous[i]+velocity*h
			if offset.length()>MAX_OFFSET: offset=offset.limit_length(MAX_OFFSET); velocity*=0.4
			state.velocity[i]=velocity
			state.offset[i]=offset
			state.peak=maxf(float(state.peak),offset.length())
		constrain_lattice(state)
		state.clock+=h
		state.pose_clock+=h*(.12 if held else 1.0)
		state.hold=maxf(0,state.hold-h)
		state.cue_age+=h;state.cue_cooldown=maxf(0,state.cue_cooldown-h)
		if not held:
			state.shock*=exp(-11*h)
			state.recoil_velocity=(state.recoil_velocity-state.recoil*180*h)*exp(-13*h)
			state.recoil=(state.recoil+state.recoil_velocity*h).limit_length(.23)
			state.lean_velocity=(state.lean_velocity-state.lean*200*h)*exp(-14*h)
			state.lean=clampf(state.lean+state.lean_velocity*h,-.25,.25)
		state.flash=maxf(0,float(state.flash)-h)
		remaining-=h
