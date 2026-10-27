extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/centipede.gd")
const Battle=preload("res://scripts/combat.gd")
var checks:Array=[]

func _initialize():call_deferred("execute")

func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)

func indexed(battle)->bool:
	if battle.spatial.by_uid.size()!=battle.enemies.size():return false
	for i in battle.enemies.size():
		if battle.spatial.by_uid.get(battle.enemies[i].uid,-1)!=i:return false
	return true

func snapshot(battle,body)->Dictionary:
	return {"actors":battle.enemies,"bullets":battle.bullets,"drones":battle.drones,"enemy_drones":battle.enemy_drones,"loot":battle.loot,"parts":body.parts,"hits":battle.hit_count,"kills":battle.kills,"statistics":battle.statistics,"rng":battle.rng.state,"loot_rng":battle.loot_rng.state}.duplicate(true)

func execute():
	var db=DB.new();var body=Body.new(db);var battle=Battle.new(db,body)
	battle.use_uid_mutation_hints=true
	for i in 4:battle.spawn(db.pool["250"],Vector2(400+i*80,50))
	check(indexed(battle),"Spawning while the broadphase is inactive immediately adds every UID hint")
	var last:Dictionary=battle.enemies.back()
	battle.refresh_spatial();battle.enemies.pop_front()
	check(is_same(battle.entity(last.uid),last) and not battle.spatial_active,"A stale slot from an external removal finds the exact live dictionary and invalidates stale cells")
	check(battle.spatial.by_uid[last.uid]==battle.enemies.size()-1,"Fallback repairs the found UID in constant time for following calls")
	battle.reindex_entity_hints()
	check(indexed(battle),"The layout hook rebuilds a complete exact map only when called")
	battle.refresh_spatial();var first:Dictionary=battle.enemies[0];battle.enemies.reverse()
	check(is_same(battle.entity(first.uid),first) and not battle.spatial_active,"Same-array same-size reorders validate the cached UID before returning an actor")
	battle.reindex_entity_hints();battle.refresh_spatial()
	var external:Array=battle.enemies.duplicate();external.reverse();battle.enemies=external
	check(is_same(battle.entity(last.uid),last),"An external replacement keeps strict actor identity during a stale lookup")
	battle.reindex_entity_hints();battle.refresh_spatial()
	check(battle.entity(-12345).is_empty() and battle.spatial_active,"An absent UID in an intact active index stays a constant-time miss")
	battle.spatial_active=false;battle.enemies.clear();battle.reindex_entity_hints()
	check(indexed(battle) and battle.entity(first.uid).is_empty(),"Clearing the layout removes stale UID hints")
	var reference:Array=[];var differences:Array=[];var comparisons=0
	for optimized in [false,true]:
		preload("res://scripts/projectile_trails.gd").next_visual_id=0
		body=Body.new(db);battle=Battle.new(db,body);battle.use_uid_mutation_hints=optimized
		for name in ["Core_Gun_Tesla","Core_Gun_EMP"]:body.append_segment(db.named(name).id)
		for part in body.parts:part.hp=100000;part.max_hp=100000
		for i in 12:
			var enemy=battle.spawn(db.pool["250"],Vector2(180+i*27,70*sin(i)))
			enemy.hp=10000;enemy.max_hp=10000;enemy.warp=0
		var parent:Dictionary=battle.enemies[0];var child:Dictionary=battle.enemies[1]
		child.parent=parent.uid;child.offset=Vector2(0,25);parent.parts.append(child.uid)
		battle.terrain=preload("res://scripts/chasm_world.gd").new()
		for tick in 240:
			if tick==45 or tick==125:battle.spawn(db.pool["250"],Vector2(250,35))
			if tick==85:battle.enemies[3].hp=0
			if tick==105:battle.enemies[4].despawn=true
			if tick==145:
				var removed_uid=int(battle.enemies[5].uid)
				battle.enemies=battle.enemies.filter(func(e):return e.uid!=removed_uid)
				battle.reindex_entity_hints()
			battle.step([1.0/60,1.0/30,.008,.023][tick%4],Vector2(300,0),true)
			var state=snapshot(battle,body)
			if not optimized:reference.append(state)
			else:
				comparisons+=1
				if state!=reference[tick]:differences.append(tick)
			if optimized and tick in [45,85,105,125,145]:check(indexed(battle),"Live layout stays indexed after spawn/death/despawn/unload tick %d"%tick)
	check(differences.is_empty(),"Full combat state remains identical with variable dt, spawning, death, despawn, attached parts and map-style removal")
	var passed=checks.all(func(c):return c.passed)
	var report={"passed":passed,"checks":checks,"exact_state_comparisons":comparisons,"different_frames":differences,"scope":"UID hint mutation maintenance and stale-index fallback; no AI cadence, ordering, spawning, targeting, collision or visual state changes. No performance/FPS assertion."}
	FileAccess.open("res://artifacts/deep50-entity-uid-hints.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if passed else 1)
