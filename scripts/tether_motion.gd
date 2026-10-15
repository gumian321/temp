extends RefCounted
## Simulation-clock elasticity shared by spider silk and weapon tendrils.
## Released curves contain only value snapshots, never actor/source references.
const SEGMENTS=24
const MAX_RELEASED=32

static func emitter_reaction(state:Dictionary)->Dictionary:
	var axis=Vector2(state.start).direction_to(state.end)
	var force=float(state.tension)
	var sway=float(state.bend)*.55+float(state.struggle)*2.2
	if state.has("release_age"):
		var age=float(state.release_age)
		# Continuous at detachment, then overshoots backward before settling.
		var envelope=exp(-age*3.2)*(1-smoothstep(.38,float(state.release_duration),age))
		force*=cos(age*16)*envelope
		sway=(sway*cos(age*16)+sin(age*19)*4.5*float(state.tension))*envelope
	return {"offset":(axis*force*14.0+axis.orthogonal()*sway).limit_length(17),"twist":clampf(sway*.045,-.22,.22),"axis":axis,"stretch":force*.32}

static func combine_reactions(motions:Array)->Dictionary:
	var offset=Vector2.ZERO;var twist=0.0;var axis=Vector2.ZERO;var stretch=0.0
	for motion in motions:
		var reaction=emitter_reaction(motion)
		offset+=reaction.offset;twist+=reaction.twist
		axis+=reaction.axis*absf(reaction.stretch);stretch+=reaction.stretch
	return {"offset":offset.limit_length(18),"twist":clampf(twist,-.25,.25),"axis":axis.normalized(),"stretch":clampf(stretch/maxi(1,motions.size()),-.24,.36)}

static func create(start:Vector2,end:Vector2,seed:int=0)->Dictionary:
	return {"start":start,"end":end,"age":0.0,"phase":float(seed%17)*.73,"tension":0.0,"bend":0.0,"velocity":0.0,"struggle":0.0}

static func step(state:Dictionary,start:Vector2,end:Vector2,power:float,struggle:float,dt:float):
	if dt<=0:return
	var h_total=minf(dt,.15)
	var axis=start.direction_to(end)
	var drift=((end-Vector2(state.end))-(start-Vector2(state.start))).dot(axis.orthogonal())/maxf(dt,.001)
	state.start=start;state.end=end;state.struggle=struggle
	var remaining=h_total
	while remaining>.00001:
		var h=minf(remaining,1.0/120)
		state.age+=h
		state.tension=lerpf(state.tension,clampf(power,0,1),1-exp(-20*h))
		var target=clampf(-drift*.035,-12,12)+struggle*5.0
		state.velocity=(state.velocity+(target-state.bend)*220*h)*exp(-9*h)
		state.bend=clampf(state.bend+state.velocity*h,-20,20)
		remaining-=h

static func points(state:Dictionary)->PackedVector2Array:
	if state.has("released_points"):
		var result:PackedVector2Array=state.released_points.duplicate()
		var age=float(state.release_age)
		var u=clampf(age/float(state.release_duration),0,1)
		var retract=u*u*(3-2*u)
		var start:Vector2=state.start
		var source_shift=Vector2(state.get("release_origin",start))-start
		var emitter=Vector2(state.get("emitter_offset",Vector2.ZERO))
		source_shift+=emitter-Vector2(state.get("release_emitter",Vector2.ZERO))*(1-retract)
		var normal=Vector2(state.start).direction_to(state.end).orthogonal()
		for i in result.size():
			var t=float(i)/SEGMENTS
			# Free tip snaps sideways, reverses, then shrinks back into the emitter.
			var whip=sin(age*22-t*2.5)*sin(minf(age/.07,1)*PI*.5)*exp(-age*4.5)
			result[i]=start+(result[i]-start)*(1-retract)+normal*whip*t*minf(42,Vector2(state.start).distance_to(state.end)*.22)*(1-retract)+source_shift*(1-t*(1-retract))
		result[0]=Vector2(state.get("release_origin",start))+emitter
		return result
	var result=PackedVector2Array()
	var start:Vector2=state.start;var end:Vector2=state.end
	start+=Vector2(state.get("emitter_offset",Vector2.ZERO))
	var normal=start.direction_to(end).orthogonal()
	var sag=minf(32,start.distance_to(end)*.14)*(1-float(state.tension)*.94)
	for i in range(SEGMENTS+1):
		var t=float(i)/SEGMENTS
		var wave=sin(t*PI)
		var ripple=sin(state.age*23-t*11+state.phase)*(0.4+absf(float(state.struggle))*1.8)*state.tension
		result.append(start.lerp(end,t)+normal*wave*(sag+state.bend*sin(t*PI*2)+ripple))
	result[0]=start;result[SEGMENTS]=end
	return result

static func release(state:Dictionary,kind:String,friendly:bool=true)->Dictionary:
	var snapshot=state.duplicate(true)
	snapshot.released_points=points(state)
	snapshot.release_emitter=Vector2(state.get("emitter_offset",Vector2.ZERO))
	snapshot.release_age=0.0;snapshot.release_duration=.76 if kind=="silk" else .70
	snapshot.kind=kind;snapshot.friendly=friendly
	return snapshot

static func advance_released(released:Array,dt:float):
	if dt<=0:return
	for item in released.duplicate():
		item.release_age+=dt
		if item.release_age>=item.release_duration:released.erase(item)

static func append_release(released:Array,state:Dictionary,kind:String,friendly:bool=true):
	if released.size()>=MAX_RELEASED:released.pop_front()
	released.append(release(state,kind,friendly))

static func alpha(state:Dictionary)->float:
	if not state.has("release_age"):return 1.0
	return 1.0-smoothstep(.12,float(state.release_duration),float(state.release_age))
