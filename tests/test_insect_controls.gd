extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/grid_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Controls = preload("res://scripts/insect_controls.gd")
var checks: Array = []
var db
func check(ok: bool, title: String):
	checks.append({"name":title,"passed":ok})
	if not ok: printerr("FAIL: ",title)
func _initialize(): call_deferred("execute")
func fixture():
	var body=Body.new(db)
	for p in body.parts: p.cooldown=1000.0
	return Battle.new(db,body)
func actor(battle, at=Vector2(500,0), role="") -> Dictionary:
	var e=battle.spawn(db.pool["250"],at)
	e.hp=100000.0;e.max_hp=e.hp;e.guns=[];e.components=[]
	e.kind="AISwarmingUnit";e.movement={"enginePower":2.0,"rotEngineModifier":12.0}
	e.unit={"canBeStunned":true};e.stop_distance=0.0;e.angle=PI;e.role=role
	return e
func shot(kind: String, friendly=true) -> Dictionary:
	var core=db.named("Core_Gun_EMP" if kind=="silk" else "Core_Gun_Tesla")
	return {"data":db.asset(core.coreProjectile),"insect_attack":kind,"friendly":friendly,"origin":Vector2.ZERO,"position":Vector2.ZERO,"velocity":Vector2.RIGHT*480,"damage":1.0,"shield_damage":1.0,"chips":{},"pierce":1,"hit":[]}
func execute():
	db=DB.new()
	for hz in [30,60,120]:
		var battle=fixture();var e=actor(battle)
		battle.hit_enemy(e,shot("silk"))
		check(e.stun==0 and battle.insect_controls.size()==1,"Silk binds without disabling weapons at %dHz"%hz)
		for frame in range(hz): battle.step(1.0/hz,Vector2.RIGHT,false)
		check(absf(e.position.x-(500-96*.48))<0.03,"Silk changes actual AI displacement with frame-independent expiry at %dHz"%hz)
		check(battle.insect_controls.is_empty() and not e.has("insect_control"),"Silk expires and releases actor at %dHz"%hz)
		check(not battle.insect_control_system.attach(e,shot("silk")),"Recovery rejects immediate rebind at %dHz"%hz)
		battle.insect_control_system.advance(0.71,battle)
		check(battle.insect_control_system.attach(e,shot("silk")),"Recovery eventually allows a new bind at %dHz"%hz)
		battle=fixture();e=actor(battle)
		battle.hit_enemy(e,shot("tendril"))
		for frame in range(hz): battle.insect_control_system.advance(1.0/hz,battle)
		check(absf(e.position.x-436)<0.01 and battle.insect_controls.is_empty(),"Tendril really pulls exactly its 64px budget at %dHz"%hz)
	var battle=fixture();var e=actor(battle,Vector2(100,0))
	e.guns=[{"id":db.named("Core_Gun_Gatling").id,"cooldown":0.0,"angle":PI}]
	battle.hit_enemy(e,shot("silk"));battle.step(0.01,Vector2.RIGHT,false)
	check(battle.bullets.any(func(b):return not b.friendly),"Bound enemies still really fire their weapons")
	battle=fixture();e=actor(battle)
	battle.hit_enemy(e,shot("tendril"))
	for frame in range(60): battle.step(1.0/60,Vector2.RIGHT,false)
	check(absf(e.position.x-340)<.03,"Full combat integrates AI motion and64px tether displacement")
	battle=fixture();e=actor(battle)
	battle.insect_control_system.attach(e,shot("silk"))
	for i in range(100): battle.insect_control_system.attach(e,shot("silk"))
	check(battle.insect_controls.size()==1 and battle.insect_controls[0].life==Controls.SILK_DURATION,"Repeated hits neither stack nor refresh silk")
	battle.insect_control_system.advance(10,battle)
	check(battle.insect_controls.is_empty() and battle.insect_control_system.movement_factor(e,0.1)==1,"Large delta fully releases silk")
	battle=fixture();e=actor(battle,Vector2(60,0))
	battle.insect_control_system.attach(e,shot("tendril"));battle.insect_control_system.advance(5,battle)
	check(e.position.x>=48 and battle.insect_controls.is_empty(),"Large delta pull stops outside contact distance")
	battle=fixture();e=actor(battle)
	var ally=actor(battle,Vector2(600,0),"friendly")
	check(not battle.insect_control_system.attach(ally,shot("silk")),"Friendly shots cannot bind allies")
	check(not battle.insect_control_system.attach(e,shot("tendril",false)),"Hostile shots cannot pull their own team")
	check(battle.insect_control_system.attach(ally,shot("tendril",false)),"Hostile control may affect opposing allied actors")
	ally.role="";battle.insect_control_system.advance(0.1,battle)
	check(battle.insect_controls.is_empty() and ally.position.x==600,"Ownership changes cancel active control before movement")
	for kind in ["AIBossUnit","AIBossPartController","AIStation","Asteroid"]:
		e.kind=kind
		check(not battle.insect_control_system.attach(e,shot("silk")),kind+" resists binding")
	e.kind="AISwarmingUnit";e.mission_controlled=true
	check(not battle.insect_control_system.attach(e,shot("tendril")),"Mission-controlled actors cannot be displaced")
	e.mission_controlled=false;e.unit.canBeStunned=false
	check(not battle.insect_control_system.attach(e,shot("silk")),"Source stun immunity is respected")
	battle=fixture()
	for i in range(Controls.MAX_ACTIVE+12): battle.insect_control_system.attach(actor(battle,Vector2(500+i*8,0)),shot("silk"))
	check(battle.insect_controls.size()==Controls.MAX_ACTIVE,"Active controls have a hard global cap")
	for c in battle.insect_controls: c.target.hp=0
	battle.insect_control_system.advance(0.01,battle)
	check(battle.insect_controls.is_empty(),"Dead targets release every control slot")
	battle=fixture();e=actor(battle)
	battle.fire(db.named("Core_Gun_EMP"),Vector2.ZERO,Vector2.RIGHT,true)
	var b: Dictionary=battle.bullets[0]
	check(b.insect_attack=="silk","Real EMP firing attaches silk gameplay identity")
	battle.hit_enemy(e,b)
	check(battle.insect_controls.size()==1 and e.hp<e.max_hp,"Real EMP projectile deals damage and creates silk")
	battle=fixture();e=actor(battle,Vector2(100,0))
	battle.player.install_module(db.named("Core_Gun_Tesla").id,1,4)
	battle.player.install_module(db.named("Core_Gun_Gatling").id,2,4)
	battle.fire(db.named("Core_Gun_Tesla"),Vector2.ZERO,Vector2.RIGHT,true,{},0,false,0,1,"player:1")
	check(battle.insect_controls.size()==1 and battle.insect_controls[0].kind=="tendril","Real Tesla hits create a tendril")
	var origin_part: Dictionary=battle.player.parts[1]
	battle.player.parts[1]=battle.player.parts[2];battle.player.parts[2]=origin_part
	battle.insect_control_system.advance(.01,battle)
	check(battle.insect_controls.size()==1 and battle.insect_controls[0].origin==battle.player.weapon_origin(2),"Stable source token follows source when part indices change")
	battle.player.parts.remove_at(2);battle.insect_control_system.advance(.01,battle)
	check(battle.insect_controls.is_empty(),"Removing the originating organ releases its tether")
	battle=fixture();e=actor(battle)
	var shield=db.kind("ShieldCore")[0]
	e.guns=[{"id":shield.id,"shield":float(shield.maxShieldHealth)}]
	battle.hit_enemy(e,shot("silk"))
	check(battle.insect_controls.is_empty() and e.hp==e.max_hp,"Shields intercept silk before control and hull damage")
	battle=fixture();e=actor(battle)
	battle.insect_control_system.attach(e,shot("silk"));e.warp=1.0
	battle.insect_control_system.advance(.01,battle)
	check(battle.insect_controls.is_empty(),"Warping cancels control rather than dragging a teleported target")
	battle=fixture();e=actor(battle)
	battle.insect_control_system.attach(e,shot("tendril"));battle.enemies.erase(e)
	battle.insect_control_system.advance(.01,battle)
	check(battle.insect_controls.is_empty(),"Despawned targets release tether references")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/insect-controls-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
