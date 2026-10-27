extends "res://tests/test_enemy_core_frame.gd"
## Run after applying artifacts/cpu3-absent-knockback.patch. This test does not
## patch runtime files or access a player save.
const Push=preload("res://scripts/knockback.gd")
const Controls=preload("res://scripts/insect_controls.gd")
const CharacterBody=preload("res://scripts/chain_centipede.gd")

func control_shot(db,kind:String)->Dictionary:
	var core=db.named("Core_Gun_EMP" if kind=="silk" else "Core_Gun_Tesla")
	return {"data":db.asset(core.coreProjectile),"insect_attack":kind,"friendly":true,"origin":Vector2.ZERO,"position":Vector2.ZERO,"velocity":Vector2.RIGHT*480,"damage":1.0,"shield_damage":1.0,"chips":{},"pierce":1,"hit":[]}

func wave(db,at:Vector2,friendly:bool)->Dictionary:
	return {"data":db.asset(db.named("Core_Gun_SonicWave").coreProjectile),"damage":2.0,"shield_damage":2.0,"friendly":friendly,"chips":{},"velocity":Vector2.RIGHT*480,"position":at,"previous":at-Vector2(30,0),"origin":at-Vector2(300,0),"radius":4.0,"pierce":1,"hit":[]}

func complete_state(battle,body,actors:Array)->Dictionary:
	var result=snapshot(battle,body)
	result.merge({"head":body.head,"statistics":battle.statistics,"loot":battle.loot,"loot_rng":battle.loot_rng.state,"destroyed":battle.destroyed,"projectile_trails":battle.projectile_trails,"released_controls":battle.insect_control_system.released,"emitter_poses":battle.insect_control_system.emitter_poses,"control_clock":battle.insect_control_system.elapsed,"control_serial":battle.insect_control_system.serial,"fixture_actors":actors},true)
	return result.duplicate(true)

func execute():
	var comparisons=0;var differences:Array=[];var coverage:Array=[]
	# The shortcut must only apply to a genuinely absent field. Keep ZERO,
	# tiny, active and nonfinite present values on the original path.
	var raw_controls=Controls.new();var opt_controls=Controls.new()
	raw_controls.use_absent_knockback=false;opt_controls.use_absent_knockback=true
	for velocity in [null,Vector2.ZERO,Vector2(1e-9,-1e-9),Vector2(100,-30),Vector2(NAN,0),Vector2(INF,-INF)]:
		for dt in [0.0,-.01,.016,.1]:
			for controlled in [false,true]:
				var e={"hp":100.0,"warp":0.0,"kind":"AISwarmingUnit","role":"","damageable":true,"parent":0,"mission_controlled":false,"unit":{"canBeStunned":true}}
				if velocity!=null:e.knockback_velocity=velocity
				if controlled:e.insect_control=1;e.insect_control_friendly=true;e.insect_silk_until=.03
				var before=var_to_bytes(e)
				var expected=raw_controls.movement_factor(e,dt);var actual=opt_controls.movement_factor(e,dt)
				check(var_to_bytes(expected)==var_to_bytes(actual),"Drive factor byte equality for present/absent/nonfinite velocity and control")
				check(var_to_bytes(e)==before,"Drive factor never mutates the actor")
	for character in ["centipede","spider"]:
		for with_terrain in [false,true]:
			var reference:Array=[]
			for optimized in [false,true]:
				var db=DB.new()
				preload("res://scripts/projectile_trails.gd").next_visual_id=0
				var body=CharacterBody.new(db);body.configure_character(character)
				var battle=Battle.new(db,body)
				battle.use_absent_knockback=optimized;battle.insect_control_system.use_absent_knockback=optimized
				if with_terrain:battle.terrain=NudgeWorld.new()
				for part in body.parts:part.hp=10000000;part.max_hp=10000000
				var actors:Array=[]
				for i in 8:
					var at=Vector2(400+i*43,70+i*17) if i<7 else Vector2(-12345.6787,9045.8760)
					var e=battle.spawn(db.pool["250"],at)
					e.kind="AISwarmingUnit";e.components=[];e.unit={"canBeStunned":true};e.hp=1000000;e.max_hp=1000000;e.warp=0
					e.movement={"enginePower":.25,"rotEngineModifier":20.0};e.stop_distance=0;e.guns=[]
					e.angle=Vector2(e.position).direction_to(body.head).angle()
					if i==0:e.guns=[gun(str(db.named("Core_Gun_Gatling").id),0)]
					actors.append(e)
				actors[1].knockback_velocity=Vector2.ZERO
				actors[2].knockback_velocity=Vector2(1e-9,-1e-9)
				actors[3].knockback_velocity=Vector2(100,-30)
				actors[4].kind="AIStationPartController";actors[4].knockback_velocity=Vector2(NAN,INF)
				actors[5].parent=actors[0].uid;actors[5].kind="AIBossPartController";actors[5].offset=Vector2(28,20);actors[5].knockback_velocity=Vector2(20,0)
				actors[6].mission_controlled=true;actors[6].knockback_velocity=Vector2(20,0)
				var enemy_impulse=false;var player_impulse=false;var silk=false;var tendril=false
				for tick in 120:
					var dt:float=[0.0,1.0/120,1.0/60,1.0/30,.009,.04][tick%6]
					if tick==4:actors[2].stun=.08;actors[2].knockback_velocity=Vector2(100,10)
					if tick==9:actors[3].warp=.07;actors[3].knockback_velocity=Vector2(90,0)
					if tick==15:
						battle.push_enemy(actors[0],Vector2.RIGHT,1.5);enemy_impulse=actors[0].has("knockback_velocity")
					if tick==20:
						battle.hit_player(0,wave(db,body.head,false));player_impulse=body.parts[0].has("knockback_velocity")
					if tick==25:silk=battle.insect_control_system.attach(actors[1],control_shot(db,"silk"))
					if tick==35:tendril=battle.insect_control_system.attach(actors[2],control_shot(db,"tendril"))
					if tick==60:actors[3].despawn=true;actors[3].knockback_velocity=Vector2(40,0)
					if tick==70:actors[4].knockback_velocity=Vector2.ZERO
					if tick==90:actors[0].knockback_velocity=Vector2.ZERO
					battle.step(dt,Vector2(500,0),false,false)
					var state=complete_state(battle,body,actors)
					if not optimized:reference.append(state)
					else:
						comparisons+=1
						if state!=reference[tick] and differences.size()<12:differences.append({"character":character,"terrain":with_terrain,"tick":tick})
				coverage.append({"character":character,"terrain":with_terrain,"optimized":optimized,"enemy_impulse":enemy_impulse,"player_impulse":player_impulse,"silk":silk,"tendril":tendril,"shots":battle.shot_serial})
	check(differences.is_empty(),"All full actor/player/control/weapon/feedback/spatially constrained motion and gameplay RNG snapshots are exactly equal")
	check(coverage.all(func(row):return row.enemy_impulse and row.player_impulse and row.silk and row.tendril and row.shots>0),"Each lane exercises real enemy/player impulses, silk, tendril and firing")
	var passed=checks.all(func(c):return c.passed)
	var report={"passed":passed,"checks":checks,"exact_state_comparisons":comparisons,"differences":differences,"coverage":coverage,"scope":"Missing-key optimization versus original predicate/drive path; exact full-state/RNG snapshots with variable dt, both characters, collision-adjusted positions, present ZERO/tiny/active/nonfinite velocities, immutable/parent/mission/stun/warp/despawn paths and real impulse/control lifecycles. The existing movement position subtraction/multiply/add is untouched. No timing or FPS assertion."}
	FileAccess.open("res://artifacts/absent-knockback-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if passed else 1)
