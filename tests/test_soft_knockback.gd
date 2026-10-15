extends SceneTree
const Soft=preload("res://scripts/soft_insect.gd")
const Push=preload("res://scripts/knockback.gd")
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func execute():
	var peaks={}
	for species in Soft.Brood.SPECIES:
		var e={"uid":1,"kind":"AISwarmingUnit","position":Vector2.ZERO,"angle":0.0,"hp":100.0,"max_hp":100.0,"radius":30.0,"brood_species":species}
		Push.add_impulse(e,Vector2.RIGHT,5);Soft.begin_push(e)
		var state:Dictionary=e.soft_body
		check(state.push_strain<-.15,"Immediate compression: "+species)
		var frozen=state.duplicate(true);Soft.step(e,0)
		check(state==frozen,"Paused combat freezes all push deformation: "+species)
		var stretch=false;var rebound=false;var peak=0.0;var bounded=true
		for frame in 240:
			Soft.step(e,1.0/60);Push.take_displacement(e,1.0/60)
			stretch=stretch or float(state.get("push_strain",0))>.03
			rebound=rebound or float(state.get("push_bend",0))<-.01
			var a=Vector2(0.6,0.4);var b=Vector2(-0.6,-0.4)
			var da=Soft.push_deform(state,a,Vector2.ZERO,1.0,0)
			var db=Soft.push_deform(state,b,Vector2.ZERO,1.0,0)
			peak=maxf(peak,absf(da.distance_to(db)-a.distance_to(b)))
			bounded=bounded and da.is_finite() and db.is_finite() and da.distance_to(a)<=.241 and db.distance_to(b)<=.241
		check(stretch and rebound,"Compression becomes stretch and a reversing body wobble: "+species)
		check(bounded and peak>.03,"Shape changes internally without unbounded mesh distortion: "+species)
		check(not state.has("push_strain"),"Springs settle completely after knockback: "+species)
		check(e.position==Vector2.ZERO and e.hp==100,"Deformation cannot move hitboxes or change damage: "+species)
		peaks[species]=peak
	check(peaks.beetle<peaks.grub*.6,"Rigid beetle shell deforms less than a soft grub")
	var e={"uid":2,"kind":"AISwarmingUnit","position":Vector2.ZERO,"angle":0.3,"hp":100.0,"max_hp":100.0,"radius":30.0,"brood_species":"grub"}
	for frame in 120:
		Push.add_impulse(e,Vector2.from_angle(frame*.04),5);Soft.begin_push(e)
		Soft.step(e,1.0/60);Push.take_displacement(e,1.0/60)
	check(absf(e.soft_body.push_strain)<=.28 and absf(e.soft_body.push_bend)<=.22,"Overlapping impacts and changing directions cannot accumulate extreme poses")
	for frame in 300:Soft.step(e,1.0/60);Push.take_displacement(e,1.0/60)
	check(not e.soft_body.has("push_strain"),"Even sustained fire permits full recovery when it ends")
	var report={"checks":checks,"shape_change_by_species":peaks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/soft-knockback-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
