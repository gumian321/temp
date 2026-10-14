extends "res://tests/test_centipede_scene.gd"
const Formation=preload("res://scripts/radial_formation.gd")

func is_ring(points:Array,center:Vector2)->bool:
	if points.is_empty():return false
	var radius=Vector2(points[0]).distance_to(center)
	var angles:Array=[]
	for point in points:
		if absf(Vector2(point).distance_to(center)-radius)>.01:return false
		angles.append(fposmod((Vector2(point)-center).angle(),TAU))
	angles.sort()
	for i in angles.size():
		if absf(fposmod(angles[(i+1)%angles.size()]-angles[i],TAU)-TAU/angles.size())>.001 and angles.size()>1:return false
	return true

func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	game.start_run();game.set_process(false);game.combat.enemies.clear()
	var core=game.db.named("Core_MinesField")
	game.player.append_segment(core.id)
	var p=game.player;var b=game.combat
	var reward=game.db.named("Reward_LevelUP_MineField")
	for level in [0,3]:
		p.levels[reward.id]=level
		var cap=b.special.mine_capacity(core)
		for i in range(cap+1):p.parts[1].cooldown=0;b.special.step(0)
		var points=b.special.mines.map(func(m):return m.position)
		check(points.size()==cap and is_ring(points,p.parts[1].position),"Egg ring fills distinct equally spaced circular slots at upgrade %d"%level)
		var minimum=INF
		for i in points.size():
			for j in range(i+1,points.size()):minimum=minf(minimum,points[i].distance_to(points[j]))
		check(minimum>24,"Upgraded eggs remain visually separated")
		p.facing=Vector2.UP;p.parts[1].position+=Vector2(40,70);b.special.step(0)
		check(is_ring(b.special.mines.map(func(m):return m.position),p.parts[1].position),"Egg ring follows its moving and turning owner")
		var victim=b.spawn(game.db.pool["250"],b.special.mines[0].position);victim.mission_controlled=true;victim.guns=[]
		var hp=victim.hp;p.parts[1].cooldown=1;b.special.step(0)
		check(victim.hp<hp and b.special.mines.size()==cap-1,"Contact detonates one egg and leaves one empty slot")
		b.enemies.clear();p.parts[1].cooldown=0;b.special.step(0)
		check(is_ring(b.special.mines.map(func(m):return m.position),p.parts[1].position),"Recharging fills the missing slot without duplicates")
	p.levels[reward.id]=0;b.special.mines.clear();p.refresh_positions()
	for i in 20:p.parts[1].cooldown=0;b.special.step(0)
	b.effects.clear();game.camera=p.parts[1].position;game.zoom=1
	await capture("circular-egg-ring")
	b.special.mines.clear();p.parts[1].id=game.db.named("Core_MineSpawner").id;p.parts[1].cooldown=0;p.velocity=Vector2.RIGHT*30
	b.special.step(0)
	check(b.special.mines.size()==10 and is_ring(b.special.mines.map(func(m):return m.position),p.parts[1].position),"Free egg spawner releases a full circle instead of a horizontal row")
	var laid=b.special.mines.map(func(m):return m.position)
	p.parts[1].position+=Vector2(60,20);b.special.step(.1)
	check(laid==b.special.mines.map(func(m):return m.position),"Free eggs stay where they were laid")
	var map=game.run.map_director
	for type in [101,103,105]:
		var key=Vector2(type*100,1000);map.spawn_node(key,type)
		var node=map.nodes[key]
		var guard_points=[]
		for uid in node.members:
			if uid not in node.objectives:guard_points.append(b.entity(uid).orbit_offset)
		var sources=map.source_points(node.prefab,"AIGuardsSpawner","AIGuardSpawnPointsList")
		var center=Vector2.ZERO
		for point in sources:center+=point
		center/=sources.size()
		check(is_ring(guard_points,center),"Map guards evenly encircle event %d even with partial strength"%type)
		if type==103:check(is_ring(node.objectives.map(func(uid):return b.entity(uid).orbit_offset),Vector2.ZERO),"Station parts use radial positions")
	for prefab in game.db.entities:
		if game.db.component(prefab,"AIPatrolManager").is_empty():continue
		var leader=b.spawn(prefab,Vector2(3000,3000))
		var members=b.patrols[leader.uid].members
		var outer=members.map(func(uid):return b.entity(uid).patrol_offset).filter(func(offset):return offset.length()>1)
		check(is_ring(outer,Vector2.ZERO),"Patrol uses a circular escort: "+str(game.db.prefabs[prefab].name))
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in 12:await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/radial-formations-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
