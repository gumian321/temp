extends SceneTree
const Pilot=preload("res://scripts/conservative_pilot.gd")
var checks:Array=[]

class Database extends RefCounted:
	var stores={"PlayerDataStore":{"enginePower":2,"boostEnginePower":2}}
	var catalog={
		"gun":{"class":"ProjectileCore","name":"Gatling","coreProjectile":"shot","turretRange":3},
		"beam":{"class":"ProjectileCore","coreProjectile":"continuous","turretRange":3},
		"shot":{"class":"Projectile"},"continuous":{"class":"ContinuousProjectile"},
		"repair":{"class":"RepairCore"},"shield":{"class":"ShieldCore"},"hq":{"class":"MainCore"},
		"fuel":{"class":"FuelCore","name":"Core_FuelTank","fuelCapacity":150},
		"engineer":{"class":"DroneCore","coreDrone":"engineer_data"},"engineer_data":{"class":"EngineerDrone"},
		"attack_drone":{"class":"DroneCore","coreDrone":"attack_data"},"attack_data":{"class":"ProjectileDrone"}}
	func asset(id)->Dictionary:return catalog.get(id,{})
	func range_units(value)->float:return [5.0,9.0,12.0,15.0,20.0,7.0][clampi(int(value),0,5)]

class Player extends RefCounted:
	var parts:Array=[{"id":"hq","hp":100.0,"max_hp":100.0,"segment":0},{"id":"gun","hp":100.0,"max_hp":100.0,"segment":1}]
	var pending:Array=[]
	var character_id="centipede"
	var character_config:Dictionary={}
	var stats:Dictionary={}
	var fuel=100.0
	var max_fuel=100.0
	var fuel_delay=2.0
	var coil_active=false
	var head=Vector2.ZERO
	func collision_radius(_index:int)->float:return 30.0
	func adjacent_part_indices(index:int)->Array:
		var result:Array=[]
		for i in parts.size():
			if absi(int(parts[i].segment)-int(parts[index].segment))==1:result.append(i)
		return result
	func first_free_mount()->Vector2i:return Vector2i(parts.size(),4)

class Battle extends RefCounted:
	var enemies:Array=[]
	var bullets:Array=[]
	var loot:Array=[]
	var skills:Array=[]
	func request_skill(aim:Vector2)->bool:skills.append(aim);return true

class World extends RefCounted:
	var pits:Array=[]
	var nearby_calls=0
	var move_calls=0
	var observed_area=Rect2()
	func ore(_cell:Vector2i)->float:return 0.0
	func solid(_cell:Vector2i)->bool:return false
	func nearby(area:Rect2)->Array:nearby_calls+=1;observed_area=area;return pits
	func move(_start:Vector2,desired:Vector2,_radius:float)->Vector2:move_calls+=1;return desired

class GeometryTrace extends "res://scripts/chasm_world.gd":
	var first_hit_calls=0
	func first_hit(start:Vector2,finish:Vector2,radius:float,pits:Array)->Dictionary:
		first_hit_calls+=1
		return super.first_hit(start,finish,radius,pits)

class Terrain extends RefCounted:
	var world=World.new()

class Run extends RefCounted:
	var elapsed=25.0
	var offers:Array=[]
	var packs=0
	var finished=false
	func can_reward(_reward:Dictionary)->bool:return true

class LogTrace extends RefCounted:
	var events:Array=[]
	func write(event:Dictionary):events.append(event)

class BuildTrace extends RefCounted:
	var calls:Array=[]
	func drop(target:Dictionary,data:Dictionary):calls.append([target.duplicate(),data.duplicate()])

class Game extends RefCounted:
	var player=Player.new()
	var db=Database.new()
	var combat=Battle.new()
	var charcoal_terrain=Terrain.new()
	var run=Run.new()
	var runtime_log=LogTrace.new()
	var build_ui=BuildTrace.new()
	var screen="build"
	var reward_epoch=1
	var chosen:Dictionary={}
	var reward_snoozed=false
	var reward_flow_calls=0
	func main_weapon_input()->Dictionary:return {"enabled":true}
	func choose_reward(reward:Dictionary,_epoch):chosen=reward
	func finish_building():pass
	func reward_waiting()->bool:return run.packs>0 or not player.pending.is_empty()
	func advance_reward_flow():
		reward_flow_calls+=1;reward_snoozed=false
		screen="build" if not player.pending.is_empty() else ("rewards" if run.packs>0 else "game")

func check(passed:bool,label:String):
	checks.append({"passed":passed,"label":label})
	if not passed:push_error(label)

func actor(uid:int,at:Vector2,gun:String="gun",boss:bool=false)->Dictionary:
	return {"uid":uid,"position":at,"hp":100.0,"role":"enemy","kind":"AIBossUnit" if boss else "AIFollowingUnit","guns":[{"id":gun,"offset":Vector2.ZERO}],"radius":15.0,"range_modifier":.5,"unit":{"bossActionRadiuos":100}}

func rectangular_pit(bounds:Rect2)->Dictionary:
	return {"bounds":bounds,"miter":1.0,"polygon":PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]),"normals":PackedVector2Array([Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT])}

func _initialize():call_deferred("execute")
func execute():
	for action in ["move_right","move_left","move_up","move_down","boost"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var pilot=Pilot.new();var game=Game.new();pilot.game=game
	var ordinary=actor(1,Vector2(1000,0));var beam=actor(2,Vector2(-1000,0),"beam")
	game.combat.enemies=[ordinary,beam]
	var original=[game.player.parts.duplicate(true),game.combat.enemies.duplicate(true)]
	var threats=pilot.pilot_threats()
	check(threats.size()==2 and threats[0].reach==1080 and threats[1].reach==720,"live enum range and continuous-shot modifier exception")
	check(threats[0].radius==1345 and threats[1].radius==985,"range includes body hull and ordinary decision reserve")
	game.player.parts[0].hp=50.0
	check(pilot.pilot_threats()[0].radius==1505,"low HP adds retreat reserve without changing health")
	game.player.parts[0].hp=100.0
	var shield=actor(3,Vector2.ZERO,"shield");game.combat.enemies=[shield]
	check(pilot.pilot_threats()[0].reach==0,"shield equipment is not mistaken for a ranged gun")
	var boss=actor(4,Vector2(4500,0),"shield",true);boss.ground_radius=220.0;game.combat.enemies=[boss]
	var boss_threat=pilot.pilot_threats()[0]
	check(boss_threat.radius==2200 and boss_threat.soft==5270,"boss hard minimum and real 4800px activation soft circle")
	check(pilot.dangerous(Vector2.ZERO,[boss_threat])>0 and pilot.pilot_exposure(Vector2.ZERO,[boss_threat]).x==0,"activation circle remains a soft preference")
	var left={"position":Vector2(-400,0),"radius":900.0,"soft":900.0,"weight":1.8,"boss":false}
	var right={"position":Vector2(400,0),"radius":900.0,"soft":900.0,"weight":1.8,"boss":false}
	var escape:Vector2=pilot.pilot_escape_direction(Vector2.ZERO,Vector2.RIGHT,[left,right],[],200)
	check(escape.length()>.999 and absf(escape.y)>.9 and absf(escape.x)<.3,"opposed ranged threats choose a full perpendicular escape instead of cancelling")
	var near_boss=boss_threat.duplicate();near_boss.position=Vector2(1800,0)
	check(pilot.pilot_escape_direction(Vector2.ZERO,Vector2.RIGHT,[near_boss],[],200).x<-.9,"hard boss danger overrides a goal toward boss")
	check(pilot.pilot_escape_direction(Vector2.ZERO,Vector2.DOWN,[],[],200).dot(Vector2.DOWN)>.999,"safe exploration retains mining direction")
	var shot={"position":Vector2(200,0),"velocity":Vector2(-600,0),"radius":99.0}
	var dodge:Vector2=pilot.pilot_escape_direction(Vector2.ZERO,Vector2.RIGHT,[],[shot],200)
	check(absf(dodge.y)>.5,"incoming projectile changes travel direction before impact")
	game.combat.enemies=[ordinary];game.player.parts[0].hp=50.0
	pilot.steer()
	check(Input.get_vector("move_left","move_right","move_up","move_down").x<-.8 and Input.is_action_pressed("boost"),"full steer uses ordinary movement and boost to leave ranged danger")
	check(game.combat.skills.is_empty(),"low HP alone does not trigger travel-slowing centipede coil")
	check(game.player.parts[0].hp==50.0 and game.combat.enemies[0]==ordinary,"steering leaves health and enemy state unchanged")
	check(game.runtime_log.events[0].get("version")=="range_escape_v4","first decision records policy version and independent policy seed")
	game.player.parts[0].hp=35.0;game.combat.bullets=[{"position":Vector2(80,0),"velocity":Vector2(-960,0),"friendly":false,"radius":4.0}]
	pilot.decisions=1;pilot.steer()
	check(game.combat.skills.size()==1,"low HP and imminent bullets request normal centipede defensive skill")
	game.combat.skills.clear();game.combat.bullets.clear();game.player.character_id="beetle";pilot.steer()
	check(game.combat.skills.size()==1 and Vector2(game.combat.skills[0]).x<0,"low HP beetle requests ordinary rush toward selected escape direction")
	game.combat.skills.clear();game.player.character_id="spider";game.combat.enemies=[actor(5,Vector2(200,0))];pilot.steer()
	check(game.combat.skills.size()==1,"low HP spider requests ordinary nearby crowd-control skill")
	pilot.held(Vector2.ZERO);game.player.character_id="centipede";game.player.parts[0].hp=100.0
	var normal_reward={"id":"normal_reward","class":"BlockReward","blockCore":"gun"}
	var repair_reward={"id":"repair_reward","class":"BlockReward","blockCore":"repair"}
	check(pilot.reward_score(repair_reward)>pilot.reward_score(normal_reward),"normally offered first HQ repair outranks ordinary extra weapon")
	game.player.pending=["repair"]
	pilot.choose_or_build()
	check(game.build_ui.calls==[[{"kind":"gap","before":1},{"kind":"inventory","index":0,"id":"repair"}]],"repair is placed beside HQ through ordinary inventory drop callback")
	check(game.player.pending==["repair"] and game.player.parts==original[0],"controller delegates placement instead of granting or mutating modules")
	game.player.parts.append({"id":"repair","hp":100.0,"max_hp":100.0,"segment":2})
	check(not pilot.pilot_hq_has_repair(),"repair at tail does not count as HQ protection")
	game.player.parts[1].segment=2;game.player.parts[2].segment=1
	check(pilot.pilot_hq_has_repair() and pilot.reward_score(repair_reward)<pilot.reward_score(normal_reward),"existing live HQ repair prevents repeated support prioritization")
	game.player.pending=["gun"];game.build_ui.calls.clear();pilot.choose_or_build()
	check(game.build_ui.calls[0][0]=={"kind":"gap","before":3},"normal weapons continue legal tail placement")
	game.player.parts=original[0].duplicate(true);game.screen="rewards";game.run.offers=[normal_reward,repair_reward];pilot.choose_or_build()
	check(game.chosen==repair_reward and game.player.parts==original[0],"reward remains one offered can_reward choice through normal callback")
	var filtered=ordinary.duplicate(true);filtered.role="friendly"
	check(not pilot.hostile(filtered),"friendly actors do not create danger")
	filtered.role="enemy";filtered.despawn=true
	check(not pilot.hostile(filtered),"despawning actors do not create danger")
	# The remaining checks exercise v3's ordinary supply-menu retry and hard
	# pit prediction. The original 26 skill/reward/movement checks above remain.
	game.screen="game";game.player.pending=[];game.run.packs=3;game.reward_snoozed=true;pilot.next_ui=0
	var elapsed=game.run.elapsed;var parts_before=game.player.parts.duplicate(true);var events_before=game.runtime_log.events.size()
	check(pilot.resume_snoozed_rewards(1000000) and game.reward_flow_calls==1 and game.screen=="rewards","snoozed remaining packs reopen the ordinary reward flow without waiting for a new pickup")
	check(game.run.packs==3 and game.player.pending.is_empty() and game.player.parts==parts_before,"opening supply flow does not grant or consume packs, rewards or equipment")
	check(not pilot.resume_snoozed_rewards(1100000) and game.reward_flow_calls==1,"reward screen cannot receive duplicate supply-open callbacks")
	game.screen="game";game.reward_snoozed=true
	check(not pilot.resume_snoozed_rewards(2499999) and game.reward_flow_calls==1,"the next supply menu waits the full ordinary 1.5-second UI interval")
	check(pilot.resume_snoozed_rewards(2500000) and game.reward_flow_calls==2,"unchanged pack backlog is retried after completing a build and returning to gameplay")
	game.screen="game";game.run.packs=0;game.player.pending=["gun"];game.reward_snoozed=true
	check(pilot.resume_snoozed_rewards(4000000) and game.screen=="build","snoozed legal inventory resumes the normal build UI even with no unopened packs")
	game.screen="game";game.player.pending=[];game.reward_snoozed=true
	check(not pilot.resume_snoozed_rewards(5500000),"empty snoozed reward flow does not interrupt gameplay")
	game.run.packs=1;game.reward_snoozed=false
	check(not pilot.resume_snoozed_rewards(5500000),"unsnoozed rewards retain the game's normal auto-opening behavior")
	game.reward_snoozed=true;game.run.finished=true
	check(not pilot.resume_snoozed_rewards(5500000),"finished runs never reopen supply menus")
	game.run.finished=false;game.player.parts[0].hp=0
	check(not pilot.resume_snoozed_rewards(5500000),"a dead head never opens the reward flow")
	game.player.parts[0].hp=100;game.screen="pause"
	check(not pilot.resume_snoozed_rewards(5500000),"paused gameplay is not resumed by supply retries")
	var supply_events=game.runtime_log.events.slice(events_before).filter(func(event):return event.type=="pilot_supply_resume")
	check(supply_events.size()==3 and supply_events.all(func(event):return event.action=="advance_reward_flow" and event.policy=="range_escape_v4"),"every resumed supply action is logged with its normal UI callback and policy version")
	check(game.run.elapsed==elapsed and pilot.frame_samples.is_empty(),"supply menus do not advance the normal active run clock or contribute menu FPS samples")
	game.screen="game";game.player.pending=[];game.run.packs=0;game.reward_snoozed=false
	var wall=rectangular_pit(Rect2(60,-1000,160,2000));var farther_wall=rectangular_pit(Rect2(300,-1000,80,2000))
	var distance=pilot.pilot_reachable_distance(Vector2.ZERO,Vector2.RIGHT,500,30,[farther_wall,wall])
	check(absf(distance-29.6)<.0001,"the closest hard pit stops prediction at the swept hull contact minus the same Chasm skin")
	check(absf(pilot.pilot_reachable_distance(Vector2.ZERO,Vector2.RIGHT,500,0,[wall])-59.6)<.0001,"hard-pit prediction includes the actual head collision radius")
	check(pilot.pilot_reachable_distance(Vector2.ZERO,Vector2.LEFT,500,30,[wall])==500 and pilot.pilot_reachable_distance(Vector2.ZERO,Vector2.RIGHT,500,30,[])==500,"open retreat lanes retain the entire 2.5-second travel distance")
	check(pilot.pilot_reachable_distance(Vector2.ZERO,Vector2.RIGHT,0,30,[wall])==0,"zero movement cannot predict a fabricated escape distance")
	var world=World.new();world.pits=[wall];var geometry=GeometryTrace.new();pilot.pit_geometry=geometry
	var wall_copy=wall.duplicate(true);var threat_copy=left.duplicate(true)
	var open_escape=pilot.pilot_escape_direction(Vector2.ZERO,Vector2.RIGHT,[left],[],200)
	var began=Time.get_ticks_usec()
	var wall_escape=pilot.pilot_escape_direction(Vector2.ZERO,Vector2.RIGHT,[left],[],200,world,30)
	var pit_decision_us=Time.get_ticks_usec()-began
	check(open_escape.x>.9 and absf(wall_escape.y)>.9 and absf(wall_escape.x)<.3,"escape exposure uses reachable points and rejects the false direct retreat through an undiggable pit")
	check(world.nearby_calls==1 and geometry.first_hit_calls==17 and world.move_calls==0,"all 17 headings share one nearby hard-pit set and never invoke expensive cave movement")
	check(world.observed_area.has_point(Vector2(-560,-560)) and world.observed_area.has_point(Vector2(559,559)),"the single pit query covers every heading's maximum travel plus hull clearance")
	check(wall==wall_copy and left==threat_copy,"hard-pit prediction leaves the world geometry and observed enemies unchanged")
	world.nearby_calls=0
	check(pilot.pilot_escape_direction(Vector2.ZERO,Vector2.DOWN,[],[],200,world,30).dot(Vector2.DOWN)>.999 and world.nearby_calls==0,"safe mining keeps its ordinary direction and does not query extra retreat geometry")
	var before_manual=[game.player.parts.duplicate(true),game.player.stats.duplicate(),game.run.elapsed,game.player.fuel]
	check(pilot.request_manual_input({"x":3,"y":4,"boost":true,"seconds":100},1000000) and pilot.manual_until==31000000,"manual steering is normalized and expires within thirty wall-clock seconds")
	check(pilot.apply_manual_input(2000000) and absf(Input.get_action_strength("move_right")-.6)<.00001 and absf(Input.get_action_strength("move_down")-.8)<.00001 and Input.is_action_pressed("boost"),"manual coaching uses only the same ordinary held movement and boost actions")
	check(before_manual==[game.player.parts,game.player.stats,game.run.elapsed,game.player.fuel],"manual input does not grant health, equipment, fuel or game time")
	game.screen="pause"
	check(not pilot.apply_manual_input(3000000),"manual input never resumes a paused game")
	game.screen="game"
	check(not pilot.apply_manual_input(31000000) and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("boost"),"expired manual coaching releases its controls and returns to the ordinary policy")
	check(not pilot.request_manual_input({"x":NAN,"y":0,"seconds":5},32000000),"nonfinite manual inputs are rejected")
	var fuel_reward={"id":"fuel_reward","class":"BlockReward","blockCore":"fuel"}
	var shield_reward={"id":"shield_reward","class":"BlockReward","blockCore":"shield"}
	var engineer_reward={"id":"engineer_reward","class":"BlockReward","blockCore":"engineer"}
	var attack_reward={"id":"attack_reward","class":"BlockReward","blockCore":"attack_drone"}
	game.player.parts=original[0].duplicate(true);game.player.pending=[]
	check(pilot.reward_score(fuel_reward)==185 and pilot.reward_score(shield_reward)==175,"first real FuelCore and ShieldCore receive their survival priorities")
	check(pilot.reward_score(engineer_reward)==180 and pilot.reward_score(engineer_reward)>pilot.reward_score(attack_reward),"EngineerDrone healing is identified through DroneCore.coreDrone metadata rather than generic drones")
	game.player.parts.append({"id":"repair","hp":100.0,"max_hp":100.0,"segment":2})
	check(pilot.pilot_support_count("EngineerDrone")==0 and pilot.reward_score(engineer_reward)==180,"RepairCore is not mistaken for an existing engineer healing bay")
	game.player.parts=original[0].duplicate(true);game.player.parts.append({"id":"fuel","hp":100.0,"max_hp":100.0,"segment":2})
	check(pilot.reward_score(fuel_reward)==45 and pilot.reward_score(fuel_reward)<pilot.reward_score(normal_reward),"an owned fuel tank drops to normal priority instead of being hoarded")
	game.player.parts=original[0].duplicate(true);game.player.pending=["fuel"]
	check(pilot.reward_score(fuel_reward)==45,"an already pending fuel tank also prevents redundant first-tank prioritization")
	game.player.pending=[];game.player.parts.append({"id":"shield","hp":100.0,"max_hp":100.0,"segment":2})
	check(pilot.reward_score(shield_reward)==50,"an existing live shield ends the first-shield priority")
	game.player.parts=original[0].duplicate(true);game.player.parts.append({"id":"engineer","hp":100.0,"max_hp":100.0,"segment":2})
	for i in 6:game.player.parts.append({"id":"gun","hp":100.0,"max_hp":100.0,"segment":3+i})
	check(pilot.reward_score(engineer_reward)==120,"a developed body can prefer one additional engineer healing bay")
	game.player.parts.append({"id":"engineer","hp":100.0,"max_hp":100.0,"segment":9})
	check(pilot.reward_score(engineer_reward)==45,"two live engineer bays end the additional healing priority")
	game.player.parts=original[0].duplicate(true);game.player.parts.append({"id":"fuel","hp":0.0,"max_hp":100.0,"segment":2})
	check(pilot.reward_score(fuel_reward)==185,"a destroyed tank does not count as usable fuel support")
	game.player.parts=original[0].duplicate(true);game.player.max_fuel=150;game.player.fuel=150;pilot.refueling=false
	check(pilot.pilot_boost(true,false) and not pilot.refueling,"a charged tank permits the ordinary requested boost")
	game.player.fuel=22.4
	check(not pilot.pilot_boost(true,false) and pilot.refueling,"below fifteen percent fuel begins a released-boost recharge interval")
	for fuel in [0.0,.4,30.0,89.9]:
		game.player.fuel=fuel
		check(not pilot.pilot_boost(true,false) and pilot.refueling,"fuel %.1f cannot pulse boost before the sixty-percent recharge threshold"%fuel)
	game.player.fuel=90
	check(pilot.pilot_boost(true,false) and not pilot.refueling,"sixty percent fuel restores requested boost")
	game.player.fuel=10
	var fuel_state=[game.player.fuel,game.player.max_fuel,game.player.fuel_delay,game.player.parts.duplicate(true),game.player.stats.duplicate()]
	check(not pilot.pilot_boost(true,false) and pilot.pilot_boost(true,true) and pilot.refueling,"imminent collision or dense bullets may use available reserve without cancelling recharge hysteresis")
	check(not pilot.pilot_boost(true,false),"after the emergency the low tank continues recharging")
	check(fuel_state==[game.player.fuel,game.player.max_fuel,game.player.fuel_delay,game.player.parts,game.player.stats],"boost policy does not edit fuel, delay, health, capacity or upgrades")
	game.player.fuel=0
	check(not pilot.pilot_boost(true,true),"even an emergency cannot request a zero-fuel boost pulse")
	game.player.max_fuel=0
	check(not pilot.pilot_boost(true,false) and not pilot.refueling,"no fuel module produces no automatic boost or fabricated recharge capacity")
	game.combat.enemies=[ordinary];game.combat.bullets=[];pilot.steer()
	check(not Input.is_action_pressed("boost"),"full steering releases boost when the normal body has no fuel capacity")
	game.player.max_fuel=150;game.player.fuel=10;game.combat.enemies=[actor(9,Vector2(80,0),"shield")];pilot.steer()
	check(Input.is_action_pressed("boost") and pilot.refueling,"full steering permits an ordinary reserve boost for a truly imminent contact")
	pilot.held(Vector2.ZERO)
	check(game.runtime_log.events.any(func(event):return event.type=="pilot_refuel" and event.has("fuel") and event.has("max_fuel")),"refuel transitions record their real fuel and capacity")
	pilot.free()
	var passed=checks.all(func(item):return item.passed)
	print(JSON.stringify({"suite":"conservative_pilot_policy","passed":passed,"checks":checks,"hard_pit_decision_us":pit_decision_us}))
	quit(0 if passed else 1)
