extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/centipede.gd")
const Battle=preload("res://scripts/combat.gd")
func _initialize():call_deferred("execute")
func snapshot(battle)->Dictionary:
	return {"actors":battle.enemies.map(func(e):return [e.uid,e.position,e.angle,e.hp,e.guns]),"bullets":battle.bullets,"drones":battle.drones,"hits":battle.hit_count,"rng":battle.rng.state}.duplicate(true)
func execute():
	var db=DB.new();var traces:Array=[]
	for optimized in [false,true]:
		preload("res://scripts/projectile_trails.gd").next_visual_id=0
		var body=Body.new(db);var battle=Battle.new(db,body);battle.use_incremental_refresh=optimized
		for name in ["Core_Gun_Tesla","Core_Gun_EMP","Core_Drones_Attack"]:body.append_segment(db.named(name).id)
		for part in body.parts:part.hp=100000;part.max_hp=100000
		for i in 16:
			var enemy=battle.spawn(db.pool["250"],Vector2(180+i*21,60*sin(i)))
			enemy.hp=10000;enemy.max_hp=10000;enemy.warp=0
		# Attached parts must follow their owner even when controls move it late.
		var parent:Dictionary=battle.enemies[0];var child:Dictionary=battle.enemies[1]
		child.parent=parent.uid;child.offset=Vector2(0,25);parent.parts.append(child.uid)
		battle.terrain=preload("res://scripts/chasm_world.gd").new()
		var trace:Array=[]
		for tick in 180:
			if tick%60==0:battle.insect_control_system.attach(parent,{"insect_attack":"tendril","friendly":true,"origin":Vector2.ZERO})
			if tick==75:battle.spawn(db.pool["250"],Vector2(300,30))
			if tick==120:battle.enemies[-1].hp=0
			battle.step(1.0/60,Vector2(300,0),true)
			trace.append(snapshot(battle))
		traces.append(trace)
	var same=traces[0]==traces[1]
	var report={"passed":same,"ticks":180,"scope":"Full-rate versus incremental spatial refresh: identical actors, gun state, bullets, drones, hits and RNG throughout normal combat, pull constraints, attached pieces, spawning and death."}
	if not same:
		for i in traces[0].size():
			if traces[0][i]!=traces[1][i]:report.first_difference={"frame":i,"before":traces[0][i],"after":traces[1][i]};break
	FileAccess.open("res://artifacts/combat-incremental-refresh-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if same else 1)
