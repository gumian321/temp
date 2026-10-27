extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/centipede.gd")
const Battle=preload("res://scripts/combat.gd")
class NudgeWorld extends "res://scripts/chasm_world.gd":
	func nearby(_area:Rect2)->Array:return []
	func move(start:Vector2,desired:Vector2,_radius:float)->Vector2:return desired if desired==start else desired+Vector2(0,.75)
	func direction(origin:Vector2,target:Vector2,_radius:float,_memory:Dictionary)->Vector2:return origin.direction_to(target)
var checks:Array=[]

func _initialize():call_deferred("execute")

func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)

func gun(id:String,index:int)->Dictionary:
	return {"id":id,"cooldown":float(index%3)*.03,"angle":.1*index,"offset":Vector2(index*3,-index*2)}

func snapshot(battle,body)->Dictionary:
	return {"actors":battle.enemies,"parts":body.parts,"bullets":battle.bullets,"drones":battle.drones,"enemy_drones":battle.enemy_drones,"effects":battle.effects,"barrages":battle.barrages,"holes":battle.special.black_holes,"whips":battle.special.flame_whips,"hits":battle.hit_count,"rng":battle.rng.state,"shot_serial":battle.shot_serial,"audio":battle.audio_events,"controls":battle.insect_control_system.active}.duplicate(true)

func execute():
	var db=DB.new();var cores:Array=[]
	for name in ["Core_Gun_Gatling","Core_Gun_Rocket","Core_Gun_Tesla","Core_Gun_EMP","Core_Gun_SonicWave","Core_Gun_Flame Thrower","Core_Shield","Core_Drones_Attack"]:
		var core:Dictionary=db.named(name)
		check(not core.is_empty(),"Real weapon fixture exists: "+name)
		cores.append(str(core.get("id","")))
	var comparisons=0;var differences:Array=[];var final_counts:Array=[]
	for with_terrain in [false,true]:
		var reference:Array=[]
		for optimized in [false,true]:
			# Each side receives fresh mutable catalog entries, then the exact
			# same edits at frame boundaries, including replacement dictionaries.
			db=DB.new()
			preload("res://scripts/projectile_trails.gd").next_visual_id=0
			var body=Body.new(db);var battle=Battle.new(db,body);battle.use_enemy_gun_inputs=true;battle.use_enemy_core_frame=optimized
			if with_terrain:battle.terrain=NudgeWorld.new()
			for part in body.parts:part.hp=10000000;part.max_hp=10000000
			var actors:Array=[]
			for i in 4:
				var e=battle.spawn(db.pool["250"],Vector2(180+i*55 if i<2 else 1800+i*55,50+i*25),"friendly" if i%2==1 else "")
				e.components=[];e.unit=e.unit.duplicate(true);e.unit.canBeStunned=true
				e.hp=1000000;e.max_hp=1000000;e.warp=0;e.movement={"enginePower":.25,"rotEngineModifier":20.0}
				e.angle=Vector2(e.position).direction_to(body.head).angle();e.guns=[]
				for j in cores.size():e.guns.append(gun(cores[(j+i)%cores.size()],j))
				actors.append(e)
			# Attached guns use the inherited parent pose, including post-collision
			# changes. The ordinary target distance must remain distinct from delta.
			actors[3].parent=actors[2].uid;actors[3].offset=Vector2(28,20);actors[2].parts.append(actors[3].uid)
			for tick in 150:
				var dt:float=[1.0/120,1.0/60,1.0/30,.009,.04][tick%5]
				if tick==25:actors[0].stun=.08
				if tick==30:db.asset(cores[0]).turretRotateSpeed=17.5
				if tick==35:actors[1].warp=.07
				if tick==40:
					db.catalog[cores[0]]=db.asset(cores[0]).duplicate(true)
					db.asset(cores[0]).turretRange=4
				if tick==45:actors[0].guns[0].id=cores[5]
				if tick==55:
					for e in actors:
						for g in e.guns:
							if db.asset(g.id).get("class")=="ShieldCore":g.shield=0.0;g.shield_broken=true;g.shield_delay=.03
				if tick==60:db.asset(cores[1]).turretErrorAngle=45.0
				if tick==65:battle.push_enemy(actors[0],Vector2.RIGHT,1.0)
				if tick==75:actors[1].guns.append(gun(cores[0],12))
				if tick==80 and not battle.enemy_drones.is_empty():battle.enemy_drones.remove_at(0)
				if tick==85:actors[2].range_modifier=.25
				if tick==90:db.asset(cores[0]).coreProjectile=db.asset(cores[5]).coreProjectile
				if tick==95:actors[0].guns[0].id=cores[0]
				if tick==105:actors[1].guns.remove_at(0)
				if tick==115:actors[0].guns.clear()
				if tick==125:actors[0].guns.append(gun(cores[0],0))
				if tick==130:
					# A previously distant owner enters range with all elapsed
					# turret/cooldown state intact; it must fire on the same tick.
					actors[2].position=Vector2(280,50)
				battle.step(dt,Vector2(500,0),false,false)
				var state=snapshot(battle,body)
				if not optimized:reference.append(state)
				else:
					comparisons+=1
					if state!=reference[tick]:differences.append({"terrain":with_terrain,"tick":tick})
			final_counts.append({"terrain":with_terrain,"optimized":optimized,"shots":battle.shot_serial,"enemy_drones":battle.enemy_drones.size(),"hits":battle.hit_count})
	check(differences.is_empty(),"Per-frame weapon inputs exactly preserve all actors, gun angles/cooldowns/shields, shots, barrage intervals, beams, drones, damage, feedback, controls, audio and RNG")
	check(final_counts.all(func(row):return row.shots>0 and row.enemy_drones>0),"Every fixture exercises real firing and enemy drone creation")
	var passed=checks.all(func(c):return c.passed)
	var report={"passed":passed,"checks":checks,"exact_state_comparisons":comparisons,"differences":differences,"final_counts":final_counts,"scope":"Full hoisted-versus-per-frame enemy gun input differential, mixed live weapon classes and same-frame gun metadata replacement. Variable delta and post-movement collision adjustment; no performance/FPS assertion."}
	FileAccess.open("res://artifacts/deep50-enemy-core-frame.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if passed else 1)
