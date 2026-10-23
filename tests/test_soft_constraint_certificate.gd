extends SceneTree
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
func _initialize():call_deferred("execute")
func actor(i:int)->Dictionary:
	return {"uid":i,"kind":"AISwarmingUnit","position":Vector2.ZERO,"angle":i*.17,"hp":10000.0,"max_hp":10000.0,"radius":18.0,"brood_species":Brood.SPECIES[i%Brood.SPECIES.size()]}
func execute():
	var a=[];var b=[]
	for i in 24:a.append(actor(i));b.append(actor(i))
	var differences=0;var compared=0
	for tick in 900:
		for i in a.size():
			if tick%37==i%7:
				var direction=Vector2.from_angle(tick*.031+i)
				Soft.impact(a[i],direction*12,direction,45);Soft.impact(b[i],direction*12,direction,45)
			var dt=[1.0/120,1.0/60,1.0/30,.001,.15,0.0][tick%6]
			Soft.use_constraint_certificate=true;Soft.step(a[i],dt)
			Soft.use_constraint_certificate=false;Soft.step(b[i],dt)
			compared+=1
			if a[i].soft_body!=b[i].soft_body:differences+=1
	var old_us=0;var new_us=0
	for batch in 6:
		for order in 2:
			var enabled=(batch+order)%2==0;Soft.use_constraint_certificate=enabled
			var actors=[]
			for i in 32:
				var e=actor(i);Soft.prepare(e);Soft.impact(e,Vector2(12,0),Vector2.LEFT,45);actors.append(e)
			var began=Time.get_ticks_usec()
			for tick in 360:
				for i in actors.size():
					if tick%90==i:Soft.impact(actors[i],Vector2(0,12),Vector2.UP,45)
					Soft.step(actors[i],1.0/60)
			var elapsed=Time.get_ticks_usec()-began
			if enabled:new_us+=elapsed
			else:old_us+=elapsed
	Soft.use_constraint_certificate=true
	var report={"passed":differences==0,"exact_actor_step_comparisons":compared,"state_differences":differences,"paired_steps":6*32*360,"reference_us":old_us,"certified_us":new_us,"scope":"Exact complete soft-body state comparison and paired timing; not FPS."}
	FileAccess.open("res://artifacts/soft-constraint-certificate-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
