extends "res://tests/test_centipede_scene.gd"

func execute():
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	game.start_run();game.set_process(false)
	var battle=game.combat;var map=game.run.map_director;var world=game.charcoal_terrain.world
	var guards=battle.enemies.filter(func(e):return e.get("orbit_speed",0)!=0 and int(e.parent)==0)
	check(not guards.is_empty(),"Real cave deployment supplies orbiting map guards")
	var actor:Dictionary=guards[0].duplicate(true)
	actor.parent=0;actor.mission_controlled=true;actor.role="enemy";actor.orbit_speed=.14
	actor.origin=Vector2.ZERO;actor.orbit_offset=Vector2(80,0);actor.position=Vector2(80,0);actor.ground_previous=actor.position
	actor.feedback_left=0;actor.stun=0;actor.erase("knockback_velocity");actor.erase("insect_control");actor.erase("soft_body")
	var initial=actor.duplicate(true);var near_trace:Array=[]
	battle.enemies=[actor];battle.bullets.clear();battle.drones.clear();battle.special.black_holes.clear()
	map.orbit_activity_view=Rect2(-1000,-700,2000,1400);map.use_remote_orbits=false
	for i in 240:
		map.step_orbits(1.0/60);near_trace.append([actor.position,actor.angle,actor.orbit_offset])
	actor=initial.duplicate(true);battle.enemies=[actor];map.use_remote_orbits=true
	var exact=true
	for i in 240:
		map.step_orbits(1.0/60)
		exact=exact and near_trace[i]==[actor.position,actor.angle,actor.orbit_offset] and map.orbit_moves==1
	check(exact,"Visible guard position, angle and orbital phase match full-rate updates exactly over 240 ticks")
	var far_point=world.safe_position(Vector2(9000,-8000),100)
	actor=initial.duplicate(true);actor.origin=far_point-actor.orbit_offset;actor.position=far_point;actor.ground_previous=far_point
	actor.ground_radius=15.0;actor.radius=15.0
	battle.enemies=[actor];var full=actor.duplicate(true);var moves=0;var safe=true;var phase_equal=true
	for i in 240:
		full.orbit_offset=Vector2(full.orbit_offset).rotated(full.orbit_speed/60.0);full.angle+=full.orbit_speed/60.0
		map.step_orbits(1.0/60);moves+=map.orbit_moves
		safe=safe and not world.blocked(actor.position,15)
		phase_equal=phase_equal and actor.orbit_offset==full.orbit_offset and actor.angle==full.angle
	check(moves>=59 and moves<=62 and safe and phase_equal,"Distant guards retain every orbital phase tick while using 15 Hz continuous, physically clear collision moves")
	actor.feedback_left=.065;map.step_orbits(1.0/60)
	check(map.orbit_moves==1 and not actor.has("remote_orbit_elapsed"),"A distant hit immediately restores normal collision updates")
	actor.feedback_left=0;battle.bullets=[{"position":actor.position+Vector2(100,0)}];map.step_orbits(1.0/60)
	check(map.orbit_moves==1,"A projectile entering the guard neighborhood immediately wakes movement")
	battle.bullets.clear();map.orbit_activity_view=Rect2(actor.position-Vector2(500,500),Vector2(1000,1000));map.step_orbits(1.0/60)
	check(map.orbit_moves==1,"Zoomed or panned views keep their visible guards at full rate")
	map.orbit_activity_view=Rect2(-1000,-700,2000,1400);game.player.head=actor.position+Vector2(500,0);map.step_orbits(1.0/60)
	check(map.orbit_moves==1,"Approaching the encounter resumes normal movement on the first tick")
	game.player.head=Vector2.ZERO;game.player.stats["17"]=100.0;map.step_orbits(1.0/60)
	check(map.orbit_moves==1,"Expanded weapon range protects distant guard interaction")
	game.player.stats["17"]=0.0;map.orbit_activity_view=Rect2();map.step_orbits(1.0/60)
	check(map.orbit_moves==1,"Missing presentation bounds conservatively retain the original cadence")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in 12:await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"far_collision_moves":moves,"ticks":240,"near_exact":exact,"far_physical_clearance":safe,"phase_exact":phase_equal}
	FileAccess.open("res://artifacts/remote-map-orbits-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
