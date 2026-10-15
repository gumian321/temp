extends SceneTree
const Motion = preload("res://scripts/viscous_projectile_motion.gd")
const Feedback = preload("res://scripts/weapon_feedback.gd")
var checks: Array = []
func check(ok: bool, title: String):
	checks.append({"name":title,"passed":ok})
	if not ok: printerr("FAIL: ",title)
func shot(weapon: String, speed: float, friendly: bool = true) -> Dictionary:
	var b = {"position":Vector2.ZERO,"previous":Vector2.ZERO,"velocity":Vector2.RIGHT*speed,"age":0.0,"fx_family":weapon,"friendly":friendly,"damage":17.0,"shield_damage":9.0,"life":2.0,"radius":4.0,"pierce":1}
	Motion.initialize(b, 4)
	return b
func _initialize():
	for weapon in ["gatling","shotgun","cannon","flame","flak","nuke","mine","rocket"]:
		var endpoints: Array = []
		for hz in [30,60,120]:
			var b = shot(weapon,480)
			var max_sway = 0.0
			for frame in range(hz):
				b.previous=b.position;b.age+=1.0/hz;Motion.advance(b,1.0/hz)
				max_sway=maxf(max_sway,absf(b.position.y))
			check(max_sway==0.0 and max_sway<=Motion.MAX_SWAY,"%s %dHz no cosmetic lateral deviation"%[weapon,hz])
			check(absf(b.position.x-480)<0.001 and b.velocity==Vector2(480,0),"%s %dHz forward speed unchanged"%[weapon,hz])
			check(b.damage==17.0 and b.shield_damage==9.0 and b.pierce==1 and b.life==2.0 and b.radius==4.0,"%s motion cannot alter damage/collision budget"%weapon)
			endpoints.append(b.position)
		check(endpoints[0].distance_to(endpoints[2])<0.001,"%s frame-independent straight centerline"%weapon)
	for weapon in ["rocket","gatling","nuke","rail","tesla","sonic","unknown"]:
		for friendly in [true,false]:
			for speed in [0.0,900.0,960.0,3000.0]:
				var b=shot(weapon,speed,friendly);b.age=.2;Motion.advance(b,.2)
				check(b.position==Vector2(speed*.2,0),"Fast, stationary, and precision trajectories untouched: %s"%weapon)
		var hostile=shot(weapon,480,false);hostile.age=.2;Motion.advance(hostile,.2)
		check(hostile.position==Vector2(96,0),"Hostile readability preserves straight path: %s"%weapon)
	for weapon in ["rail","tesla","sonic","unknown"]:
		var precision=shot(weapon,480);precision.age=.2;Motion.advance(precision,.2)
		check(precision.position==Vector2(96,0),"Slow precision and unknown families remain straight: %s"%weapon)
	var effects: Array = []
	var target={"position":Vector2(100,0),"angle":0.0,"hp":100.0}
	var b=shot("nuke",480);b.previous=Vector2.ZERO;b.position=Vector2(130,0)
	var contact=Feedback.surface_contact(target.position,20,b)
	for n in 100: Motion.add_contact(effects,target,contact,"nuke",true,18,Motion.MAX_CONTACTS-effects.size())
	check(effects.size()==Motion.MAX_CONTACTS,"Contact budget caps a hundred egg hits at 24")
	check(effects[0].position==contact.position,"Egg initially adheres at exact swept surface contact")
	target.position+=Vector2(9,11);target.angle=PI/2
	for e in effects: e.life-=.3;Motion.advance_contact(e,.3)
	check(effects[0].position.distance_to(target.position+Vector2(0,-20))<.001,"Attachment follows direct target reference and surface rotation")
	for e in effects: e.life-=.3;Motion.advance_contact(e,.3)
	check(effects.all(func(e):return e.kind=="egg_burst" and not e.has("follow")),"Eggs swell then transition in-place to bounded detached visual burst")
	check(target.hp==100.0,"Egg swelling and burst apply no extra damage")
	for e in effects: e.life-=.2;Motion.advance_contact(e,.2)
	effects=effects.filter(func(e):return e.life>0)
	check(effects.is_empty(),"Egg contacts and bursts expire without spawning extra effects")
	var db=load("res://scripts/source_db.gd").new()
	var body=load("res://scripts/grid_centipede.gd").new(db)
	var battle=load("res://scripts/combat.gd").new(db,body)
	var enemy=battle.spawn(db.pool["250"],Vector2(100,0));enemy.guns=[];enemy.hp=1000;enemy.max_hp=1000
	b=shot("flak",480);b.data=db.asset(db.named("Core_Gun_Gatling").coreProjectile);b.chips={};b.position=Vector2(130,0)
	battle.refresh_spatial()
	check(enemy in battle.projectile_candidates(b),"Spatial broadphase sees organic swept endpoints")
	var rng_state=battle.rng.state
	battle.hit_enemy(enemy,b)
	check(enemy.hp==983 and battle.hit_count==1,"Egg visual preserves immediate single gameplay hit")
	check(battle.effects.any(func(e):return e.kind=="viscous_contact" and e.organic_family=="egg"),"Combat emits attached egg visual")
	for e in battle.effects:
		e.life-=1.0;Motion.advance_contact(e,1.0)
	check(enemy.hp==983 and battle.hit_count==1 and battle.rng.state==rng_state,"Visual expiry never double-damages or consumes gameplay RNG")
	battle.effects.clear();enemy.fx_cooldown=0
	battle.impact_feedback(enemy,b,true,enemy.position,50)
	check(not battle.effects.any(func(e):return e.kind=="viscous_contact"),"Absorbed shield hit does not attach goo to protected hull")
	battle.effects.clear();battle.viscous_contact_count=0
	for i in 100:
		enemy.fx_cooldown=0
		battle.impact_feedback(enemy,b)
	check(battle.viscous_contact_count==Motion.MAX_CONTACTS and battle.effects.filter(func(e):return e.kind=="viscous_contact").size()==Motion.MAX_CONTACTS,"Combat admission enforces constant-time contact budget")
	Motion.add_contact(effects,target,contact,"cannon",true,18,Motion.MAX_CONTACTS-effects.size())
	target.hp=0
	Motion.advance_contact(effects[0],.01)
	check(not effects[0].has("follow"),"Dead attachment target is released without an actor scan")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/viscous-motion-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
