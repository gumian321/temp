extends RefCounted
## Lightweight damped bone lattice. It affects the mesh, never combat collisions.
const Brood = preload("res://scripts/brood_theme.gd")
const Anatomy = preload("res://scripts/insect_anatomy.gd")
const Knockback = preload("res://scripts/knockback.gd")
const PUSH_SOFTNESS = {"grub":1.0,"beetle":0.42,"moth":0.85,"sac":1.1,"mantis":0.65,"queen":0.7}
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
	e.soft_body = {"offset":offset,"velocity":velocity,"lattice_active":false,"rest":rest_points(Brood.species(e)),"aspect":aspect,"clock":0.0,"pose_clock":0.0,"flash":0.0,"hits":0,"peak":0.0,"hold":0.0,"shock":0.0,"recoil":Vector2.ZERO,"recoil_velocity":Vector2.ZERO,"lean":0.0,"lean_velocity":0.0,"direction":Vector2.RIGHT,"contact":Vector2.ZERO,"cue":0,"cue_age":10.0,"cue_strength":0.0,"cue_cooldown":0.0,"family":"impact"}

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
	state.lattice_active=true
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

static func begin_push(e:Dictionary):
	if not Brood.eligible(e):return
	var velocity=Vector2(e.get("knockback_velocity",Vector2.ZERO))
	if velocity.length()<Knockback.STOP_SPEED:return
	prepare(e)
	var state:Dictionary=e.soft_body
	var power=clampf(velocity.length()/Knockback.MAX_SPEED,0.0,1.0)
	state.push_direction=velocity.normalized()
	state.push_softness=PUSH_SOFTNESS[Brood.species(e)]
	if state.has("push_strain") and float(state.push_age)<0.14:return
	var side=-1.0 if int(e.get("uid",0))%2==0 else 1.0
	# The struck side compresses immediately. Momentum then stretches it out;
	# a separate underdamped bend keeps the abdomen and appendages wobbling.
	state.push_strain=clampf(float(state.get("push_strain",0))-0.22*power,-0.24,0.26)
	state.push_strain_velocity=0.0
	state.push_bend=clampf(float(state.get("push_bend",0))+side*0.14*power,-0.22,0.22)
	state.push_bend_velocity=side*0.9*power
	state.push_age=0.0

static func step_push(e:Dictionary,state:Dictionary,h:float,elapsed:float):
	if not state.has("push_strain"):return
	var speed=Vector2(e.get("knockback_velocity",Vector2.ZERO)).length()*exp(-Knockback.DRAG*elapsed)
	var target=clampf(speed/Knockback.MAX_SPEED,0,1)*0.24
	state.push_strain_velocity=(state.push_strain_velocity+(target-state.push_strain)*190*h)*exp(-7*h)
	state.push_strain=clampf(state.push_strain+state.push_strain_velocity*h,-0.24,0.28)
	state.push_bend_velocity=(state.push_bend_velocity-state.push_bend*135*h)*exp(-5.5*h)
	state.push_bend=clampf(state.push_bend+state.push_bend_velocity*h,-0.22,0.22)
	state.push_age+=h
	if speed<Knockback.STOP_SPEED and absf(state.push_strain)<0.001 and absf(state.push_strain_velocity)<0.01 and absf(state.push_bend)<0.001 and absf(state.push_bend_velocity)<0.01:
		for key in ["push_direction","push_softness","push_strain","push_strain_velocity","push_bend","push_bend_velocity","push_age"]:state.erase(key)

static func push_deform(state:Dictionary,point:Vector2,center:Vector2,softness:float,heading:float)->Vector2:
	if not state.has("push_strain"):return point
	var axis=Vector2(state.push_direction).rotated(-heading)
	var normal=axis.orthogonal()
	var delta=point-center
	var along=delta.dot(axis)
	var across=delta.dot(normal)
	var strain=float(state.push_strain)*float(state.push_softness)
	var bend=float(state.push_bend)*float(state.push_softness)
	var deformation=(axis*along*strain-normal*across*strain*0.45)*lerpf(0.55,1.0,softness)
	deformation+=normal*(sin(along*4.0-float(state.push_age)*10.0)*bend+along*bend*0.55)*softness
	return point+deformation.limit_length(0.24)

static func pull(e:Dictionary,direction:Vector2,speed:float,dt:float):
	if dt<=0 or speed<=0 or direction.is_zero_approx() or not Brood.eligible(e):return
	prepare(e)
	var state:Dictionary=e.soft_body
	if not state.has("pull_strain"):
		state.pull_direction=direction.normalized()
		state.pull_strain=0.0;state.pull_velocity=0.0;state.pull_bend=0.0
		state.pull_age=float(int(e.get("uid",0))%17)*0.37
		state.pull_softness=PUSH_SOFTNESS[Brood.species(e)]
	state.pull_target_direction=direction.normalized()
	state.pull_power=clampf(speed/200.0,0.0,1.0)
	# A short lease bridges callers before/after Soft.step without owning actors or sources.
	# Missing sources stop refreshing it, then the spring releases naturally.
	state.pull_left=minf(0.18,dt+0.06)

static func step_pull(state:Dictionary,h:float):
	if not state.has("pull_strain"):return
	state.pull_left=maxf(0,state.pull_left-h)
	var power=float(state.pull_power) if state.pull_left>0 else 0.0
	var angle=lerp_angle(Vector2(state.pull_direction).angle(),Vector2(state.pull_target_direction).angle(),1-exp(-14*h))
	state.pull_direction=Vector2.from_angle(angle)
	state.pull_velocity=(state.pull_velocity+(power*0.58-state.pull_strain)*125*h)*exp(-5.8*h)
	state.pull_strain=clampf(state.pull_strain+state.pull_velocity*h,-0.28,0.70)
	state.pull_age+=h
	# Opposing waves travel down the abdomen while tension is maintained.
	var bend=sin(state.pull_age*15)*power*0.20
	state.pull_bend=lerpf(state.pull_bend,bend,1-exp(-18*h))
	if power==0 and absf(state.pull_strain)<0.001 and absf(state.pull_velocity)<0.01 and absf(state.pull_bend)<0.001:
		for key in ["pull_direction","pull_target_direction","pull_strain","pull_velocity","pull_bend","pull_age","pull_softness","pull_power","pull_left"]:state.erase(key)

static func struggle(state:Dictionary,phase:float=0.0)->float:
	return sin(float(state.get("pull_age",0))*15+phase)*clampf(absf(float(state.get("pull_strain",0)))/0.58,0,1)*float(state.get("pull_softness",1))

static func pull_deform(state:Dictionary,point:Vector2,center:Vector2,softness:float,heading:float)->Vector2:
	if not state.has("pull_strain"):return point
	var axis=Vector2(state.pull_direction).rotated(-heading)
	var normal=axis.orthogonal()
	var delta=point-center
	var along=delta.dot(axis)
	var strain=float(state.pull_strain)*float(state.pull_softness)
	var deformation=(axis*along*strain-normal*delta.dot(normal)*strain*0.38)*lerpf(0.6,1.0,softness)
	# The leading edge reaches toward the tether, the rear lags and writhes against it.
	deformation+=normal*sin(along*4.5-state.pull_age*15)*absf(strain)*0.30*softness
	return point+deformation.limit_length(0.42)

static func constrain_lattice(state:Dictionary):
	var constrained=_constrained_arrays(state.rest,state.offset,state.velocity)
	state.offset=constrained[0];state.velocity=constrained[1]

static func _constrained_arrays(rest:PackedVector2Array,offsets:PackedVector2Array,velocities:PackedVector2Array)->Array:
	# Work on packed arrays directly, avoiding repeated dictionary lookups and
	# nested property write-back for every constraint assignment.
	for row in range(5):
		var middle=row*3+1
		var center:Vector2=rest[middle]+offsets[middle]
		for side in [-1,1]:
			var i=middle+side
			var minimum=absf(rest[i].x-rest[middle].x)*.32
			var p:Vector2=rest[i]+offsets[i]
			if (p.x-center.x)*side<minimum:
				offsets[i].x=center.x+side*minimum-rest[i].x
				velocities[i].x*=.25
	for row in range(4):
		for column in range(3):
			var i=row*3+column;var j=i+3
			var minimum=(rest[j].y-rest[i].y)*.38
			var gap=(rest[j].y+offsets[j].y)-(rest[i].y+offsets[i].y)
			if gap<minimum:
				var correction=(minimum-gap)*.5
				offsets[i].y-=correction;offsets[j].y+=correction
				velocities[i].y*=.4;velocities[j].y*=.4
	for i in offsets.size():offsets[i]=offsets[i].limit_length(MAX_OFFSET)
	return [offsets,velocities]

static func step(e: Dictionary, dt: float):
	if not Brood.eligible(e): return
	prepare(e)
	var state: Dictionary = e.soft_body
	var remaining = clampf(dt,0,0.15)
	var push_elapsed=0.0
	var elastic: Vector2 = ELASTICITY[Brood.species(e)]
	while remaining > 0.00001:
		var h = minf(remaining, 1.0/120.0)
		step_push(e,state,h,push_elapsed)
		step_pull(state,h)
		push_elapsed+=h
		var held=float(state.hold)>0
		# A newly prepared lattice is exactly at equilibrium. Only impact mutates
		# it, and wakes it before writing. Never truncate a decaying nonzero pose.
		if state.get("lattice_active",true):
			var previous:PackedVector2Array=state.offset.duplicate()
			var offsets:PackedVector2Array=state.offset
			var velocities:PackedVector2Array=state.velocity
			var rest:PackedVector2Array=state.rest
			var peak:float=state.peak
			if not held:
				var damping=exp(-elastic.y*h)
				for i in rest.size():
					var coupling=Vector2.ZERO
					if i>=3:coupling+=previous[i-3]-previous[i]
					if i+3<REST.size():coupling+=previous[i+3]-previous[i]
					var velocity:Vector2=(velocities[i]+(-previous[i]*elastic.x+coupling*22.0)*h)*damping
					var offset:Vector2=previous[i]+velocity*h
					if offset.length()>MAX_OFFSET:offset=offset.limit_length(MAX_OFFSET);velocity*=.4
					velocities[i]=velocity;offsets[i]=offset
					peak=maxf(peak,offset.length())
			var constrained=_constrained_arrays(rest,offsets,velocities)
			state.offset=constrained[0];state.velocity=constrained[1];state.peak=peak
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
