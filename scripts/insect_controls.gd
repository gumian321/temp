extends RefCounted
## Bounded gameplay control, independent of cosmetic weapon families and save IDs.
const MAX_ACTIVE = 32
const SILK_DURATION = 0.8
const PULL_DURATION = 0.32
const RECOVERY = 0.9
const PULL_DISTANCE = 64.0
const PULL_SPEED = 200.0
const Knockback=preload("res://scripts/knockback.gd")
const Tether=preload("res://scripts/tether_motion.gd")
var active: Array = []
var released: Array = []
var emitter_poses:Dictionary={}
var elapsed = 0.0
var serial = 0

static func attack_for(turret: Dictionary) -> String:
	match str(turret.get("name", "")):
		"Turret_Gun_EMP": return "silk"
		"Turret_Gun_Tesla": return "tendril"
	return ""

static func eligible(e: Dictionary, friendly: bool) -> bool:
	return float(e.get("hp",0)) > 0 and float(e.get("warp",0)) <= 0 and not e.get("despawn",false) and bool(e.get("damageable",true)) and (e.get("role","") != "friendly") == friendly and int(e.get("parent",0)) == 0 and not bool(e.get("mission_controlled",false)) and str(e.get("kind","")) in ["AISwarmingUnit", "AIFollowingUnit", "AIPatrolUnit", "TraderUnit"] and bool(e.get("unit",{}).get("canBeStunned",true))

func attach(e: Dictionary, b: Dictionary) -> bool:
	var kind = str(b.get("insect_attack",""))
	if kind not in ["silk","tendril"] or not eligible(e,bool(b.get("friendly",true))): return false
	if active.size() >= MAX_ACTIVE or e.has("insect_control") or elapsed < float(e.get("insect_recovery_until",0)): return false
	serial += 1
	var duration = SILK_DURATION if kind == "silk" else PULL_DURATION
	var control = {"kind":kind,"target":e,"origin":Vector2(b.get("origin",b.get("position",e.position))),"life":duration,"duration":duration,"friendly":bool(b.get("friendly",true)),"serial":serial,"remaining_pull":PULL_DISTANCE,"source_key":str(b.get("control_source","")),"source_token":int(b.get("control_source_token",0))}
	active.append(control)
	control.tether=Tether.create(control.origin,e.position,serial)
	# Store only the serial on the actor: no reference cycle and no duplicated actor graphs.
	e.insect_control = serial
	e.insect_control_friendly = bool(b.get("friendly",true))
	e.insect_silk_until = elapsed + duration if kind == "silk" else elapsed
	e.insect_recovery_until = elapsed + duration + RECOVERY
	return true

func movement_factor(e: Dictionary, dt: float) -> float:
	var recovery=Knockback.drive_factor(e)
	if dt <= 0 or not e.has("insect_control") or not eligible(e,bool(e.get("insect_control_friendly",true))): return recovery
	var covered = minf(dt,maxf(0,float(e.get("insect_silk_until",0))-elapsed))
	return (1.0 - 0.65 * covered / dt)*recovery

func advance(dt: float, battle):
	dt = maxf(0,dt)
	Tether.advance_released(released,dt)
	if dt>0:follow_released_origins(battle)
	for c in active.duplicate():
		var e: Dictionary = c.target
		if not eligible(e,c.friendly) or not battle.enemies.has(e):
			release(c);continue
		var key = str(c.source_key)
		if key.begins_with("player:"):
			var index = -1
			for i in range(battle.player.parts.size()):
				if int(c.source_token) > 0 and int(battle.player.parts[i].get("insect_source_token",0)) == int(c.source_token):
					index=i;break
			if index < 0 or index >= battle.player.parts.size() or battle.player.parts[index].hp <= 0:
				release(c);continue
			c.origin = battle.player.weapon_origin(index)
		elif key.begins_with("enemy:"):
			var source: Dictionary = battle.entity(int(key.get_slice(":",1)))
			if source.is_empty() or source.hp <= 0 or (source.get("role","")=="friendly") != bool(c.friendly):
				release(c);continue
			c.origin = source.position
			if key.get_slice_count(":") > 2:
				var gun_index = int(key.get_slice(":",2))
				if gun_index < 0 or gun_index >= source.guns.size():
					release(c);continue
				c.origin += Vector2(source.guns[gun_index].get("offset",Vector2.ZERO)).rotated(float(source.angle))
		var covered = minf(dt,maxf(0,c.life))
		if c.kind == "tendril":
			var delta = Vector2(c.origin) - Vector2(e.position)
			# Stop outside contact range; cumulative distance remains capped even if the source moves.
			var distance = minf(minf(PULL_SPEED*covered,c.remaining_pull),maxf(0,delta.length()-maxf(48,float(e.get("radius",14))+24)))
			e.position += delta.normalized()*distance
			if distance>0:preload("res://scripts/soft_insect.gd").pull(e,delta,distance/covered,covered)
			c.remaining_pull -= distance
		var struggle=preload("res://scripts/soft_insect.gd").struggle(e.get("soft_body",{}))
		Tether.step(c.tether,c.origin,e.position,.98 if c.kind=="tendril" else .75,struggle,covered)
		c.life = maxf(0,c.life-dt)
		if c.life <= 0: release(c)
	elapsed += dt
	if dt>0:rebuild_emitter_poses()

static func emitter_key(source:String,token:int=0)->String:
	return "player:"+str(token) if source.begins_with("player:") and token>0 else source

func emitter_pose(source:String,token:int=0)->Dictionary:
	if source.begins_with("player:") and token<=0:return {}
	return emitter_poses.get(emitter_key(source,token),{})

func rebuild_emitter_poses():
	emitter_poses.clear()
	var groups={}
	for c in active+released:
		var key=emitter_key(str(c.get("source_key","")),int(c.get("source_token",0)))
		if key.is_empty():continue
		if not groups.has(key):groups[key]=[]
		groups[key].append(c.get("tether",c))
	for key in groups:
		var pose=Tether.combine_reactions(groups[key])
		emitter_poses[key]=pose
		for motion in groups[key]:motion.emitter_offset=pose.offset

func release(c: Dictionary):
	if not active.has(c):return
	Tether.append_release(released,c.tether,c.kind,c.friendly)
	released[-1].source_key=c.source_key
	released[-1].source_token=c.source_token
	var e: Dictionary = c.target
	if int(e.get("insect_control",-1)) == int(c.serial):
		e.erase("insect_control")
		e.erase("insect_silk_until")
		e.erase("insect_control_friendly")
	active.erase(c)

func follow_released_origins(battle):
	for motion in released:
		var key=str(motion.get("source_key",""))
		if key.begins_with("player:"):
			for i in battle.player.parts.size():
				if int(motion.source_token)>0 and int(battle.player.parts[i].get("insect_source_token",0))==int(motion.source_token) and battle.player.parts[i].hp>0:
					motion.release_origin=battle.player.weapon_origin(i);break
		elif key.begins_with("enemy:"):
			var source:Dictionary=battle.entity(int(key.get_slice(":",1)))
			if source.is_empty() or source.hp<=0:continue
			var origin=Vector2(source.position)
			if key.get_slice_count(":")>2:
				var index=int(key.get_slice(":",2))
				if index<0 or index>=source.guns.size():continue
				origin+=Vector2(source.guns[index].get("offset",Vector2.ZERO)).rotated(float(source.angle))
			motion.release_origin=origin
