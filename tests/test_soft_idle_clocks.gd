extends SceneTree
const Soft=preload("res://scripts/soft_insect.gd")
func _initialize():call_deferred("execute")
func fixture(at:float)->Dictionary:
	return {"kind":"AISwarmingUnit","soft_body":{"rest":PackedVector2Array(),"lattice_active":false,"clock":at,"pose_clock":at*.7,"cue_age":at*.3}}
func execute():
	var original=Soft.use_idle_clock_locals;var comparisons=0;var differences:Array=[]
	var steps=[0.0,-.1,.00001,.000011,1.0/240,1.0/120,1.0/60,.027,.05,.1,.15,.3]
	for at in [0.0,.001,10.2,1800.123,131072.5,1000000000.0]:
		var a=fixture(at);var b=fixture(at)
		for tick in 3600:
			var dt:float=steps[tick%steps.size()]
			Soft.use_idle_clock_locals=false;Soft.step(a,dt)
			Soft.use_idle_clock_locals=true;Soft.step(b,dt)
			comparisons+=1
			if a!=b and differences.size()<8:differences.append({"start":at,"tick":tick,"old":a,"new":b})
	var timings:Array=[]
	for optimized in [false,true,true,false]:
		Soft.use_idle_clock_locals=optimized
		var actors:Array=[]
		for i in 320:actors.append(fixture(float(i)*.51))
		var start=Time.get_ticks_usec()
		for frame in 180:
			for actor in actors:Soft.step(actor,1.0/30)
		timings.append({"optimized":optimized,"ms_per_320_actor_tick":float(Time.get_ticks_usec()-start)/180000})
	Soft.use_idle_clock_locals=original
	var report={"passed":differences.is_empty(),"comparisons":comparisons,"differences":differences,"timings":timings,"scope":"Exact idle-clock substep arithmetic at varied dt and clock magnitudes; CPU kernel only, no rendered FPS claim."}
	FileAccess.open("res://artifacts/deep50-soft-idle-clocks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
