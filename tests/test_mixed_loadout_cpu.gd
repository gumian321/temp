extends SceneTree
## CPU attribution only, not FPS. Same physical cave/body and initial actor
## pressure; suppress one equipment family at a time in a disposable database.
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const World=preload("res://scripts/cave_world.gd")
const Fixture=preload("res://tests/mixed_loadout_fixture.gd")
func _initialize():call_deferred("execute")
func stats(values:Array)->Dictionary:
	values.sort();var total=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))],"max":values[-1]}
func execute():
	var cases={"all":[],"no_mines":["Core_MinesField"],"no_tesla":["Core_Gun_Tesla"],"no_rocket":["Core_Gun_Rocket"],"no_drones":["Core_Drones_Attack","Core_Drones_Engineer","Core_Drones_Scrapper"],"idle":Fixture.names()}
	var requested=OS.get_environment("RBPEW_MIXED_CASE")
	if not requested.is_empty():cases={requested:cases[requested]}
	var results=[]
	for name in cases:
		var db=DB.new();var player=Body.new(db);var world=World.new();world.reset_cave(true)
		player.terrain=world
		var entry=world.wall_hit(Vector2.ZERO,Vector2(1000,0),30)
		player.head=Vector2(entry.position)+Vector2(entry.normal)*.35;player.facing=Vector2.RIGHT
		for i in player.history.size():player.history[i]=player.head-Vector2(i*4,0)
		Fixture.install(player,db)
		for core in cases[name]:
			var c=db.named(core);c.erase("coreProjectile");c["class"]="TurretCore"
		for part in player.parts:part.hp=100000;part.max_hp=100000
		player.motion.reset();player.refresh_positions()
		var battle=Battle.new(db,player)
		battle.profile_enabled=true
		for i in 32:
			var e=battle.spawn(db.pool["250"],Vector2(630+(i%8)*15,(i/8)*25-50))
			e.guns=[];e.components=[];e.warp=0;e.stop_distance=0;e.hp=100000;e.max_hp=100000
		var rows=[];var times=[];var early=[];var late=[];var phase_samples={}
		for tick in 2400:
			battle.phase_times.clear()
			var began=Time.get_ticks_usec()
			var direction=Vector2.RIGHT if tick<180 else Vector2.UP
			player.step(1.0/60,direction,false)
			var split=Time.get_ticks_usec()
			battle.step(1.0/60,player.head+Vector2.RIGHT*500,false)
			var total=float(Time.get_ticks_usec()-began)/1000.0
			var row={"frame":tick,"cpu_ms":total,"body_ms":float(split-began)/1000.0,"phases":battle.phase_times.duplicate(),"actors":battle.enemies.size(),"bullets":battle.bullets.size(),"mines":battle.special.mines.size(),"drones":battle.drones.size(),"loot":battle.loot.size(),"effects":battle.effects.size()}
			rows.append(row)
			if tick>=120:
				times.append(total)
				if tick<600:early.append(total)
				if tick>=1800:late.append(total)
				for key in battle.phase_times:
					if not phase_samples.has(key):phase_samples[key]=[]
					phase_samples[key].append(float(battle.phase_times[key])/1000.0)
			battle.audio_events.clear();player.feedback_events.clear()
		var phases={}
		for key in phase_samples:phases[key]=stats(phase_samples[key])
		var result={"case":name,"cpu_ms":stats(times),"early_cpu_ms":stats(early),"late_cpu_ms":stats(late),"phases_ms":phases,"last":rows[-1],"rows":rows}
		results.append(result)
		print("MIXED_CPU ",JSON.stringify({"case":name,"cpu_ms":result.cpu_ms,"late_cpu_ms":result.late_cpu_ms,"last":result.last}))
	var tag=OS.get_environment("RBPEW_MIXED_TAG")
	if tag.is_empty():tag="latest"
	FileAccess.open("res://artifacts/mixed-loadout-cpu-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"CPU only; no rendering or FPS claim. Screenshot-derived 11 modules, fusion tiers 2/1/1/2/1/1/1/1/1/2/1, 30 mine slots, 32 durable non-shooting cave actors, 40 seconds simulation per case.","results":results},"\t"))
	quit()
