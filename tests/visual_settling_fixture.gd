extends RefCounted
const Soft=preload("res://scripts/soft_insect.gd")
const VISUAL_KEYS=["offset","velocity","shock","recoil","recoil_velocity","lean","lean_velocity","lattice_active"]
const NUMERICAL_ERROR=1e-12

static func actor(species:String,radius:float=18.0)->Dictionary:
	var entity={"uid":17,"kind":"AISwarmingUnit","position":Vector2(80,60),"angle":.23,"hp":100.0,"max_hp":100.0,"radius":radius,"brood_species":species}
	Soft.prepare(entity);ghost(entity.soft_body)
	return entity

static func ghost(state:Dictionary):
	var tiny=Soft.VISUAL_SETTLING_THRESHOLD*.25
	for i in state.offset.size():
		state.offset[i]=Vector2(tiny if i%2==0 else -tiny,tiny*.5)
		state.velocity[i]=Vector2(-tiny*.75,tiny*.5)
	state.shock=tiny;state.recoil=Vector2(tiny,-tiny);state.recoil_velocity=Vector2(tiny*.5,-tiny*.75)
	state.lean=tiny*.5;state.lean_velocity=-tiny*.5;state.lattice_active=true
	state.hold=0.0;state.flash=0.0;state.cue_cooldown=0.0
	state.clock=1800.123;state.pose_clock=915.25;state.cue_age=8.0;state.peak=.25
	state.cue=3;state.hits=7;state.cue_strength=1.1;state.contact=Vector2(.2,.3);state.direction=Vector2.UP;state.family="cannon"

static func without_visuals(value):
	if value is Dictionary:
		if value.has("lattice_active") and value.has("constraint_margin_squared"):
			for key in VISUAL_KEYS:value.erase(key)
		for key in value:value[key]=without_visuals(value[key])
	elif value is Array:
		for i in value.size():value[i]=without_visuals(value[i])
	return value

static func difference(before,after)->float:
	if before is Vector2 and after is Vector2:return maxf(absf(before.x-after.x),absf(before.y-after.y))
	if before is PackedVector2Array and after is PackedVector2Array:
		if before.size()!=after.size():return INF
		var worst=0.0
		for i in before.size():worst=maxf(worst,difference(before[i],after[i]))
		return worst
	return absf(float(before)-float(after))

static func visual_difference(before:Dictionary,after:Dictionary)->float:
	var worst=0.0
	for key in VISUAL_KEYS:
		if key!="lattice_active":worst=maxf(worst,difference(before[key],after[key]))
	return worst
