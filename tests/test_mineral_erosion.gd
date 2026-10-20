extends SceneTree
const Mineral=preload("res://scripts/mineral_erosion.gd")
const Health=preload("res://scripts/enemy_health_layer.gd")
var checks:Array=[]
var db
var body
var battle
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok: printerr("FAIL: ",title)
func rock(at:Vector2=Vector2.ZERO)->Dictionary:
	var e=battle.spawn(db.pool["132"],at)
	e.warp=0.0; e.hp=100.0; e.max_hp=100.0; e.guns=[]
	return e
func shot(e:Dictionary,damage:float=25.0,offset:float=0.0)->Dictionary:
	return {"previous":e.position+Vector2(-200,offset),"position":e.position+Vector2(200,offset),"velocity":Vector2(3000,0),"radius":.5,"damage":damage,"shield_damage":damage,"data":{"class":"BasicProjectile"},"chips":{},"pierce":1,"friendly":true,"hit":[]}
func _initialize():
	db=load("res://scripts/source_db.gd").new()
	body=load("res://scripts/grid_centipede.gd").new(db)
	battle=load("res://scripts/combat.gd").new(db,body)
	var rng=battle.rng.state
	for variant in 4:
		battle.enemies.clear()
		var e=rock(); e.uid=100+variant
		var original=Mineral.base(e)
		var original_cells=original.cells.duplicate()
		check(not Health.eligible(e),"Mineral has no HP bar, variant %d"%variant)
		var peer=e.duplicate(true); peer.uid=e.uid+4
		var s=shot(e,25)
		var entry=Mineral.sweep(e,s.previous,s.position,s.radius,db)
		check(not entry.is_empty() and entry.position.x<e.position.x,"Swept hit finds visible front face, variant %d"%variant)
		battle.hit_enemy(e,s)
		check(e.has("mineral") and absf(float(e.mineral.remaining)/original.total-.75)<.002,"Damage removes corresponding material area, variant %d"%variant)
		check(not peer.has("mineral") and original.cells==original_cells,"Damage cannot alter another mineral or the source atlas")
		var next=Mineral.sweep(e,s.previous,s.position,s.radius,db)
		check(not next.is_empty() and next.position.x>entry.position.x+1,"Next impact advances into the chipped face")
		var count=e.mineral.remaining
		e.hp=90; Mineral.erode(e,entry.position,db)
		check(e.mineral.remaining==count,"Healing never regrows removed material")
		e.hp=25; Mineral.erode(e,next.position,db)
		check(e.mineral.remaining<count,"Further damage only removes material")
		var aim=battle.target_position(e)
		check(not Mineral.sweep(e,aim,aim,0,db).is_empty(),"Automatic weapons target surviving material instead of an empty center")
		var mask_matches=true
		for i in e.mineral.cells.size():
			var visible=e.mineral.image.get_pixel(i%int(e.mineral.size.x),i/int(e.mineral.size.x)).a>=Mineral.ALPHA
			if visible!=(e.mineral.cells[i]!=0):mask_matches=false;break
		check(mask_matches,"Rendered alpha and collision agree for every pixel")
		e.hp=0.00001; Mineral.erode(e,next.position,db)
		check(e.mineral.remaining>=1,"Fractional surviving HP retains hittable material")
		aim=battle.target_position(e)
		check(not Mineral.sweep(e,aim-Vector2(3000,0),aim+Vector2(3000,0),0,db).is_empty(),"Fast zero-radius sweep hits even the final single-pixel fragment")
		e.hp=0; Mineral.erode(e,next.position,db)
		check(e.mineral.remaining==0 and Mineral.sweep(e,s.previous,s.position,1,db).is_empty(),"Destroyed mineral has no phantom collision")
	check(battle.rng.state==rng,"Erosion and chips consume no combat RNG")
	# Real projectile loop: a clear cut must not consume the shot or its pierce.
	battle.enemies.clear(); battle.effects.clear(); battle.loot.clear()
	var front=rock()
	front.hp=35; Mineral.erode(front,front.position+Vector2(-12,-24),db)
	var gap_y=INF
	var intact=front.duplicate(); intact.erase("mineral")
	for y in range(-38,39):
		var start=Vector2(-140,y); var end=Vector2(140,y)
		if not Mineral.sweep(intact,start,end,.5,db).is_empty() and Mineral.sweep(front,start,end,.5,db).is_empty():gap_y=y;break
	check(is_finite(gap_y),"Localized erosion opens a bullet-sized passage through original material")
	if is_finite(gap_y):
		var target=battle.spawn(db.pool["250"],Vector2(140,gap_y))
		target.warp=0; target.hp=1000; target.max_hp=1000; target.guns=[];target.stun=1.0
		battle.fire(db.named("Core_Gun_Gatling"),Vector2(-150,gap_y),Vector2.RIGHT,true)
		var bullet=battle.bullets.back()
		bullet.position=Vector2(-150,gap_y); bullet.velocity=Vector2(6400,0);bullet.radius=.5;bullet.damage=2;bullet.pierce=1
		battle.step(.05,Vector2.ZERO,false,false)
		check(front.hp==35 and target.hp<1000,"Actual bullet passes through removed material and damages target behind")
	# Shields absorb the hit before carving; splash and sustained damage do carve.
	battle.enemies.clear(); battle.effects.clear(); battle.bullets.clear()
	var protected=rock()
	protected.guns=[{"id":db.named("Core_Shield").id,"shield":100.0}]
	battle.hit_enemy(protected,shot(protected))
	check(protected.hp==100 and not protected.has("mineral"),"Shield-absorbed hit leaves the mineral intact")
	protected.guns=[]
	var center=battle.spawn(db.pool["250"],Vector2(-65,0));center.guns=[];center.warp=0;center.hp=1000
	var blast=shot(center,25);blast.data.projectileEffectArea=4.0
	battle.hit_enemy(center,blast)
	check(protected.hp==75 and protected.has("mineral"),"Explosion splash removes material on neighboring mineral")
	var before=protected.mineral.remaining
	battle.special.black_holes=[{"position":Vector2(-60,0),"radius":160.0,"life":1.0,"damage":50.0,"shield_damage":0.0,"friendly":true,"force":0.0}]
	battle.special.step(.1)
	check(protected.mineral.remaining<before,"Sustained black-hole damage also erodes material")
	# Conservative broad phase includes visible corners outside the legacy radius.
	battle.refresh_spatial()
	check(battle.spatial.max_radius>=Mineral.bounds_radius(protected,db),"Spatial index encloses full sprite rather than the old small circle")
	var timer=Time.get_ticks_usec()
	for i in 30:
		var e=rock(Vector2(i*100,500));e.hp=75
		Mineral.erode(e,e.position+Vector2(-30,0),db)
	var milliseconds=float(Time.get_ticks_usec()-timer)/1000.0
	check(milliseconds<1500,"Thirty simultaneous quarter-rock cuts finish within bounded CPU work")
	# End-to-end automatic mining must finish after its original aim point disappears.
	body=load("res://scripts/grid_centipede.gd").new(db)
	battle=load("res://scripts/combat.gd").new(db,body)
	var mined=rock(Vector2(150,0));mined.hp=12;mined.max_hp=12
	for tick in 900:
		battle.step(1.0/60.0,Vector2.ZERO,false)
		if mined.hp<=0: break
	check(mined.hp<=0 and battle.statistics.get("stat_AsteroidsDestroyed",0)==1,"Automatic mining destroys all remaining fragments and records one mined rock")
	var reward=0
	for drop in battle.loot:
		if not drop.pack: reward+=int(drop.value)
	check(reward==int(mined.unit.get("totalScraps",0))+int(mined.unit.get("totalScrapsOnDestroy",0)),"Full mining preserves the original total resource reward")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"thirty_cuts_ms":milliseconds}
	FileAccess.open("res://artifacts/mineral-erosion-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
