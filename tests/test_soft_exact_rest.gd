extends SceneTree
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func actor(species:String)->Dictionary:
	var e={"uid":1,"kind":"AISwarmingUnit","position":Vector2(50,80),"angle":.23,"hp":100.0,"max_hp":100.0,"radius":18.0,"brood_species":species}
	Soft.prepare(e);e.soft_body.lattice_active=true;e.soft_body.peak=.17
	return e
func execute():
	var original=Soft.use_exact_rest_certificate;var comparisons=0;var equal=true
	for species in Brood.SPECIES:
		var a=actor(species);var b=actor(species)
		check(Soft.exact_rest_certificate(a.soft_body),"Exact-zero stale-active %s body can skip its no-op lattice"%species)
		for tick in 720:
			if tick in [20,200,450]:
				Soft.impact(a,a.position+Vector2(9,3),Vector2.LEFT,17,"cannon")
				Soft.impact(b,b.position+Vector2(9,3),Vector2.LEFT,17,"cannon")
				check(not Soft.exact_rest_certificate(b.soft_body),"A fresh impact wakes %s at tick %d"%[species,tick])
			if tick==300:
				a.knockback_velocity=Vector2.RIGHT*80;b.knockback_velocity=Vector2.RIGHT*80
				Soft.begin_push(a);Soft.begin_push(b)
			if tick==310:a.erase("knockback_velocity");b.erase("knockback_velocity")
			if tick==380:
				Soft.pull(a,Vector2.LEFT,120.0,.033);Soft.pull(b,Vector2.LEFT,120.0,.033)
			var dt:float=[1.0/120,1.0/60,1.0/30,.001,.15,0.0,-.1][tick%7]
			Soft.use_exact_rest_certificate=false;Soft.step(a,dt)
			Soft.use_exact_rest_certificate=true;Soft.step(b,dt)
			comparisons+=1;equal=equal and a==b
	check(equal,"Every physical and feedback field, including lattice_active, matches with variable dt, impacts, push and pull")
	for field in ["hold","flash","shock","lean","lean_velocity","cue_cooldown"]:
		var e=actor("grub");e.soft_body[field]=1e-300
		check(not Soft.exact_rest_certificate(e.soft_body),"Tiny nonzero %s is never truncated"%field)
	for field in ["offset","velocity"]:
		var e=actor("grub");e.soft_body[field][0]=Vector2(1e-30,0)
		check(not Soft.exact_rest_certificate(e.soft_body),"Tiny nonzero %s components remain active even if their squared length underflows"%field)
	for field in ["recoil","recoil_velocity"]:
		var e=actor("grub");e.soft_body[field]=Vector2(1e-30,0)
		check(not Soft.exact_rest_certificate(e.soft_body),"Tiny nonzero %s feedback remains active"%field)
	var timings:Array=[]
	for optimized in [false,true,true,false]:
		Soft.use_exact_rest_certificate=optimized
		var actors:Array=[]
		for i in 128:actors.append(actor(Brood.SPECIES[i%6]))
		var began=Time.get_ticks_usec()
		for frame in 90:
			for e in actors:Soft.step(e,1.0/30)
		timings.append({"optimized":optimized,"ms_per_128_zero_energy_active_bodies":float(Time.get_ticks_usec()-began)/90000})
	Soft.use_exact_rest_certificate=original
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"exact_state_comparisons":comparisons,"timings":timings,"scope":"Strict zero-energy certificate only, no epsilon or animation-rate reduction. Synthetic worst-case stale-active kernel timing is not a game FPS claim."}
	FileAccess.open("res://artifacts/deep50-soft-exact-rest.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
