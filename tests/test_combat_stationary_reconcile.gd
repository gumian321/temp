extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Soft=preload("res://scripts/soft_insect.gd")
const STATIC_KINDS=["AIStation","AIStationPartController","AIGuardUnitController","Asteroid","ContainerObject","SpawnerStation"]
var checks:Array=[]
var captured_images=0

func _initialize():call_deferred("execute")

func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)

func first_prefab(db,kind:String)->String:
	for id in db.entities:
		if db.entities[id].any(func(blueprint):return blueprint.unit.get("class")==kind):return id
	return ""

func first_difference(before,after,path:String="state")->Dictionary:
	if before==after:return {}
	if before is Dictionary and after is Dictionary:
		for key in before:
			if not after.has(key):return {"path":path+"."+str(key),"reason":"missing in candidate"}
			var difference=first_difference(before[key],after[key],path+"."+str(key))
			if not difference.is_empty():return difference
		for key in after:
			if not before.has(key):return {"path":path+"."+str(key),"reason":"extra in candidate"}
	elif before is Array and after is Array:
		if before.size()!=after.size():return {"path":path+".size","before":before.size(),"after":after.size()}
		for i in before.size():
			var difference=first_difference(before[i],after[i],path+"["+str(i)+"]")
			if not difference.is_empty():return difference
	return {"path":path,"before":str(before),"after":str(after),"before_type":typeof(before),"after_type":typeof(after)}

func capture_images(value):
	# Mineral erosion creates a separate Image resource for each fixture.
	# Compare its complete visible pixels rather than unrelated Object IDs,
	# and capture bytes now so later erosion cannot mutate an earlier frame.
	if value is Image:
		captured_images+=1
		return {"image_size":value.get_size(),"image_format":value.get_format(),"image_mipmaps":value.has_mipmaps(),"image_bytes":value.get_data()}
	if value is Dictionary:
		for key in value:value[key]=capture_images(value[key])
	elif value is Array:
		for i in value.size():value[i]=capture_images(value[i])
	return value

func snapshot(battle,body)->Dictionary:
	var queries:Array=[]
	for at in [Vector2.ZERO,Vector2(300,0),Vector2(650,120)]:
		queries.append([battle.spatial.query(at-Vector2.ONE*120,at+Vector2.ONE*120).map(func(e):return e.uid),battle.spatial.nearest(at,800).get("uid",0)])
	return capture_images({"actors":battle.enemies,"parts":body.parts,"bullets":battle.bullets,"drones":battle.drones,"enemy_drones":battle.enemy_drones,"loot":battle.loot,"effects":battle.effects,"hits":battle.hit_count,"kills":battle.kills,"statistics":battle.statistics,"rng":battle.rng.state,"loot_rng":battle.loot_rng.state,"controls":battle.insect_control_system.active,"released":battle.insect_control_system.released,"special_holes":battle.special.black_holes,"queries":queries}.duplicate(true))

func execute():
	var db=DB.new();var comparisons=0;var differences:Array=[];var covered:Dictionary={}
	for with_terrain in [false,true]:
		var reference:Array=[]
		for mode in [[false,false],[true,false],[false,true],[true,true]]:
			preload("res://scripts/projectile_trails.gd").next_visual_id=0
			var body=Body.new(db);var battle=Battle.new(db,body)
			battle.use_stationary_root_fastpath=mode[0];battle.use_attached_only_reconcile=mode[1]
			if with_terrain:battle.terrain=preload("res://scripts/chasm_world.gd").new()
			for name in ["Core_Gun_Tesla","Core_Gun_EMP","Core_Gun_SonicWave"]:body.append_segment(db.named(name).id)
			for part in body.parts:part.hp=100000;part.max_hp=100000
			var roots:Array=[]
			for kind in STATIC_KINDS:
				var prefab=first_prefab(db,kind)
				if prefab.is_empty():check(false,"Missing real static prefab "+kind);continue
				for friendly in [false,true]:
					var e=battle.spawn(prefab,Vector2(520+roots.size()*80,110 if friendly else -110),"friendly" if friendly else "map")
					e.mission_controlled=true;e.warp=0;e.hp=100000;e.max_hp=100000
					e.target_mission=roots.size()%2==0
					roots.append(e);covered[kind]=true
			for kind in ["AIPatrolUnit","TraderUnit","AIBossUnit"]:
				var root=battle.spawn(first_prefab(db,kind),Vector2(900,280+roots.size()*11))
				root.mission_controlled=true
			var parent=battle.spawn(db.pool["250"],Vector2(350,90));parent.kind="AISwarmingUnit";parent.components=[];parent.guns=[];parent.movement={"enginePower":0.0};parent.warp=0
			var child=battle.spawn(first_prefab(db,"AIGuardUnitController"),Vector2(375,90));child.parent=parent.uid;child.offset=Vector2(25,0);parent.parts.append(child.uid);child.mission_controlled=true
			var grandchild=battle.spawn(first_prefab(db,"AIGuardUnitController"),Vector2(375,112));grandchild.parent=child.uid;grandchild.offset=Vector2(0,22);child.parts.append(grandchild.uid)
			for e in battle.enemies:e.hp=100000;e.max_hp=100000;e.warp=0
			battle.mission_target=Vector2(100,220)
			for tick in 180:
				var dt:float=[1.0/120,1.0/60,1.0/30,.013,.05][tick%5]
				parent.angle=sin(tick*.021)*PI
				for i in roots.size():
					var e:Dictionary=roots[i]
					battle.move_actor(e,Vector2(e.origin)+Vector2.from_angle(tick*.02+i)*12)
					if tick==35:e.stun=.09
					if tick==55:e.warp=.08
					if tick==75:e.ground_radius=float(e.get("ground_radius",e.radius))+2
					if tick==85:e.knockback_velocity=Vector2(80,20)
				if tick in [15,90,150]:battle.insect_control_system.attach(parent,{"insect_attack":"tendril","friendly":true,"origin":Vector2.ZERO})
				if tick==30:Soft.pull(parent,Vector2.LEFT,120,dt)
				if tick==45:battle.special.black_holes.append({"position":Vector2(280,90),"life":.45,"radius":180.0,"damage":.25,"shield_damage":.25,"friendly":true,"force":80.0})
				if tick==65:battle.push_enemy(parent,Vector2.RIGHT,2.0)
				if tick==105:roots[0].patrol=-1
				if tick==115:roots[0].erase("patrol")
				if tick==125:roots[1].mission_controlled=false
				if tick==135:roots[1].mission_controlled=true
				battle.step(dt,Vector2(500,0),true)
				var state=snapshot(battle,body)
				if mode==[false,false]:reference.append(state)
				else:
					comparisons+=1
					if state!=reference[tick]:differences.append({"terrain":with_terrain,"mode":mode,"tick":tick,"first_difference":first_difference(reference[tick],state)})
			# Explicit external movement must still be supported by the full API.
			parent.position+=Vector2(600,0);battle.refresh_spatial_positions()
			check(battle.area_candidates(parent.position,1).has(parent),"Full reconciliation indexes an externally moved root with terrain=%s mode=%s"%[with_terrain,str(mode)])
	check(covered.size()==STATIC_KINDS.size(),"The differential fixture covers all six static kinds with actual prefab metadata")
	check(differences.is_empty(),"Independent and combined candidates preserve full state under orbit moves, nested children, late tether pulls, soft pulls, black holes, impulses, stun, warp and variable delta")
	var passed=checks.all(func(c):return c.passed)
	var report={"passed":passed,"checks":checks,"exact_state_comparisons":comparisons,"captured_images":captured_images,"differences":differences,"scope":"Four combinations of independently switched stationary mission-root and attached-only step reconciliation candidates. Full actor/weapon/soft/control/projectile/RNG state, ordered targeting, and exact mineral image pixel bytes, both with and without terrain. No frame-rate or performance assertion."}
	FileAccess.open("res://artifacts/deep50-combat-stationary-reconcile.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if passed else 1)
