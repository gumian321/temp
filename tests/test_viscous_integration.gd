extends SceneTree
const Motion=preload("res://scripts/viscous_projectile_motion.gd")
const Feedback=preload("res://scripts/weapon_feedback.gd")
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/grid_centipede.gd")
const Combat=preload("res://scripts/combat.gd")
var checks:Array=[]
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func _initialize():call_deferred("execute")
func execute():
	# Actual combat swept-collision path at normal, slow-motion and coarse timesteps.
	var db=DB.new()
	for dt in [1.0/600.0,1.0/60.0,0.1]:
		var body=Body.new(db);var battle=Combat.new(db,body)
		var target=battle.spawn(db.pool["250"],Vector2(110,0))
		target.guns=[];target.hp=1000;target.max_hp=1000;target.kind="Asteroid";target.unit={};target.radius=22.0
		var shot={"position":Vector2.ZERO,"previous":Vector2.ZERO,"origin":Vector2.ZERO,"velocity":Vector2(600,0),"direction":Vector2.RIGHT,"age":0.0,"life":2.0,"radius":4.0,"friendly":true,"fx_family":"cannon","data":{"class":"BasicProjectile"},"damage":7.0,"shield_damage":7.0,"hit":[],"pierce":1,"chips":{}}
		Motion.initialize(shot);battle.bullets.append(shot)
		var contact={}
		for frame in int(ceil(0.3/dt)):
			battle.step(dt,Vector2(1000,0),false,false)
			for effect in battle.effects:
				if effect.kind=="viscous_contact":contact=effect.duplicate()
		check(target.hp==993.0 and battle.hit_count==1,"Swept organic shot deals original damage exactly once at dt="+str(dt))
		check(not contact.is_empty() and absf(Vector2(contact.get("position",Vector2.ZERO)).distance_to(target.position)-target.radius)<0.01,"Organic impact anchors on actual target surface at dt="+str(dt))
		check(battle.bullets.is_empty(),"Collided non-piercing projectile recycled at dt="+str(dt))
	# Cosmetic attachments stay bounded and release after TTL, including egg bursts.
	var target={"position":Vector2(300,100),"angle":0.0,"hp":100.0}
	var contact={"position":Vector2(280,100),"normal":Vector2.LEFT,"direction":Vector2.RIGHT}
	var effects:Array=[]
	for i in 100:Motion.add_contact(effects,target,contact,"flak",true,20.0,Motion.MAX_CONTACTS-effects.size())
	check(effects.size()==Motion.MAX_CONTACTS,"Organic contact presentation has a global hard cap")
	target.position+=Vector2(12,8);target.angle=PI/2
	for effect in effects:Motion.advance_contact(effect,0.05)
	check(effects[0].position.distance_to(target.position+Vector2(0,-20))<0.001,"Attached egg follows translated and rotated hull without actor search")
	for effect in effects:
		effect.life=0.17;Motion.advance_contact(effect,0.01)
	check(effects.all(func(e):return e.kind=="egg_burst" and not e.has("follow")),"Egg reaches cosmetic rupture and releases retained target")
	var burst_position=effects[0].position;target.position+=Vector2(50,50)
	for effect in effects:Motion.advance_contact(effect,0.01)
	check(effects[0].position==burst_position,"Released rupture remains at its actual detachment location")
	for effect in effects:effect.life-=1.0
	effects=effects.filter(func(e):return e.life>0)
	Motion.add_contact(effects,target,contact,"cannon",true,8,Motion.MAX_CONTACTS-effects.size())
	check(effects.size()==1,"Expired contact slots become available for subsequent impacts")
	target.hp=0;Motion.advance_contact(effects[0],0.01)
	check(not effects[0].has("follow"),"Destroyed target releases attachment reference")
	# Every projectile center follows velocity; deformation is rendering only.
	for speed in [600.0,1200.0]:
		for friendly in [true,false]:
			var shot={"position":Vector2.ZERO,"velocity":Vector2(speed,0),"age":0.0,"friendly":friendly,"fx_family":"rocket"}
			Motion.initialize(shot,7)
			var bounded=true
			for i in 1200:
				shot.age+=1.0/600.0;Motion.advance(shot,1.0/600.0)
				bounded=bounded and absf(shot.position.y)<=Motion.MAX_SWAY and shot.velocity==Vector2(speed,0)
			check(bounded and absf(shot.position.x-speed*2.0)<0.1,"Exact centerline preserves speed/velocity: "+str(speed)+" friendly="+str(friendly))
			check(shot.position.y==0.0,"All projectile speeds and factions retain exact straight trajectory")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/viscous-integration-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
