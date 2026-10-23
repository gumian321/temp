extends RefCounted
## Distinct simulated attacks; damage still goes through Combat.hit_enemy.
const Art=preload("res://scripts/mutation_weapon_art.gd")
const Feedback=preload("res://scripts/weapon_feedback.gd")
const Branches=preload("res://scripts/mutation_branches.gd")
const MAX_SHOTS=128
const MAX_POOLS=32
const MAX_LARVAE=24
const LARVAE_PER_ORGAN=6
var battle_ref:WeakRef
var shots:Array=[]
var pools:Array=[]
var larvae:Array=[]
var poisoned:Dictionary={}
var serial=0
var pool_serial=0
var larva_serial=0
func _init(battle):battle_ref=weakref(battle)
func battle():return battle_ref.get_ref()
func living_target(e:Dictionary)->bool:
	return not e.is_empty() and float(e.get("hp",0))>0 and bool(e.get("damageable",false)) and e.get("role","")!="friendly" and float(e.get("warp",0))<=0
func mobile_target(e:Dictionary)->bool:
	return living_target(e) and e.get("kind","") not in ["Asteroid","ContainerObject","TraderUnit"]
func nearest_mobile(at:Vector2,reach:float)->Dictionary:
	var result:Dictionary={};var best=reach*reach
	for e in battle().target_candidates(at,reach):
		if not mobile_target(e):continue
		var distance=at.distance_squared_to(e.position)
		if distance<best:result=e;best=distance
	return result
func source_anchor(shot:Dictionary)->Dictionary:
	if int(shot.owner_uid)==0:return {"position":shot.origin}
	for i in battle().player.parts.size():
		var part:Dictionary=battle().player.parts[i]
		if int(part.get("feedback_uid",-1))==int(shot.owner_uid) and float(part.hp)>0:
			return {"position":battle().player.weapon_origin(i)}
	return {}
func fire(core:Dictionary,at:Vector2,direction:Vector2,chips:Dictionary,boost:float,source:String):
	if shots.size()>=MAX_SHOTS:return
	serial+=1
	var key=str(core.mutation_weapon)
	var branch=Branches.selected(battle().player,key)
	var data:Dictionary=battle().db.asset(core.coreProjectile)
	var dir=direction.normalized() if direction.length_squared()>.001 else Vector2.RIGHT
	var owner_uid=0
	var source_index=-1
	if source.begins_with("player:"):
		source_index=int(source.get_slice(":",1))
		if source_index>=0 and source_index<battle().player.parts.size():owner_uid=int(battle().player.parts[source_index].get("feedback_uid",0))
	var speed=float(data.projectileSpeed)*48
	if branch=="boneblade_recall":speed*=1.8
	var range_stat="17" if source_index==0 or str(core.get("name","")).begins_with("HQ_") else "3"
	var range_boost=float(battle().player.stats.get(range_stat,0))+battle().player.upgrade_bonus(core.id,"RangePercent")
	var turn_after=battle().db.range_units(core.get("turretRange",1))*48*maxf(.1,1+range_boost)/maxf(1,speed)
	var multiplier=maxf(0,1+boost)*(1+battle().special.chip("MammothDamagePercentBoost",int(chips.get(5,0))))*battle().momentum.damage_multiplier()
	var shot={"key":key,"data":data,"position":at,"previous":at,"origin":at,"velocity":dir*speed,"direction":dir,"speed":speed,"life":maxf(2.8,turn_after*2.2+.5) if key=="boneblade" else maxf(1.3,turn_after+.15),"turn_after":turn_after,"age":0.0,"damage":float(data.projectileDamage.hullDamage)*multiplier,"shield_damage":float(data.projectileDamage.shieldDamage)*multiplier,"radius":13.0 if key=="boneblade" else 8.0,"friendly":true,"chips":chips.duplicate(),"hit":[],"pierce":1000 if key=="boneblade" else 1,"fx_family":key,"owner_uid":owner_uid,"returning":false,"seed":serial,"history":PackedVector2Array([at])}
	shot.branch=branch;shot.trail_timer=.16;shot.return_damage=1.5 if branch=="boneblade_recall" else 1.0
	var count=3 if branch=="boneblade_fan" else 1
	for i in count:
		if shots.size()>=MAX_SHOTS:break
		var attack=shot.duplicate(true)
		if count==3:
			attack.direction=dir.rotated((i-1)*.30);attack.velocity=Vector2(attack.direction)*speed
			attack.damage*=.6;attack.shield_damage*=.6;attack.radius=11.0;attack.seed=serial*3+i
		shots.append(attack)
		battle().statistics.stat_BulletsFired=int(battle().statistics.get("stat_BulletsFired",0))+1
	battle().effects.append(Feedback.decorate({"kind":"muzzle","position":at,"direction":dir,"radius":5.0,"life":.12},key,true))
	battle().audio_events.append({"type":3,"position":at,"pitch":Feedback.profile(key).pitch,"gain":.7})
func secondary_hit(e:Dictionary,damage:float,key:String,at:Vector2,direction:Vector2):
	var shot={"data":battle().db.asset("expanded_"+key+"_projectile"),"position":at,"previous":at-direction*8,"origin":at-direction*8,"velocity":direction*150,"direction":direction,"damage":damage,"shield_damage":damage,"friendly":true,"chips":{},"hit":[],"pierce":1,"radius":2.0,"fx_family":key}
	battle().hit_enemy(e,shot)
func pop(shot:Dictionary,impact:bool):
	if shot.get("popped",false):return
	shot.popped=true
	if shot.key=="toxin":
		add_pool(shot,false)
	elif shot.key=="parasite" and impact:
		hatch(shot)
	shot.life=0.0
func add_pool(shot:Dictionary,trail:bool):
	var branch=str(shot.get("branch",""));var spread=branch=="toxin_spread";var dense=branch=="toxin_concentrate"
	var duration=6.0 if spread else (3.0 if dense else 4.0)
	var radius=82.0*(1.65 if spread else (.75 if dense else 1.0))
	radius*=1+battle().special.chip("MammothAreaPercentBoost",int(shot.chips.get(5,0)))
	if trail:radius*=.38
	if pools.size()>=MAX_POOLS:pools.pop_front()
	pool_serial+=1
	pools.append({"id":pool_serial,"position":shot.position,"life":duration,"duration":duration,"age":0.0,"radius":radius,"damage":float(shot.damage)*1.2*(.8 if spread else (2.4 if dense else 1.0)),"linger":3.0 if dense else 1.2,"tick":0.0,"seed":shot.seed,"branch":branch,"trail":trail})
func hatch(shot:Dictionary):
	var branch=str(shot.get("branch",""));var swarm=branch=="parasite_swarm";var hunter=branch=="parasite_hunter"
	var count=4 if swarm else (1 if hunter else 2)
	var cap=10 if swarm else (3 if hunter else LARVAE_PER_ORGAN)
	var weight=3 if hunter else 1
	for i in count:
		var population=0
		for larva in larvae:population+=int(larva.get("weight",1))
		if population+weight>MAX_LARVAE or larvae.filter(func(larva):return larva.owner_uid==shot.owner_uid).size()>=cap:break
		var collision=8.0 if hunter else (4.0 if swarm else 5.0)
		var offset=Vector2(shot.direction).orthogonal()*(float(i)-(count-1)*.5)*24
		var position=Vector2(shot.position)+offset
		if battle().terrain!=null:position=battle().terrain.move(shot.position,position,collision)
		larva_serial+=1
		larvae.append({"position":position,"velocity":Vector2(shot.direction).rotated((i-(count-1)*.5)*.22)*90,"life":8.0 if hunter else 5.0,"age":0.0,"damage":float(shot.damage)*.65*(.65 if swarm else (3.0 if hunter else 1.0)),"cooldown":.15,"owner_uid":shot.owner_uid,"seed":larva_serial,"target":0,"branch":branch,"weight":weight,"radius":collision,"speed":261.0 if hunter else 180.0,"lunge":0.0,"lunge_delay":.25,"lunge_dir":Vector2.ZERO})
func begin_return(shot:Dictionary):
	if shot.returning:return
	shot.returning=true;shot.hit.clear()
	shot.damage*=float(shot.return_damage);shot.shield_damage*=float(shot.return_damage)
func larva_target(larva:Dictionary)->Dictionary:
	if larva.branch!="parasite_swarm":return nearest_mobile(larva.position,420)
	var result:Dictionary={};var best=INF
	for e in battle().target_candidates(larva.position,420):
		if not mobile_target(e):continue
		var distance=Vector2(larva.position).distance_squared_to(e.position)
		if distance>420*420:continue
		var assigned=larvae.filter(func(other):return other.target==e.uid).size()
		var score=distance+assigned*18000
		if score<best:best=score;result=e
	return result
func step(dt:float):
	if dt<=0:return
	for pool in pools:
		pool.life-=dt;pool.age+=dt;pool.tick-=dt
		if pool.life<=0 or pool.tick>0:continue
		pool.tick+=.2
		for e in battle().area_candidates(pool.position,pool.radius+80):
			if not mobile_target(e) or Vector2(pool.position).distance_to(e.position)>float(pool.radius)+float(e.radius)*.5:continue
			if battle().cave_enabled() and not battle().terrain.ray_clear(pool.position,e.position):continue
			if not poisoned.has(e.uid):poisoned[e.uid]={"life":0.0,"damage":0.0,"tick":0.0,"sources":{},"dense":false}
			var status:Dictionary=poisoned[e.uid]
			status.sources[pool.id]={"life":pool.linger,"damage":pool.damage,"dense":pool.branch=="toxin_concentrate"}
	pools=pools.filter(func(pool):return pool.life>0)
	for uid in poisoned.keys():
		var e:Dictionary=battle().entity(int(uid));var status:Dictionary=poisoned[uid]
		status.life=0.0;status.damage=0.0;status.dense=false;status.tick+=dt
		for id in status.sources.keys():
			var exposure:Dictionary=status.sources[id];exposure.life-=dt
			if exposure.life<=0:status.sources.erase(id);continue
			status.life=maxf(status.life,exposure.life)
			if exposure.damage>status.damage:status.damage=exposure.damage;status.dense=exposure.dense
		if not mobile_target(e) or status.sources.is_empty():
			if not e.is_empty():e.erase("mutation_poison")
			poisoned.erase(uid);continue
		e.mutation_poison=status.life
		while status.tick>=.25 and living_target(e):
			status.tick-=.25
			secondary_hit(e,float(status.damage)*.25,"toxin",e.position,Vector2.UP)
	for shot in shots:
		shot.previous=shot.position;shot.age+=dt;shot.life-=dt
		if shot.key=="boneblade":
			if not shot.returning and shot.age>=float(shot.turn_after):begin_return(shot)
			if shot.returning:
				var anchor=source_anchor(shot)
				if anchor.is_empty() or Vector2(shot.position).distance_to(anchor.position)<22:shot.life=0;continue
				var desired=Vector2(shot.position).direction_to(anchor.position)
				var swift=shot.branch=="boneblade_recall"
				var angle=rotate_toward(Vector2(shot.velocity).angle(),desired.angle(),dt*(50.0 if swift else 28.0))
				shot.velocity=Vector2.from_angle(angle)*float(shot.speed)*(1.7 if swift else 1.25)
			shot.position+=Vector2(shot.velocity)*dt
		else:
			# Slow membrane projectiles have a small real lateral undulation.
			var wave=(sin(float(shot.age)*7+float(shot.seed))-sin((float(shot.age)-dt)*7+float(shot.seed)))*3.0
			shot.position+=Vector2(shot.velocity)*dt+Vector2(shot.direction).orthogonal()*wave
		var wall:Dictionary={}
		if battle().cave_enabled():wall=battle().terrain.wall_hit(shot.previous,shot.position,shot.radius)
		if not wall.is_empty():
			shot.position=Vector2(wall.position)+Vector2(wall.get("normal",-Vector2(shot.direction)))*2
		var history:PackedVector2Array=shot.history;history.append(shot.position)
		if history.size()>12:history.remove_at(0)
		shot.history=history
		for e in battle().projectile_candidates(shot):
			if not living_target(e) or e.uid in shot.hit or not battle().projectile_hits(e,shot):continue
			var contact:Dictionary=battle().visual_contact(e,shot)
			battle().hit_enemy(e,shot);shot.hit.append(e.uid)
			if shot.key!="boneblade":shot.position=contact.position;pop(shot,true);break
		if shot.key=="toxin" and shot.branch=="toxin_spread" and shot.life>0:
			shot.trail_timer-=dt
			if shot.trail_timer<=0:shot.trail_timer+=.16;add_pool(shot,true)
		if shot.key=="boneblade" and not wall.is_empty():
			if not shot.returning:begin_return(shot)
			else:shot.life=0
		elif shot.key!="boneblade" and shot.life>0 and not wall.is_empty():pop(shot,true)
		elif shot.key=="toxin" and shot.life<=0:pop(shot,false)
	shots=shots.filter(func(shot):return shot.life>0)
	for larva in larvae:
		larva.life-=dt;larva.age+=dt;larva.cooldown-=dt
		if larva.life<=0:continue
		larva.lunge_delay-=dt;larva.lunge-=dt
		var target=battle().entity(int(larva.target))
		if not mobile_target(target) or Vector2(larva.position).distance_to(target.position)>460:
			target=larva_target(larva);larva.target=int(target.get("uid",0))
		var steering=Vector2.ZERO
		if not target.is_empty():
			var slot=Vector2.from_angle(float(larva.seed)*2.39996)*(float(target.radius)+float(larva.radius)*2)
			var destination=Vector2(target.position)+slot
			steering=Vector2(larva.position).direction_to(destination)*float(larva.speed)
			var distance=Vector2(larva.position).distance_to(target.position)-float(target.radius)
			if larva.branch=="parasite_hunter" and larva.lunge_delay<=0 and distance>35 and distance<140:
				larva.lunge_dir=Vector2(larva.position).direction_to(target.position);larva.lunge=.18;larva.lunge_delay=1.2
			if Vector2(larva.position).distance_to(target.position)<float(target.radius)+24:
				steering*=.25
				if larva.cooldown<=0 and (not battle().cave_enabled() or battle().terrain.ray_clear(larva.position,target.position)):
					secondary_hit(target,float(larva.damage),"parasite",larva.position,Vector2(larva.position).direction_to(target.position));larva.cooldown=.55
		for other in larvae:
			if other==larva:continue
			var offset=Vector2(larva.position)-Vector2(other.position)
			var spacing=(float(larva.radius)+float(other.radius))*2
			if offset.length_squared()<spacing*spacing and offset.length_squared()>.01:steering+=offset.normalized()*(spacing-offset.length())*12
		if larva.lunge>0:steering=Vector2(larva.lunge_dir)*float(larva.speed)*2.3
		larva.velocity=Vector2(larva.velocity).move_toward(steering,dt*900)
		var destination=Vector2(larva.position)+Vector2(larva.velocity)*dt
		larva.position=battle().terrain.move(larva.position,destination,larva.radius) if battle().terrain!=null else destination
	larvae=larvae.filter(func(larva):return larva.life>0)
func paint_ground(canvas,time:float,zoom:float):
	var visible=canvas.get_viewport_rect().grow(180)
	for pool in pools:
		var at:Vector2=canvas.world(pool.position)
		if not visible.has_point(at):continue
		var fade=minf(1,float(pool.life)/.6)*minf(1,float(pool.age)/.15)
		var swell=1+sin(time*2+float(pool.seed))*.025
		var tint=Color(.62,.85,.65,.82*fade) if pool.branch=="toxin_concentrate" else Color(1,1,1,.56*fade)
		Art.sprite(canvas,"toxin_branches" if pool.branch=="toxin_spread" else "toxin",2,at,Vector2.ONE*float(pool.radius)*2*zoom*swell,sin(time*.4+float(pool.seed))*.04,tint)
		if pool.branch=="toxin_concentrate":Art.sprite(canvas,"toxin_branches",3,at,Vector2(38,22)*zoom,time*.35,Color(1,1,1,.7*fade))
func paint(canvas,time:float,zoom:float):
	var visible=canvas.get_viewport_rect().grow(180)
	for uid in poisoned:
		var e:Dictionary=battle().entity(int(uid))
		if e.is_empty() or not visible.has_point(canvas.world(e.position)):continue
		for i in 3:
			var phase=time*1.8+i*TAU/3
			var at:Vector2=canvas.world(Vector2(e.position)+Vector2(cos(phase),sin(phase))*float(e.radius)*.72)
			var dense=bool(poisoned[uid].dense)
			Art.sprite(canvas,"toxin_branches" if dense else "toxin",3 if dense else 1,at,Vector2.ONE*(12 if dense else 8)*zoom,phase,Color(1,1,1,.7 if dense else .55))
	for shot in shots:
		var at:Vector2=canvas.world(shot.position)
		if not visible.has_point(at):continue
		var history:PackedVector2Array=shot.history
		for i in range(1,history.size()):
			var amount=float(i)/history.size()
			var color=Feedback.profile(shot.key).accent
			canvas.draw_line(canvas.world(history[i-1]),canvas.world(history[i]),Color(color,amount*.25),maxf(.7,2*zoom*amount),true)
		var spin=float(shot.age)*(32 if shot.branch=="boneblade_recall" else 19) if shot.key=="boneblade" else Vector2(shot.velocity).angle()
		var extent=Vector2(42,38) if shot.key=="boneblade" else Vector2(28,24)
		var art_key=str(shot.key);var cell=1
		match str(shot.branch):
			"toxin_spread":extent=Vector2(33,29)
			"toxin_concentrate":art_key="toxin_branches";cell=3;extent=Vector2(38,24)
			"boneblade_fan":art_key="boneblade_branches";cell=2;extent=Vector2(35,32)
			"boneblade_recall":art_key="boneblade_branches";cell=3;extent=Vector2(48,29)
			"parasite_swarm":extent=Vector2(33,27)
			"parasite_hunter":extent=Vector2(42,34)
		if shot.key!="boneblade":extent*=1+sin(float(shot.age)*10)*.06
		Art.sprite(canvas,art_key,cell,at,extent*zoom,spin)
	for larva in larvae:
		var at:Vector2=canvas.world(larva.position)
		if not visible.has_point(at):continue
		var wriggle=sin(float(larva.age)*18+float(larva.seed))*.12
		var angle=Vector2(larva.velocity).angle()+wriggle
		var fade=minf(1,float(larva.life)/.4)
		var hunter=larva.branch=="parasite_hunter"
		var extent=Vector2(50,36) if hunter else (Vector2(20,14) if larva.branch=="parasite_swarm" else Vector2(24,17))
		if hunter and larva.lunge>0:extent*=Vector2(1.15,.88)
		Art.sprite(canvas,"parasite_branches" if hunter else "parasite",2+int(float(larva.age)*9+float(larva.seed))%2,at,extent*zoom,angle,Color(1,1,1,fade))
