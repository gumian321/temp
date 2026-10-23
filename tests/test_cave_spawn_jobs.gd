extends SceneTree
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)
func execute():
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.test_mode=true;game.save.fresh();game.start_run();game.set_process(false)
	var map=game.run.map_director;var world=game.player.terrain
	game.combat.enemies.clear();map.nodes.clear();map.pending_nodes.clear()
	map.defer_actor_jobs=true;var key=Vector2(45,0);map.spawn_node(key,103);map.defer_actor_jobs=false
	var planned=map.actor_jobs.size();var node=map.nodes[key]
	check(planned>2 and node.pending==planned and node.members.is_empty(),"Runtime map planning queues complete station/guard prefabs before expensive placement")
	var ticks=0
	while not map.actor_jobs.is_empty() and ticks<2500:
		map.prepare_actor();ticks+=1
	check(map.actor_jobs.is_empty() and node.pending==0 and ticks>planned,"Offscreen geometry is prepared in bounded steps and every queued prefab eventually spawns")
	check(not node.objectives.is_empty() and node.members.size()>node.objectives.size(),"Deferred stations retain destructible parts, guards and original reward metadata")
	check(game.combat.enemies.all(func(e):return not world.blocked(e.position,float(e.get("ground_radius",e.radius)))),"Prepared whole prefabs and child bodies spawn outside physical rock")
	var before={}
	for uid in node.members:
		var e=game.combat.entity(uid);before[uid]=Vector2(e.position)
		check(Vector2(e.origin+e.orbit_offset).distance_to(e.position)<.001,"Relocated map orbit begins at its accepted cave position")
	map.step(1.0/60)
	check(node.members.all(func(uid):return game.combat.entity(uid).position.distance_to(before[uid])<5),"First orbit update does not sweep back toward the old position through rock")
	map.defer_actor_jobs=true;map.spawn_node(Vector2(-45,0),103);map.defer_actor_jobs=false
	var cancelled=map.nodes[Vector2(-45,0)];map.nodes.erase(Vector2(-45,0))
	while not map.actor_jobs.is_empty():map.prepare_actor()
	check(cancelled.members.is_empty(),"Unloaded map columns discard pending prefabs before spawning")
	var owner=game.combat.entity(node.members[0]);var old_count=game.combat.enemies.size()
	owner.spawn_pending=true
	game.run.local_spawn_jobs.append({"prefab":game.db.pool["250"],"point":Vector2(owner.position),"owner":owner.uid,"cooldown":1.0,"range":999999.0,"placement":{}})
	for i in 300:
		game.run.prepare_local_spawn()
		if game.run.local_spawn_jobs.is_empty():break
	check(game.run.local_spawn_jobs.is_empty() and not owner.spawn_pending and owner.spawn_timer==1.0 and game.combat.enemies.size()>old_count and game.combat.enemies.back().spawner_owner==owner.uid,"Local generators also prepare geometry over frames and retain owner/cooldown semantics")
	var run=game.run;var director=run.director
	run.map_director.incremental=true;run.elapsed=15.1
	run.mode={"class":"SurvivalModeManager","EndBossFleetList":[250],"EndBossSpawningRadius":40}
	director.mode=run.mode;director.end_spawned=false
	director.step(0)
	check(run.pending_fleet("survival_final") and not run.finished,"A queued final wave counts as active and cannot win the mission before it spawns")
	for i in 500:
		run.prepare_local_spawn()
		if run.local_spawn_jobs.is_empty():break
	var final_actors=game.combat.enemies.filter(func(e):return e.group=="survival_final")
	director.step(0)
	check(not final_actors.is_empty() and final_actors.all(func(e):return e.objective and e.heat_speed) and not run.finished,"Every prepared wave member retains its group, targeting and final-boss metadata")
	game.combat.enemies=game.combat.enemies.filter(func(e):return e.group!="survival_final")
	director.step(0)
	check(run.finished and run.won,"The original survival completion rule still waits for the actual final wave to be cleared")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"preparation_ticks":ticks,"prefabs":planned}
	FileAccess.open("res://artifacts/cave-spawn-jobs-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free()
	await process_frame;await process_frame;quit(0 if report.passed else 1)
