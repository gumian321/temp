extends SceneTree
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
var mismatches=[]
func _initialize():call_deferred("execute")
func actor(uid:int,species:String)->Dictionary:
	return {"uid":uid,"kind":"AISwarmingUnit","position":Vector2(50,80),"angle":.23,"hp":100.0,"max_hp":100.0,"radius":18.0,"brood_species":species}
func execute():
	var path=OS.get_environment("SOFT_RENDER_BASELINE")
	if path.is_empty():push_error("Set SOFT_RENDER_BASELINE to frozen baseline project");quit(1);return
	var baseline=load(path+"/scripts/soft_insect.gd")
	var comparisons=0
	for species in Brood.SPECIES:
		var a=actor(1,species);var b=actor(1,species)
		Soft.prepare(a);baseline.prepare(b)
		for frame in 600:
			if frame in [10,11,12,30,100,120,121,180,200,220]:
				var direction=Vector2.from_angle(frame*.17)
				var family=["cannon","flame","blackhole","shield","rail"][frame%5]
				Soft.impact(a,a.position+direction*10,direction,45,family)
				baseline.impact(b,b.position+direction*10,direction,45,family)
			var dt=[1.0/120,1.0/60,1.0/30,.001,.15,0.0,-.1][frame%7]
			Soft.step(a,dt);baseline.step(b,dt)
			for key in b.soft_body:
				comparisons+=1
				if a.soft_body[key]!=b.soft_body[key] and mismatches.size()<12:mismatches.append({"species":species,"frame":frame,"field":key,"actual":str(a.soft_body[key]),"expected":str(b.soft_body[key])})
	var timings={}
	for active in [false,true]:
		for optimized in [false,true]:
			var solver=Soft if optimized else baseline
			var actors=[]
			for i in 128:
				var e=actor(i,Brood.SPECIES[i%6]);solver.prepare(e)
				if active:solver.impact(e,e.position+Vector2(10,0),Vector2.LEFT,45,"cannon")
				actors.append(e)
			var start=Time.get_ticks_usec()
			for frame in 120:
				for e in actors:solver.step(e,1.0/60)
			timings[("optimized" if optimized else "baseline")+("_active" if active else "_idle")+"_128_actors_ms_per_tick"]=(Time.get_ticks_usec()-start)/120000.0
	var report={"passed":mismatches.is_empty(),"exact_field_comparisons":comparisons,"mismatches":mismatches,"cpu":timings}
	FileAccess.open("res://artifacts/soft-solver-performance-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
