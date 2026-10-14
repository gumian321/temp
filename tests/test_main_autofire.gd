extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
var checks:Array=[]
var db
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func fixture():return Battle.new(db,Body.new(db))
func actor(b,at=Vector2(180,0)):
	var e=b.spawn(db.pool["250"],at)
	e.guns=[];e.mission_controlled=true;e.hp=100000;e.max_hp=e.hp
	return e
func tick(b,manual=false,aim=Vector2(0,600),seconds=1.0):
	for i in range(int(seconds*60)):b.step(1.0/60,aim,manual)
func shots(b):return int(b.statistics.get("stat_BulletsFired",0))
func _initialize():call_deferred("execute")
func execute():
	db=DB.new()
	var b=fixture();tick(b)
	check(shots(b)==0,"No target means no random HQ firing")
	var e=actor(b);tick(b)
	check(shots(b)>0 and absf(b.player.parts[0].angle)<0.01,"Default HQ automatically acquires and fires at a real enemy")
	check(e.hp<e.max_hp,"Automatic HQ projectiles actually damage their enemy")
	var before=shots(b);tick(b,true)
	check(shots(b)>before and absf(b.player.parts[0].angle-PI/2)<0.01,"Held manual aim overrides nearby enemy")
	tick(b,false)
	check(absf(b.player.parts[0].angle)<0.01,"Release restores automatic targeting")
	for invalid in ["friendly","dead","undamageable","warping","cloaked","range"]:
		b=fixture();e=actor(b)
		match invalid:
			"friendly":e.role="friendly"
			"dead":e.hp=0
			"undamageable":e.damageable=false
			"warping":e.warp=100
			"cloaked":e.cloaked=true
			"range":e.position=Vector2(10000,0)
		tick(b)
		check(shots(b)==0,"Auto targeting excludes "+invalid)
	b=fixture();actor(b);b.player.parts[0].cooldown=2;tick(b)
	check(shots(b)==0,"Existing HQ cooldown is respected")
	b=fixture();actor(b)
	for i in range(60):b.step(1.0/60,Vector2.RIGHT*600,true,false)
	check(shots(b)==0,"Disabled player input blocks both automatic and manual shots")
	b=fixture();e=actor(b);tick(b);e.role="friendly";before=shots(b);tick(b)
	check(shots(b)==before,"Enemy converted to an ally is dropped immediately by auto targeting")
	b=fixture();var rocket=db.named("HQ_Gun_Rocket")
	b.fire(rocket,Vector2.ZERO,Vector2.RIGHT,true,{},0,false,0,1,"player:0")
	before=shots(b)
	for i in range(60):b.step(1.0/60,Vector2.RIGHT*600,false,false)
	check(shots(b)==before and not b.barrages.is_empty(),"UI suppression pauses pending player-owned barrage shots")
	b.fire(rocket,Vector2.ZERO,Vector2.RIGHT,true,{},0,false,0,1,"enemy:42")
	before=shots(b)
	for i in range(60):b.step(1.0/60,Vector2.RIGHT*600,false,false)
	check(shots(b)>before,"UI suppression does not stop independently owned friendly barrages")
	b=fixture();actor(b);b.player.parts[0].stun=2;tick(b)
	check(shots(b)==0,"Stunned HQ cannot auto fire")
	var hq_count=0
	for core in db.catalog.values():
		if not str(core.get("name","")).begins_with("HQ_") or not core.has("coreProjectile"):continue
		b=fixture();b.player.hq_weapon=core.id;actor(b,Vector2(80,0));tick(b)
		check(shots(b)>0,"HQ variant auto fires: "+str(core.get("name",core.id)));hq_count+=1
	check(hq_count>0,"HQ variant catalog coverage is nonempty")
	# Manual chip remains opt-in: install a gun adjacent to the chip, away from HQ.
	b=fixture();b.player.append_segment(db.named("Core_Gun_Gatling").id)
	var chip={}
	for core in db.catalog.values():
		if core.has("coreChip") and int(db.asset(core.coreChip).get("chipType",-1))==6:chip=core;break
	if not chip.is_empty():
		b.player.append_segment(chip.id);b.player.parts[0].cooldown=100;actor(b);tick(b)
		check(shots(b)==0,"Adjacent manual-aim chip gun remains idle without explicit input")
		tick(b,true,Vector2.RIGHT*600)
		check(shots(b)>0,"Adjacent manual-aim chip gun still fires under manual input")
	else:check(false,"Manual-aim chip exists")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/main-autofire-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
