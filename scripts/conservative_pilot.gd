extends Node
## External controller for normal release gameplay. No simulation/health/reward
## overrides: use held movement actions and the same choice/build UI callbacks.
const POLICY_VERSION="terrain_escape_v5"
const TerrainPrediction=preload("res://scripts/pilot_escape_terrain.gd")
const PitGeometry=preload("res://scripts/chasm_world.gd")
var pit_geometry=PitGeometry.new()
var game
var folder=""
var began=0
var next_decision=0
var next_status=0
var next_capture=120.0
var next_ui=0
var next_ore=0.0
var ore_goal=Vector2.INF
var wander=Vector2.RIGHT
var goal=Vector2.ZERO
var goal_kind="explore"
var boss_distance=INF
var low_windows=0
var done=false
var frame_samples:Array=[]
var decision_us=0
var previous_head=Vector2.ZERO
var stuck_seconds=0.0
var last_status_elapsed=0.0
var decisions=0
var last_command=""
var last_slow_capture=0.0
var last_slow_stop=-100000.0
var manual_goal=Vector2.INF
var initial_pointer_enabled=null
var policy_rng=RandomNumberGenerator.new()
var supply_menu_actions=0
var manual_direction=Vector2.ZERO
var manual_boost=false
var manual_until=0
var refueling=false
var policy_logged=false

func setup(owner_game):game=owner_game;call_deferred("start")

func start():
	folder=OS.get_environment("RBPEW_PILOT_ROOT")
	var actual=OS.get_user_data_dir().replace("\\","/").to_lower()
	if folder.is_empty() or not actual.begins_with(folder.replace("\\","/").to_lower()+"/"):
		printerr("Pilot refuses non-isolated save directory");get_tree().quit(2);return
	var requested_seed=OS.get_environment("RBPEW_PILOT_SEED")
	if not requested_seed.is_empty() and requested_seed.is_valid_int():policy_rng.seed=int(requested_seed)
	else:policy_rng.randomize()
	began=Time.get_ticks_usec()
	game.selected_mission=game.db.named("Endless Mission")
	if game.selected_mission.is_empty():printerr("Endless mission missing");get_tree().quit(2);return
	# Select a normal available mission and normal difficulty; preserve the copied
	# profile's unlocks and the normal starter body. Never grant equipment.
	game.difficulty=0
	get_tree().process_frame.connect(tick)
	game.begin_run()

func held(direction:Vector2,boost:bool=false):
	for entry in [["move_right",maxf(0,direction.x)],["move_left",maxf(0,-direction.x)],["move_down",maxf(0,direction.y)],["move_up",maxf(0,-direction.y)],["boost",1.0 if boost else 0.0]]:
		if entry[1]>.02:Input.action_press(entry[0],entry[1])
		else:Input.action_release(entry[0])

func tick():
	if game==null:return
	var now=Time.get_ticks_usec()
	if now>=next_status:
		next_status=now+5000000;status()
		var command_path=folder.path_join("command.json")
		if FileAccess.file_exists(command_path):
			var command=JSON.parse_string(FileAccess.get_file_as_string(command_path))
			var signature=JSON.stringify(command)
			if command is Dictionary and signature!=last_command:
				last_command=signature
				match command.get("action"):
					"quit":shutdown();return
					"pause":stop("manual_pause")
					"resume":
						done=false;low_windows=0;game.runtime_log.run_identity=0;game.show_game()
					"goal":manual_goal=Vector2(float(command.x),float(command.y))
					"auto":manual_goal=Vector2.INF;manual_until=0
					"hold":request_manual_input(command,now)
					"skill":
						if not done and game.screen=="game":
							var target=game.player.head+game.player.facing*500
							if command.has("x") and command.has("y"):target=Vector2(float(command.x),float(command.y))
							if is_finite(target.x) and is_finite(target.y):
								var used=game.combat.request_skill(target)
								game.runtime_log.write({"type":"pilot_manual_skill","run_elapsed":game.run.elapsed,"used":used})
					"capture":capture(str(command.get("label","manual")).validate_filename())
					"mark":game.runtime_log.mark(game,"pilot_manual");game.performance_overlay.begin_capture()
					"inspect":dump_state()
	if done or game.run==null or game.deployment_active:return
	if game.run.finished or game.screen=="result":stop("normal_run_ended");return
	if game.screen=="pause":held(Vector2.ZERO);return
	if game.screen!="game":
		held(Vector2.ZERO)
		if now>=next_ui:next_ui=now+1500000;choose_or_build()
		return
	if resume_snoozed_rewards(now):return
	frame_samples.append(float(game.get_process_delta_time())*1000)
	if now>=next_decision:
		next_decision=now+500000
		var started=Time.get_ticks_usec();steer();decision_us=Time.get_ticks_usec()-started;decisions+=1
	if game.run.elapsed>=next_capture:
		next_capture+=120;capture("progress-%04d"%int(game.run.elapsed))
	var limit=float(OS.get_environment("RBPEW_PILOT_SECONDS"))
	if limit>0 and game.run.elapsed>=limit:stop("target_duration")

func resume_snoozed_rewards(now:int)->bool:
	if game==null or game.run==null or game.screen!="game" or game.run.finished or game.player.parts[0].hp<=0:return false
	if not game.reward_snoozed or not game.reward_waiting() or now<next_ui:return false
	next_ui=now+1500000
	held(Vector2.ZERO)
	supply_menu_actions+=1
	game.runtime_log.write({"type":"pilot_supply_resume","policy":POLICY_VERSION,"run_elapsed":game.run.elapsed,"packs":game.run.packs,"pending":game.player.pending.size(),"action":"advance_reward_flow","supply_menu_actions":supply_menu_actions})
	# This is the same reward flow opened by the ordinary E/build action.
	# Choice, placement and pack consumption remain inside the game's callbacks.
	game.advance_reward_flow()
	return true

func request_manual_input(command:Dictionary,now:int)->bool:
	# A bounded ordinary held input lets the operator drive around a bad route.
	# There is no position, health, cooldown or simulation-time override.
	var direction=Vector2(float(command.get("x",0)),float(command.get("y",0)))
	var seconds=float(command.get("seconds",5))
	if not is_finite(direction.x) or not is_finite(direction.y) or not is_finite(seconds):return false
	manual_direction=direction.limit_length();manual_boost=bool(command.get("boost",false))
	manual_until=now+int(clampf(seconds,.1,30.0)*1000000)
	if game!=null and game.run!=null:game.runtime_log.write({"type":"pilot_manual_input","run_elapsed":game.run.elapsed,"direction":[manual_direction.x,manual_direction.y],"boost":manual_boost,"seconds":clampf(seconds,.1,30.0)})
	return true

func apply_manual_input(now:int)->bool:
	if manual_until<=0:return false
	if now>=manual_until:
		manual_until=0;held(Vector2.ZERO);return false
	if game==null or game.screen!="game" or game.run==null or game.run.finished or game.player.parts[0].hp<=0:return false
	goal_kind="manual_hold";goal=game.player.head+manual_direction*700
	boss_distance=INF
	for enemy in game.combat.enemies:
		if enemy.kind=="AIBossUnit" and enemy.hp>0:boss_distance=minf(boss_distance,game.player.head.distance_to(enemy.position))
	held(manual_direction,manual_boost)
	return true

func pilot_threats()->Array:
	# Decision-local observations only. Gun range enums are not world distances;
	# follow Combat's continuous-shot exception and ordinary range modifier.
	var result:Array=[]
	var player=game.player
	var hp=float(player.parts[0].hp)/maxf(1,float(player.parts[0].max_hp))
	var reserve=220.0+(160.0 if hp<.65 else 0.0)
	for enemy in game.combat.enemies:
		if not hostile(enemy):continue
		var reach=0.0;var muzzle_offset=0.0
		for gun in enemy.guns:
			var core:Dictionary=game.db.asset(gun.id)
			if core.get("class")=="DroneCore":
				reach=maxf(reach,game.db.range_units(core.get("turretRange",4))*48)
			elif core.has("coreProjectile"):
				var distance=game.db.range_units(core.get("turretRange",1))*48
				if game.db.asset(core.coreProjectile).get("class")!="ContinuousProjectile":distance*=1+float(enemy.get("range_modifier",0))
				reach=maxf(reach,distance)
			muzzle_offset=maxf(muzzle_offset,Vector2(gun.get("offset",Vector2.ZERO)).length())
		var body=float(enemy.get("ground_radius",enemy.get("radius",15)))+player.collision_radius(0)
		var radius=maxf(380,reach+body+muzzle_offset+reserve)
		var boss=enemy.kind=="AIBossUnit"
		if boss:radius=maxf(2200,radius)
		var soft=maxf(radius,float(enemy.unit.get("bossActionRadiuos",30))*48+body+reserve) if boss else radius
		result.append({"position":enemy.position,"radius":radius,"soft":soft,"body":body,"reach":reach,"boss":boss,"weight":6.0 if boss else 1.8,"uid":enemy.uid})
	return result

func dangerous(point:Vector2,prepared=null)->float:
	var risk=0.0
	var threats:Array=pilot_threats() if prepared==null else prepared
	for threat in threats:
		var distance_squared=point.distance_squared_to(threat.position)
		if distance_squared>=float(threat.soft)*float(threat.soft):continue
		var d=sqrt(distance_squared)
		risk+=maxf(0,threat.radius-d)*threat.weight
		if threat.boss:risk+=maxf(0,threat.soft-d)*.08
	return risk

func hostile(enemy:Dictionary)->bool:
	return enemy.hp>0 and enemy.role!="friendly" and enemy.kind not in ["Asteroid","ContainerObject"] and not enemy.get("despawn",false)

func pilot_exposure(point:Vector2,threats:Array)->Vector3:
	var worst=0.0;var total=0.0;var soft=0.0
	for threat in threats:
		var distance_squared=point.distance_squared_to(threat.position)
		if distance_squared>=float(threat.soft)*float(threat.soft):continue
		var d=sqrt(distance_squared)
		var exposure=maxf(0,threat.radius-d)/maxf(220,threat.radius*.4)*threat.weight
		worst=maxf(worst,exposure);total+=exposure
		if threat.boss:soft+=maxf(0,threat.soft-d)/maxf(1,threat.soft)
	return Vector3(worst,total,soft)

func pilot_reachable_distance(at:Vector2,direction:Vector2,distance:float,radius:float,pits:Array)->float:
	if distance<=0:return 0.0
	if pits.is_empty():return distance
	# Only the legacy convex hard pits are supplied here. Avoid the cave's
	# diggable contour/movement solver and retain Chasm's exact swept geometry.
	var hit=pit_geometry.first_hit(at,at+direction*distance,radius,pits)
	return distance if hit.is_empty() else maxf(0,distance*float(hit.time)-PitGeometry.SKIN)

func pilot_escape_direction(at:Vector2,desired:Vector2,threats:Array,shots:Array,speed:float,world=null,hull_radius:float=0.0)->Vector2:
	# Compare whole escape paths instead of adding opposite repulsion vectors.
	# A symmetric ring of shooters must still produce a full movement command.
	var candidates:Array=[desired.normalized() if not desired.is_zero_approx() else wander]
	for heading in 16:candidates.append(Vector2.from_angle(float(heading)*TAU/16))
	var best:Vector2=candidates[0];var best_score=-INF
	var escaping=pilot_exposure(at,threats).x>0 or not shots.is_empty()
	var travel=maxf(0,speed)*2.5
	var prediction_threats:Array=threats
	if at.abs().x<32768 and at.abs().y<32768 and is_finite(travel) and travel>=0 and travel<=4096:
		prediction_threats=[]
		for threat in threats:
			# Outside this expanded disk every future sample is beyond the
			# threat's soft circle and contributes exactly zero. Keep unusual
			# inputs and original ordering for the full exposure implementation.
			if not threat is Dictionary or not threat.has("position") or not threat.has("soft"):
				prediction_threats.append(threat);continue
			var position=threat.position;var soft_value=threat.soft
			if not position is Vector2 or not (soft_value is float or soft_value is int):
				prediction_threats.append(threat);continue
			var soft=float(soft_value)
			if not is_finite(position.x) or not is_finite(position.y) or not is_finite(soft) or soft<0 or soft>32768:
				prediction_threats.append(threat);continue
			var bound=soft+travel+8.0
			if at.distance_squared_to(position)<=bound*bound:prediction_threats.append(threat)
	var pits:Array=[]
	if escaping and world!=null and world.has_method("nearby"):
		# One shared pit set covers every heading's full prediction horizon.
		pits=world.nearby(Rect2(at,Vector2.ZERO).grow(travel+hull_radius*2))
	for direction:Vector2 in candidates:
		var reachable=pilot_reachable_distance(at,direction,travel,hull_radius,pits)
		if escaping and world!=null and world.has_method("solid"):
			reachable=minf(reachable,TerrainPrediction.reachable_distance(world,at,direction,reachable,hull_radius))
		var exposure=Vector3.ZERO
		for sample in [[.5,.25],[1.25,.35],[2.5,.4]]:
			exposure+=pilot_exposure(at+direction*minf(maxf(0,speed)*sample[0],reachable),prediction_threats)*sample[1]
		var score=direction.dot(desired)*60+direction.dot(wander)*8-exposure.x*3000-exposure.y*400-exposure.z*90
		for shot in shots:
			var relative:Vector2=shot.position-at
			var velocity:Vector2=shot.velocity-direction*speed
			var moving_seconds=minf(.65,reachable/maxf(.000001,speed))
			var time=clampf(-relative.dot(velocity)/maxf(1,velocity.length_squared()),0,moving_seconds)
			var distance=(relative+velocity*time).length()
			if moving_seconds<.65:
				# After reaching the hard lip the player remains there; the shot
				# still moves. Do not credit an impossible dodge through the pit.
				var stopped_relative=relative+velocity*moving_seconds
				var stopped_time=clampf(-stopped_relative.dot(shot.velocity)/maxf(1,Vector2(shot.velocity).length_squared()),0,.65-moving_seconds)
				distance=minf(distance,(stopped_relative+Vector2(shot.velocity)*stopped_time).length())
			score-=maxf(0,float(shot.radius)-distance)*12
		if escaping and world!=null:
			# Prefer an open retreat lane, while leaving normal mining free to dig.
			for distance in [48,96]:
				var point=at+direction*minf(distance,reachable)
				if world.solid(Vector2i(floori(point.x/24),floori(point.y/24))):score-=90
		if score>best_score:best_score=score;best=direction
	return best

func steer():
	var player=game.player;var at:Vector2=player.head;var elapsed=float(game.run.elapsed)
	if not policy_logged and game.runtime_log.writer!=null:
		game.runtime_log.write({"type":"pilot_policy","version":POLICY_VERSION,"run_elapsed":elapsed,"policy_rng_seed":str(policy_rng.seed),"headings":16,"prediction_seconds":[.5,1.25,2.5],"boss_hard_min":2200,"boss_soft":"live_activation_radius","hard_pits":"single_shared_set_first_hit_stop","snoozed_supply_retry_seconds":1.5,"controls":"ordinary_movement_boost_skill_and_reward_ui"})
		policy_logged=true
	var weapon_input=game.main_weapon_input()
	if initial_pointer_enabled==null:initial_pointer_enabled=weapon_input.enabled
	# Keep the ordinary mouse pointer on unobstructed gameplay, as a player
	# would. A parked pointer over the HUD legitimately disables auto fire.
	if not weapon_input.enabled:Input.warp_mouse(game.get_viewport_rect().size*.5)
	if apply_manual_input(Time.get_ticks_usec()):return
	boss_distance=INF
	var threats=pilot_threats();var closest=INF
	for threat in threats:
		var d=at.distance_to(threat.position)
		if threat.boss:boss_distance=minf(boss_distance,d)
		closest=minf(closest,d-float(threat.body))
	var hp=float(player.parts[0].hp)/maxf(1,float(player.parts[0].max_hp))
	if at.distance_to(previous_head)<8:stuck_seconds+=maxf(0,elapsed-last_status_elapsed)
	else:stuck_seconds=0
	# Ordinary visible ore and drops only; do not search the infinite map.
	if elapsed>=next_ore:
		next_ore=elapsed+4;ore_goal=Vector2.INF
		var world=game.charcoal_terrain.world;var ore_score=-INF
		for row in range(-8,9):
			for column in range(-12,13):
				var point=at+Vector2(column,row)*48
				var ring=point.distance_to(at)
				var cell=Vector2i(floori(point.x/24),floori(point.y/24))
				if world.ore(cell)<=0 or not world.solid(cell):continue
				var score=900-ring-dangerous(point,threats)
				if score>ore_score:ore_score=score;ore_goal=(Vector2(cell)+Vector2.ONE*.5)*24
	var target=Vector2.INF;var best=INF
	for drop in game.combat.loot:
		if drop.get("delivered",false) or drop.has("reserved_by"):continue
		var d=at.distance_to(drop.position)
		if d>850:continue
		var score=d+dangerous(drop.position,threats)
		if score<best:best=score;target=drop.position
	goal_kind="explore"
	if manual_goal!=Vector2.INF:goal=manual_goal;goal_kind="manual_route"
	elif target!=Vector2.INF and best<850:goal=target;goal_kind="collect"
	elif ore_goal!=Vector2.INF and dangerous(ore_goal,threats)<350:goal=ore_goal;goal_kind="mine"
	else:
		wander=wander.rotated(policy_rng.randf_range(-.2,.2)).normalized()
		goal=at+wander*700
	var desired=at.direction_to(goal)
	if goal_kind=="mine" and at.distance_to(goal)<32:next_ore=0
	var incoming=0;var shots:Array=[]
	for bullet in game.combat.bullets:
		if bullet.friendly:continue
		var relative:Vector2=bullet.position-at
		if relative.length_squared()>700*700:continue
		var velocity:Vector2=bullet.get("velocity",Vector2.ZERO)
		if velocity.dot(-relative)<=0:continue
		var future:Vector2=relative+velocity*clampf(-relative.dot(velocity)/maxf(1,velocity.length_squared()),0,.65)
		var radius=player.collision_radius(0)+float(bullet.get("radius",4))+65
		if future.length()<radius:incoming+=1
		shots.append({"position":bullet.position,"velocity":velocity,"radius":radius})
	var exposure=pilot_exposure(at,threats)
	var urgent=exposure.x>.2 or closest<260 or incoming>=2
	var boost=pilot_boost(urgent or (hp<.65 and exposure.x>0) or boss_distance<1900,closest<100 or incoming>=3)
	# Predict with the ordinary movement speed and the real fuel-limited boost.
	var speed=clampf(float(game.db.stores.PlayerDataStore.enginePower)*(1+float(player.stats.get("11",0))),2,4)*48*float(player.character_config.get("speed_multiplier",1))
	if boost and player.fuel>0:speed+=48*minf(float(game.db.stores.PlayerDataStore.boostEnginePower)*(1+float(player.stats.get("12",0))),3)
	if player.coil_active:speed*=.3
	if stuck_seconds>6:
		wander=desired.rotated(PI*.6);desired=wander;next_ore=elapsed+2;ore_goal=Vector2.INF;goal_kind="unstick"
	desired=pilot_escape_direction(at,desired,threats,shots,speed,game.charcoal_terrain.world,player.collision_radius(0))
	if exposure.x>0:goal_kind="retreat_"+goal_kind
	var use_skill=false
	match player.character_id:
		"centipede":
			# Coiling slows travel to 30%; reserve it for imminent contact/bullets.
			use_skill=incoming>=3 or closest<100 or (hp<.4 and incoming>=1)
		"spider":use_skill=closest<260 and (hp<.7 or incoming>=2)
		"beetle":use_skill=(urgent and hp<.7) or incoming>=3 or closest<140
	var skill_used=game.combat.request_skill(at+desired*500) if use_skill else false
	held(desired,boost)
	if decisions%10==0 or skill_used:
		game.runtime_log.write({"type":"pilot_steer","policy":POLICY_VERSION,"run_elapsed":elapsed,"goal_kind":goal_kind,"direction":[desired.x,desired.y],"boost":boost,"skill_used":skill_used,"hp_fraction":hp,"fuel":player.fuel,"max_fuel":player.max_fuel,"refueling":refueling,"hard_exposure":exposure.x,"hostiles":threats.size(),"incoming":incoming,"boss_distance":boss_distance if is_finite(boss_distance) else null})

func pilot_hq_has_repair()->bool:
	for index in game.player.adjacent_part_indices(0):
		var part:Dictionary=game.player.parts[index]
		if part.hp>0 and game.db.asset(part.id).get("class")=="RepairCore":return true
	return false

func pilot_support_count(kind:String)->int:
	var count=0
	for i in game.player.parts.size():
		var part:Dictionary=game.player.parts[i]
		if part.hp<=0:continue
		var core:Dictionary=game.player.effective_core(i) if game.player.has_method("effective_core") else game.db.asset(part.id)
		if core.get("class")==kind or (kind=="EngineerDrone" and core.get("class")=="DroneCore" and game.db.asset(core.get("coreDrone","")).get("class")=="EngineerDrone"):count+=1
	for id in game.player.pending:
		var core:Dictionary=game.db.asset(id)
		if core.get("class")==kind or (kind=="EngineerDrone" and core.get("class")=="DroneCore" and game.db.asset(core.get("coreDrone","")).get("class")=="EngineerDrone"):count+=1
	return count

func pilot_boost(requested:bool,emergency:bool)->bool:
	var capacity=maxf(0,float(game.player.max_fuel));var fuel=maxf(0,float(game.player.fuel));var was_refueling=refueling
	if capacity<=0:refueling=false
	elif fuel<capacity*.15:refueling=true
	elif refueling and fuel>=capacity*.60:refueling=false
	if was_refueling!=refueling:
		game.runtime_log.write({"type":"pilot_refuel","policy":POLICY_VERSION,"run_elapsed":game.run.elapsed,"fuel":fuel,"max_fuel":capacity,"refueling":refueling,"emergency":emergency})
	# Keeping boost released through recharge prevents tiny refilled amounts
	# from being spent every two seconds and restarting the real fuel delay.
	return requested and capacity>0 and fuel>0 and (not refueling or emergency)

func reward_score(reward:Dictionary)->float:
	var category=str(reward.get("class",""));var n=str(reward.get("name",""))
	var parts=game.player.parts.size()-1;var score=0.0
	if category=="BlockReward":
		score=100 if parts<8 else (75 if parts<20 else 45)
		var core=game.db.asset(reward.blockCore)
		score+=15 if not game.player.parts.any(func(p):return p.id==reward.blockCore) else 0
		if str(core.get("name","")).contains("Gatling"):score+=10
		if core.get("class")=="RepairCore":score=170 if not pilot_hq_has_repair() else 45
		elif core.get("class")=="FuelCore":score=185 if pilot_support_count("FuelCore")==0 else 45
		elif core.get("class")=="ShieldCore":score=175 if pilot_support_count("ShieldCore")==0 else 50
		elif core.get("class")=="DroneCore" and game.db.asset(core.get("coreDrone","")).get("class")=="EngineerDrone":
			var engineers=pilot_support_count("EngineerDrone")
			score=180 if engineers==0 else (120 if engineers==1 and parts>=8 else (85 if engineers==1 else 45))
	elif category=="MainCoreTurretReward":score=55 if parts<3 else 30
	elif category=="MainCoreDroneReward":score=65
	elif category=="PercentBasicReward":
		var kind=int(reward.get("rewardType",0));score=45
		if kind in [1,2,3,4,5,11,12,13,14]:score+=25
		if kind in [10,16]:score=115 if game.player.parts[0].hp<game.player.parts[0].max_hp*.85 else 80
	elif "LevelUp" in category:score=60
	elif category=="CountBasicReward":score=-40
	elif category=="CrusedReward":score=-20
	if reward.has("mutation_branch"):score+=8
	return score+float(reward.get("rarity",0))*2

func choose_or_build():
	if game.screen=="loading":game.show_game();return
	if game.screen=="rewards":
		var best={};var score=-INF
		for reward in game.run.offers:
			if not game.run.can_reward(reward):continue
			var value=reward_score(reward)
			if value>score:score=value;best=reward
		if not best.is_empty():
			game.runtime_log.write({"type":"pilot_choice","run_elapsed":game.run.elapsed,"reward":best.id,"reward_class":best.get("class"),"offers":game.run.offers.map(func(r):return r.id)})
			game.choose_reward(best,game.reward_epoch)
		else:game.recycle_reward(game.reward_epoch)
	elif game.screen=="build":
		if game.player.pending.is_empty():game.finish_building();return
		var id=game.player.pending[0];var mount=game.player.first_free_mount()
		var target={"kind":"gap","before":mount.x} if game.player.character_id=="centipede" else {"kind":"mount","before":mount.x}
		var repair=game.db.asset(id).get("class")=="RepairCore"
		if repair and not pilot_hq_has_repair() and game.player.character_id=="centipede":target={"kind":"gap","before":1}
		game.runtime_log.write({"type":"pilot_build","policy":POLICY_VERSION,"run_elapsed":game.run.elapsed,"core":id,"target":target.duplicate(),"repair_for_hq":repair and int(target.before)==1})
		game.build_ui.drop(target,{"kind":"inventory","index":0,"id":id})

func status():
	if game==null or game.run==null:return
	var sum=0.0
	for ms in frame_samples:sum+=ms
	var average=sum/maxi(1,frame_samples.size());frame_samples.sort()
	var fps=1000/maxf(.001,average) if not frame_samples.is_empty() else 0
	var stats={"wall_seconds":float(Time.get_ticks_usec()-began)/1000000,"run_elapsed":game.run.elapsed,"screen":game.screen,"done":done,"hp":game.player.parts[0].hp,"max_hp":game.player.parts[0].max_hp,"parts":game.player.parts.size(),"level":game.run.level,"opened":game.run.opened,"pending":game.player.pending.size(),"kills":game.combat.kills,"boss_kills":game.combat.boss_kills,"actors":game.combat.enemies.size(),"bullets":game.combat.bullets.size(),"effects":game.combat.effects.size(),"position":[game.player.head.x,game.player.head.y],"ore":game.charcoal_terrain.world.ore_total,"removed_cells":game.charcoal_terrain.world.removed_count,"fps_5s":fps,"p95_ms_5s":frame_samples[mini(frame_samples.size()-1,int(frame_samples.size()*.95))] if not frame_samples.is_empty() else 0,"boss_distance":boss_distance if is_finite(boss_distance) else null,"goal_kind":goal_kind,"goal":[goal.x,goal.y],"pilot_last_decision_us":decision_us,"pilot_decisions":decisions,"test_mode":game.test_mode,"fixture":get_tree().has_meta("performance_fixture"),"log_path":game.runtime_log.session_path}
	stats.weapons_enabled=game.main_weapon_input().enabled if game.screen=="game" else null
	stats.initial_pointer_enabled=initial_pointer_enabled
	stats.packs=game.run.packs;stats.reward_snoozed=game.reward_snoozed;stats.pilot_supply_menu_actions=supply_menu_actions
	stats.fuel=game.player.fuel;stats.max_fuel=game.player.max_fuel;stats.refueling=refueling
	var kinds={};var roots={}
	for enemy in game.combat.enemies:
		kinds[enemy.kind]=int(kinds.get(enemy.kind,0))+1
		if enemy.parent==0:roots[enemy.kind]=int(roots.get(enemy.kind,0))+1
	stats.actor_kinds=kinds;stats.root_kinds=roots
	FileAccess.open(folder.path_join("status.json"),FileAccess.WRITE).store_string(JSON.stringify(stats,"\t"))
	game.runtime_log.write({"type":"pilot_status","run_elapsed":game.run.elapsed,"data":stats})
	frame_samples.clear();previous_head=game.player.head;last_status_elapsed=game.run.elapsed
	if not done and game.screen=="game" and game.run.elapsed>=600 and fps>0 and fps<38:low_windows+=1
	else:low_windows=0
	if not done and game.screen=="game" and fps>0 and fps<42 and game.run.elapsed-last_slow_capture>60:
		last_slow_capture=game.run.elapsed;capture("slow-%04d"%int(game.run.elapsed))
	# Keep a long battle continuous between useful diagnostic checkpoints.
	# This changes only the external pilot's pause cadence, never simulation dt.
	if OS.get_environment("RBPEW_PILOT_AUTO_PAUSE")!="0" and low_windows>=3 and game.run.elapsed-last_slow_stop>=300:
		last_slow_stop=game.run.elapsed;stop("sustained_slow_frames")

func capture(label:String):
	game.runtime_log.write({"type":"pilot_screenshot","run_elapsed":game.run.elapsed,"label":label})
	var picture=game.get_viewport().get_texture().get_image()
	picture.save_png(folder.path_join(label+".png"))

func stop(reason:String):
	if done:return
	done=true;manual_until=0;held(Vector2.ZERO)
	game.runtime_log.mark(game,"pilot_stop_"+reason)
	game.runtime_log.finish_session(reason)
	dump_state()
	capture(reason)
	if game.screen=="game":game.show_pause()
	status()

func dump_state():
	var actors=[]
	for enemy in game.combat.enemies:
		actors.append({"uid":enemy.uid,"kind":enemy.kind,"prefab":enemy.prefab,"parent":enemy.parent,"hp":enemy.hp,"position":[enemy.position.x,enemy.position.y],"angle":enemy.angle,"ground_radius":enemy.get("ground_radius",enemy.radius),"radius":enemy.radius,"guns":enemy.guns.size(),"parts":enemy.parts,"active":enemy.active,"heat_speed":enemy.heat_speed,"boost_left":enemy.boost_left,"role":enemy.role,"ground_route":enemy.get("ground_route",{}),"ground_next":enemy.get("ground_next",0)})
	var data={"run_elapsed":game.run.elapsed,"actors":actors,"pilot_source":game.runtime_log.fingerprint("res://scripts/conservative_pilot.gd"),"player_parts":game.player.parts,"level":game.run.level,"heat":game.run.heat,"duration":game.run.duration}
	FileAccess.open(folder.path_join("gameplay-state.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	# Preserve exact native coordinates and excavated cells for later collision
	# replay. This is diagnostic state, not a loadable player save/full battle.
	var motion:Array=[]
	for enemy in game.combat.enemies:
		if enemy.parent!=0:continue
		var state={}
		for key in ["uid","kind","position","angle","radius","ground_radius","movement","unit","active","heat_speed","boost_left","boost_cooldown","stop_distance","moving_speed","rotation_speed","stun","warp","hp","role","prefab","parent","origin","orbit_speed","orbit_offset","patrol","patrol_offset"]:
			if enemy.has(key):state[key]=enemy[key]
		motion.append(state)
	var world=game.charcoal_terrain.world
	var replay={"format":1,"scope":"Native movement inputs and excavated terrain; not a complete battle save","run_elapsed":game.run.elapsed,"head":game.player.head,"heat":game.run.heat,"actors":motion,"seed":world.seed_value,"chunks":world.chunks,"revision":world.revision,"removed_count":world.removed_count}
	FileAccess.open(folder.path_join("collision-replay.bin"),FileAccess.WRITE).store_var(replay)
	if done or game.screen=="pause":
		FileAccess.open(folder.path_join("battle-state.bin"),FileAccess.WRITE).store_var(preload("res://scripts/battle_snapshot.gd").capture(game))

func shutdown():
	held(Vector2.ZERO);game.runtime_log.finish_session("pilot_shutdown")
	game.cursor_system.shutdown();game.audio_system.shutdown();get_tree().quit()
