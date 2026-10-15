extends SceneTree
## Runtime route audit: invokes production combat and production painters.
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const Layer=preload("res://scripts/attack_shader_layer.gd")
const Feedback=preload("res://scripts/weapon_feedback.gd")
class Board extends Node2D:
	var job:Callable
	func _draw():
		if job.is_valid():job.call()
	func world(at):return at+Vector2(400,300)
class RecordedPassive extends "res://scripts/living_passive_layer.gd":
	# Dummy headless renderer does not retain MultiMesh buffer getters. Observe
	# submitted payloads while still executing the real production add method.
	var payloads:Array=[]
	func begin(time:float):
		payloads.clear();super.begin(time)
	func add(mode:int,at:Vector2,extent:Vector2,angle:float,state:Color,event:Color=Color(0,0,0,0))->bool:
		var accepted=super.add(mode,at,extent,angle,state,event)
		if accepted:payloads.append({"mode":mode,"state":state,"event":event,"extent":extent})
		return accepted
var checks:Array=[]
var board
var layer
var fx
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func submitted(key:String,hostile:bool)->bool:
	var painter=layer.batches.get(key+str(hostile))
	if painter==null:return false
	return [painter.batch,painter.texture_batch].any(func(batch):return batch.material is ShaderMaterial and batch.material.shader==Layer.SHADER and batch.commands.any(func(c):return c[0]!="draw_set_transform"))
func _initialize():call_deferred("execute")
func execute():
	root.size=Vector2i(1280,720)
	board=Board.new();root.add_child(board)
	layer=Layer.new();layer.trace_commands=true;layer.attach(board);fx=FX.new()
	var db=DB.new();var count=0;var families={}
	for core in db.catalog.values():
		if not core.has("coreProjectile"):continue
		count+=1
		var family=Feedback.family(core);families[family]=true
		for friendly in [true,false]:
			for rank in [0,1,5]:
				var body=Body.new(db);var battle=Battle.new(db,body)
				var enemy=battle.spawn(db.pool["250"],Vector2(120,0))
				enemy.hp=10000;enemy.max_hp=10000;enemy.guns=[];enemy.mission_controlled=true
				if not friendly:enemy.role="friendly"
				for reward in db.kind("TurretLevelUpReward"):
					if core.id in reward.get("coresList",[]):body.levels[reward.id]=rank
				body.refresh_upgrades()
				var chips={} if rank==0 else {1:mini(rank,2),2:mini(rank,2),3:mini(rank,2),4:mini(rank,2),5:mini(rank,2),6:mini(rank,2)}
				var projectile=db.asset(core.coreProjectile)
				if projectile.get("class")=="ContinuousProjectile":battle.special.continuous(core,Vector2.ZERO,Vector2.RIGHT,friendly,chips,rank*.25,.1,"audit")
				else:battle.fire(core,Vector2.ZERO,Vector2.RIGHT,friendly,chips,rank*.25)
				layer.begin_frame(0.2);fx.draw_count=0
				for bullet in battle.bullets:fx.paint_projectile(board,bullet,.2,1)
				for effect in battle.effects:fx.paint_effect(board,effect,1)
				check(submitted(family,not friendly),"%s rank%d %s submits shader geometry"%[core.name,rank,"friendly" if friendly else "hostile"])
	check(count==32 and families.size()==12,"All 32 HQ/player/AI gun cores and 12 families enumerated")
	for family in Feedback.PROFILES:
		for friendly in [true,false]:
			for kind in ["muzzle","hit","shield_hit","explosion","chain","flame","emp","mine_arm","hole_birth","hole_collapse","viscous_contact","egg_burst"]:
				layer.begin_frame(.4)
				var event={"kind":kind,"fx_family":family,"friendly":friendly,"position":Vector2.ZERO,"end":Vector2(120,0),"direction":Vector2.RIGHT,"normal":Vector2.LEFT,"radius":24.0,"life":.12,"fx_duration":.3,"organic_family":"egg","owner":"audit"}
				fx.paint_effect(board,event,1)
				check(submitted(family,not friendly),"%s/%s/%s routes lifecycle shader"%[family,kind,str(friendly)])
	for friendly in [true,false]:
		layer.begin_frame(.5)
		fx.paint_hole(board,{"position":Vector2.ZERO,"radius":90,"friendly":friendly,"life":2.0},1)
		check(submitted("blackhole",not friendly),"Persistent black hole shader "+str(friendly))
	# Resource identity remains constant through reuse and paused-time frames.
	var ids=layer.materials.values().map(func(m):return m.get_instance_id())
	for i in 120:layer.begin_frame(3.0)
	check(ids==layer.materials.values().map(func(m):return m.get_instance_id()),"120 frames reuse the fixed shader materials")
	check(layer.stats().commands==0,"New frame clears stale geometry")
	check(layer.materials.values().all(func(m):return is_equal_approx(float(m.get_shader_parameter("clock")),3.0)),"Explicit simulation clock supports pause")
	await passive_checks(db)
	await control_checks(db)
	await support_route_checks(db)
	var roster=load("res://scripts/character_roster.gd")
	check(roster.ids()==["centipede","spider"],"Retired beetle remains excluded")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed),"core_count":count,"families":families.keys(),"renderer":DisplayServer.get_name(),"scope":"Actual production combat and shader command submission. Does not certify GPU compilation or visual quality."}
	FileAccess.open("res://artifacts/skill-shader-coverage-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"passed":report.passed,"checks":checks.size(),"core_count":count,"failures":checks.filter(func(c):return not c.passed)}))
	board.queue_free();await process_frame;quit(0 if report.passed else 1)

func paint_passive(passive,body,battle):
	passive.update_transitions(body,.25)
	board.job=func():passive.paint(board,body,battle,1)
	board.queue_redraw();await process_frame;await process_frame
	board.job=Callable()
func passive_checks(db):
	var passive=load("res://scripts/passive_feedback.gd").new();passive.living=RecordedPassive.new();passive.setup(board)
	for core in db.kind("ShieldCore"):
		var body=Body.new(db);body.set_hq_weapon(core.id)
		var battle=Battle.new(db,body)
		await paint_passive(passive,body,battle)
		check(passive.living.counts[0]==1,core.name+" live shield submits MultiMesh instance")
		var mm:MultiMesh=passive.living.nodes[0].multimesh
		check(passive.living.nodes[0].material is ShaderMaterial and mm.visible_instance_count==1,core.name+" real visible ShaderMaterial batch")
		for axis in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			body.parts[0].shield=10000
			var shot={"origin":body.head+axis*1000,"previous":body.head+axis*100,"position":body.head,"velocity":-axis*600,"radius":4.0,"friendly":false,"damage":1.0,"shield_damage":1.0,"fx_family":"gatling","data":{}}
			battle.hurt_player(0,1,1,shot)
			await paint_passive(passive,body,battle)
			var contact=passive.living.payloads[0].event
			check(Vector2(contact.r,contact.g).dot(axis)>.8 and contact.b>0,core.name+" directional hit ripple "+str(axis))
		battle.hurt_player(0,1,999999)
		await paint_passive(passive,body,battle)
		check(passive.living.payloads[0].event.a>0 and passive.living.payloads[0].state.r==0,core.name+" depleted shield submits breaking phase")
		body.step_feedback(1)
		await paint_passive(passive,body,battle)
		check(passive.living.counts[0]==0,core.name+" exhausted break removes membrane")
		battle.step(body.parts[0].shield_delay+.01,Vector2.ZERO,false,false)
		await paint_passive(passive,body,battle)
		check(passive.living.counts[0]==1 and passive.living.payloads[0].state.g>0,core.name+" actual recharge drives shader")
	for core in db.kind("ShieldCore").filter(func(c):return str(c.name).begins_with("Core_AI_")):
		passive.reset()
		var body=Body.new(db);var battle=Battle.new(db,body)
		var enemy=battle.spawn(db.pool["250"],Vector2(100,0));enemy.hp=10000;enemy.mission_controlled=true
		enemy.guns=[{"id":core.id,"shield":float(core.maxShieldHealth),"shield_delay":0.0,"offset":Vector2.ZERO,"angle":0.0,"cooldown":0.0}]
		await paint_passive(passive,body,battle)
		check(passive.living.counts[0]==1 and passive.living.payloads[0].state.b==1,core.name+" enemy membrane uses hostile shader state")
		for axis in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			enemy.guns[0].shield=10000
			var shot={"origin":enemy.position+axis*1000,"previous":enemy.position+axis*100,"position":enemy.position,"velocity":-axis*600,"radius":4.0,"friendly":true,"damage":1.0,"shield_damage":1.0,"fx_family":"gatling","data":{"class":"BasicProjectile"},"chips":{},"pierce":1}
			battle.hit_enemy(enemy,shot)
			await paint_passive(passive,body,battle)
			var contact=passive.living.payloads[0].event
			check(Vector2(contact.r,contact.g).dot(axis)>.8 and contact.b>0,core.name+" enemy real hit direction "+str(axis))
		enemy.guns[0].shield=0
		await paint_passive(passive,body,battle)
		check(passive.living.payloads[0].event.a>0,core.name+" enemy break history submits dissolve")
		passive.clock+=1
		await paint_passive(passive,body,battle)
		check(passive.living.counts[0]==0,core.name+" enemy break expires")
		enemy.guns[0].shield=float(core.maxShieldHealth)*.5
		await paint_passive(passive,body,battle)
		check(passive.living.payloads[0].state.g>0,core.name+" enemy refill submits recharge front")
	for core in db.catalog.values():
		var mode=-1
		if core.get("class")=="ChipCore":mode=3
		elif core.get("class")=="FuelCore":mode=4
		elif core.get("class")=="RepairCore":mode=2
		elif core.get("class") in ["WallCore","PackCore"]:mode=1
		if mode<0:continue
		var body=Body.new(db);body.append_segment(core.id);var battle=Battle.new(db,body)
		await paint_passive(passive,body,battle)
		check(passive.living.counts[mode]>0,core.name+" installed passive submits expected shader mode")
	var body=Body.new(db);body.append_segment(db.named("Core_Gun_Gatling").id);body.append_segment(db.named("Core_Clocking").id)
	var battle=Battle.new(db,body);battle.special.step(.01)
	await paint_passive(passive,body,battle)
	check(passive.living.counts[5]>0,"Actual cloak coverage drives interference shader")
	body.parts[2].hp=0;battle.special.step(.01)
	await paint_passive(passive,body,battle)
	check(passive.living.counts[5]==0,"Destroyed cloak source removes interference")
	body=Body.new(db);battle=Battle.new(db,body);battle.request_skill(Vector2.RIGHT*120);body.step(.1,Vector2.ZERO,false)
	await paint_passive(passive,body,battle)
	check(passive.living.counts[1]>0,"Centipede coil enters shader-backed armor state")
	check(passive.living.material_count==6 and passive.living.nodes.size()==6,"Passive resources remain six fixed batches")
	passive.reset()
	check(passive.living.nodes.all(func(n):return n.multimesh.visible_instance_count==0),"Reset removes all stale passive geometry")
func control_checks(db):
	var body=Body.new(db);body.configure_character("spider");var battle=Battle.new(db,body)
	var enemy=battle.spawn(db.pool["250"],body.head+Vector2(150,0))
	enemy.hp=1000;enemy.guns=[];enemy.kind="AISwarmingUnit";enemy.unit={"canBeStunned":true};enemy.parent=0;enemy.mission_controlled=false
	check(battle.request_skill(enemy.position),"Spider skill activates through actual combat")
	layer.begin_frame(.2)
	load("res://scripts/character_art.gd").draw_skill(board,body,battle.character_abilities.state(),board.world(body.head),1,.2)
	check(submitted("silk",false),"Actual spider target threads submit silk shader")
	battle.character_abilities.finish();layer.begin_frame(.4)
	load("res://scripts/character_art.gd").draw_skill(board,body,battle.character_abilities.state(),board.world(body.head),1,.4)
	check(submitted("silk",false),"Finished spider skill renders its released recoil thread")
	for frame in 8:battle.character_abilities.update(.1)
	layer.begin_frame(1.2)
	load("res://scripts/character_art.gd").draw_skill(board,body,battle.character_abilities.state(),board.world(body.head),1,1.2)
	check(not submitted("silk",false),"Recoil completion removes all spider thread geometry")
	for kind in ["silk","tendril"]:
		var controls=load("res://scripts/insect_controls.gd").new()
		enemy.erase("insect_control");enemy.erase("insect_recovery_until")
		check(controls.attach(enemy,{"insect_attack":kind,"friendly":true,"origin":body.head}),kind+" actual control attaches")
		layer.begin_frame(.5)
		load("res://scripts/insect_attack_fx.gd").paint(board,controls.active,1)
		check(submitted(kind,false),kind+" active control submits shader geometry")
		controls.advance(2,battle);layer.begin_frame(.7)
		load("res://scripts/insect_attack_fx.gd").paint(board,controls.active,1)
		check(not submitted(kind,false),kind+" expiry removes shader geometry")

func support_route_checks(db):
	var body=Body.new(db);body.append_segment(db.named("Core_Drones_Engineer").id)
	var battle=Battle.new(db,body);battle.drones.clear()
	body.parts[0].hp-=10.0
	battle.add_drone(1,db.named("Drones_Core_Engineer"))
	var drone=battle.drones[0];drone.ping=0;drone.position=body.parts[0].position
	battle.step_drones(.01)
	check(drone.mode=="repair" and body.parts[0].feedback_pulses.has("healed"),"Repair tether fixture follows actual healing event")
	var passive=load("res://scripts/passive_feedback.gd").new();passive.setup(board)
	layer.begin_frame(.4);await paint_passive(passive,body,battle)
	check(submitted("repair_drone",false),"Active healing at zero-distance contact submits repair shader")
	body.parts[0].hp=body.parts[0].max_hp;battle.step_drones(.01)
	layer.begin_frame(.5);await paint_passive(passive,body,battle)
	check(not submitted("repair_drone",false),"Finished repair removes feeding tether")
	var native=load("res://scripts/native_visuals.gd").new()
	var particles=load("res://scripts/particle_effects.gd").new();native.setup(db,particles)
	for friendly in [true,false]:
		layer.begin_frame(.6)
		var data=db.named("Drones_Core_Attack" if friendly else "Drones_AI_Attack")
		var actor={"position":Vector2.ZERO}
		native.trail(board,actor,data.dronePrefab,.1,1.0,not friendly)
		actor.position=Vector2(35,0)
		native.trail(board,actor,data.dronePrefab,.12,1.0,not friendly)
		check(submitted("drone",not friendly),"Actual native drone trail preserves shader ownership "+str(friendly))
		var enemy=battle.spawn(db.pool["250"],Vector2(150,0));enemy.hp=10000;enemy.max_hp=10000;enemy.guns=[];enemy.unit={"canBeStunned":true}
		enemy.role="hostile" if friendly else "friendly"
		var projectile=db.asset(db.named("Core_Gun_EMP").coreProjectile)
		var shot={"data":projectile,"origin":Vector2.ZERO,"position":enemy.position,"velocity":Vector2.RIGHT*400,"radius":4,"friendly":friendly,"damage":1,"shield_damage":1,"chips":{},"pierce":1,"fx_family":"emp"}
		battle.effects.clear();battle.hit_enemy(enemy,shot)
		var statuses=battle.effects.filter(func(effect):return effect.kind=="emp")
		check(statuses.size()==1 and statuses[0].friendly==friendly and statuses[0].fx_family=="emp" and statuses[0].fx_duration==statuses[0].life,"Actual EMP stun preserves source ownership and visual lifetime "+str(friendly))
		layer.begin_frame(.7)
		for effect in statuses:fx.paint_effect(board,effect,1.0)
		check(submitted("emp",not friendly),"EMP status submits correct shader batch "+str(friendly))
	particles.free()
