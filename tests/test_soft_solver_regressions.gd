extends SceneTree
## Frozen 2e97923 lattice integrator is the functional oracle. No performance
## threshold, external checkout, or visual approximation is involved here.
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
class Reference extends RefCounted:
	const REST=Soft.REST
	const ELASTICITY=Soft.ELASTICITY
	const MAX_OFFSET=Soft.MAX_OFFSET
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
		Soft.prepare(e)
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

func _initialize():call_deferred("execute")
func actor(species:String)->Dictionary:
	return {"uid":1,"kind":"AISwarmingUnit","position":Vector2(50,80),"angle":.23,"hp":100.0,"max_hp":100.0,"radius":18.0,"brood_species":species}
func execute():
	var comparisons=0;var failures=[]
	for species in Brood.SPECIES:
		var a=actor(species);var b=actor(species)
		Soft.prepare(a);Soft.prepare(b)
		for frame in 300:
			if frame in [10,11,12,30,100,120,121,180,200,220]:
				var direction=Vector2.from_angle(frame*.17)
				var family=["cannon","flame","blackhole","shield","rail"][frame%5]
				Soft.impact(a,a.position+direction*10,direction,45,family)
				Soft.impact(b,b.position+direction*10,direction,45,family)
			var dt=[1.0/120,1.0/60,1.0/30,.001,.15,0.0,-.1][frame%7]
			Soft.step(a,dt);Reference.step(b,dt)
			for key in b.soft_body:
				comparisons+=1
				if a.soft_body[key]!=b.soft_body[key] and failures.size()<12:failures.append({"species":species,"frame":frame,"field":key})
	var report={"passed":failures.is_empty(),"exact_field_comparisons":comparisons,"failures":failures}
	FileAccess.open("res://artifacts/soft-solver-regressions-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
