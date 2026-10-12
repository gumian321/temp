extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/centipede.gd")
const Battle = preload("res://scripts/combat.gd")
var checks = 0
var failures: Array = []
func check(ok,message):
	checks += 1
	if not ok: failures.append(message); printerr(message)
func _initialize():
	var db=DB.new()
	var p=Body.new(db)
	var b=Battle.new(db,p)
	check(b.special.chip("PiercingTargetCount",1)==1 and b.special.chip("PiercingTargetCount",2)==2,"piercing uses source counts 1/2")
	check(b.special.chip("chainTargetJumpCount",2)==3,"chain level two uses three jumps")
	p.add_piece(db.named("Core_MinesField").id,Vector2i(-1,0))
	b.step(0.01,Vector2.RIGHT,false)
	check(b.special.mines.size()==1,"minefield starts with source recharge spawn")
	var mine=b.special.mines[0]
	var e=b.spawn(db.pool["250"],mine.position)
	e.mission_controlled=true
	var hp=e.hp
	b.step(0.01,Vector2.RIGHT,false)
	check(e.hp<hp,"mine contact inflicts source damage")
	check(b.special.mines.is_empty(),"contact consumes mine")
	var bh=db.kind("BlackHoleProjectile")[0]
	b.special.add_black_hole({"position":Vector2.ZERO,"data":bh,"chips":{},"damage":float(bh.projectileDamage.hullDamage),"shield_damage":1.0,"friendly":true})
	var victim=b.spawn(db.pool["250"],Vector2(20,0));victim.mission_controlled=true
	hp=victim.hp
	b.special.step(0.1)
	check(is_equal_approx(victim.hp,hp-float(bh.projectileDamage.hullDamage)*0.1),"black hole damage is per second, not single impact")
	check(b.special.black_holes[0].life<float(bh.projectileEffectAreaDuration),"black hole duration decreases")
	p.add_piece(db.named("Core_Clocking").id,Vector2i(-2,0))
	b.special.step(0.01)
	check(p.parts[1].cloaked,"clocking module hides neighboring compatible module")
	p.parts[2].hp=0
	b.special.step(0.01)
	check(not p.parts[1].cloaked,"destroyed cloaking module restores collision")
	var rocket=db.named("HQ_Gun_Rocket")
	b.bullets.clear();b.barrages.clear()
	b.fire(rocket,Vector2.ZERO,Vector2.RIGHT,true)
	check(b.bullets.size()==1 and b.barrages.size()==1,"rocket barrage starts one projectile and schedules remainder")
	b.step(0.11,Vector2.RIGHT,false)
	check(b.barrages[0].count==int(rocket.barrageProjectileCount)-2,"barrage dispatches next projectile at source interval")
	var report={"checks":checks,"passed":checks-failures.size(),"failures":failures,"scope":"Source chip counts, mine contacts/recharge, black-hole DPS, cloaking lifecycle, timed rocket barrage."}
	FileAccess.open("res://artifacts/special-test-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(1 if not failures.is_empty() else 0)
