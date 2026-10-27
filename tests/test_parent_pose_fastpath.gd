extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/centipede.gd")
const Battle=preload("res://scripts/combat.gd")
func _initialize():call_deferred("execute")
func snapshot(battle)->Dictionary:
	return {"actors":battle.enemies,"bullets":battle.bullets,"drones":battle.drones,"enemy_drones":battle.enemy_drones,"hits":battle.hit_count,"statistics":battle.statistics,"rng":battle.rng.state,"parts":battle.player.parts}.duplicate(true)
func execute():
	var db=DB.new();var boss_prefabs:Array=[]
	for id in db.entities:
		if db.entities[id].any(func(b):return b.unit.get("class")=="AIBossUnit"):boss_prefabs.append(id)
	var reference:Array=[];var timings:Array=[];var equal=true;var first_difference={}
	for optimized in [false,true,true,false]:
		preload("res://scripts/projectile_trails.gd").next_visual_id=0
		var body=Body.new(db);var battle=Battle.new(db,body);battle.use_parent_pose_fastpath=optimized;battle.profile_enabled=true
		body.parts[0].hp=1000000;body.parts[0].max_hp=1000000
		battle.terrain=preload("res://scripts/chasm_world.gd").new()
		for i in mini(3,boss_prefabs.size()):battle.spawn(boss_prefabs[i],Vector2(1800+i*500,-1000+i*600))
		var child:Dictionary={};var parent_id=0
		for e in battle.enemies:
			if e.kind=="AIBossPartController" and e.parent!=0:child=e;parent_id=e.parent;break
		var first=reference.is_empty();var sum_us=0
		for tick in 240:
			for e in battle.enemies:
				if e.kind=="AIBossUnit":e.angle=sin(tick*.037)*PI
			if tick==35:child.offset=Vector2(13,-31)
			if tick==55:child.parent=999999
			if tick==75:child.parent=parent_id
			if tick==95:child.stun=.1
			if tick==110:child.warp=.12
			if tick==135:child.role="friendly"
			if tick==160:child.role=""
			if tick==180:
				var parent=battle.entity(parent_id)
				parent.position+=Vector2(2500,-1400)
			var began=Time.get_ticks_usec();battle.step([1.0/60,1.0/30,.001,.05][tick%4],Vector2(300,0),false,false);sum_us+=Time.get_ticks_usec()-began
			var state=snapshot(battle)
			if first:reference.append(state)
			elif state!=reference[tick]:
				equal=false
				if first_difference.is_empty():first_difference={"tick":tick,"old":reference[tick],"new":state}
		var phases={}
		for key in battle.phase_times:phases[key]=float(battle.phase_times[key])/240000
		timings.append({"optimized":optimized,"mean_tick_ms":float(sum_us)/240000,"phases_mean_ms":phases})
	var report={"passed":equal,"ticks":240,"timings":timings,"scope":"Exact full combat state through parent attachment, missing parents, changing offsets, stun, warp, faction changes and parent relocation. Timing is only diagnostic."}
	if not equal:report.first_difference=first_difference
	FileAccess.open("res://artifacts/deep50-parent-pose-fastpath.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if equal else 1)
