extends RefCounted
var battle_ref: WeakRef
var db
var player
var mines: Array = []
var black_holes: Array = []
func _init(battle):
	battle_ref = weakref(battle)
	db = battle.db
	player = battle.player
func battle(): return battle_ref.get_ref()
func chip(field: String, level: int) -> float:
	if level<=0: return 0.0
	var values = db.stores.ChipsDataStore[field]
	if values is String: values = db.packed(values)
	return float(values[clampi(level-1,0,values.size()-1)])
func add_black_hole(b: Dictionary):
	var data: Dictionary = b.data
	black_holes.append({"position":b.position,"life":float(data.projectileEffectAreaDuration),"radius":float(data.projectileEffectArea)*48*(1+chip("MammothAreaPercentBoost",int(b.chips.get(5,0)))),"damage":float(data.projectileDamage.hullDamage),"shield_damage":float(data.projectileDamage.shieldDamage),"friendly":b.friendly,"force":float(db.component(data.blackHoleObject,"BlackHoleController").get("maxForce",10))*48})
func step(dt: float):
	var cloakers=player.parts.filter(func(p):return db.asset(p.id).get("name")=="Core_Clocking")
	for i in range(player.parts.size()):
		var p: Dictionary = player.parts[i]
		var c: Dictionary = db.asset(p.id)
		p.cloaked = false
		if i>0 and c.get("isClockable",false):
			for neighbor in cloakers:
				if neighbor.hp>0 and neighbor.stun<=0 and abs(neighbor.cell.x-p.cell.x)<=1 and abs(neighbor.cell.y-p.cell.y)<=1: p.cloaked = true
		if p.hp<=0:
			if not p.get("destroy_processed",false):
				p.destroy_processed = true
				battle().spawn_scraps(p.position,int(c.get("coreScraps",0)))
				if c["class"]=="PackCore":
					for j in range(battle().rng.randi_range(int(c.minPacksCount),int(c.maxPacksCount))): battle().loot.append({"position":p.position,"value":0,"pack":true})
			continue
		if p.stun>0 or c["class"] not in ["MinesCore","MineSpawnerCore"]: continue
		if p.cooldown>0: continue
		var count = 1
		var anchored = c["class"]=="MinesCore"
		var choices: Array = []
		if anchored:
			var maximum = int(float(c.maxMinesCount)*(1+player.upgrade_bonus(c.id,"maxMinesCountPercent")))
			if mines.filter(func(m): return m.owner==i and m.anchored).size()>=maximum: continue
			p.cooldown = 1.0/maxf(0.05,float(c.minesRechargeRate)*(1+player.upgrade_bonus(c.id,"minesRechargeRatePercent")))
			for x in range(-3,4):
				for y in range(-3,4):
					if (abs(x)==3 or abs(y)==3) and not player.occupied(p.cell+Vector2i(x,y)): choices.append(Vector2(x,-y)*48)
		else:
			if player.velocity.length()<1: continue
			p.cooldown = float(c.minesSpawnRate)*(1+player.upgrade_bonus(c.id,"minesRechargeRatePercent"))
			count = int(c.minesCountPerSpawn)
			for j in range(count): choices.append(Vector2((float(j)-float(count)*0.5)*8,-48))
		if choices.is_empty(): continue
		for j in range(count):
			var offset: Vector2 = choices[battle().rng.randi_range(0,choices.size()-1)]
			mines.append({"owner":i,"anchored":anchored,"offset":offset,"position":p.position+offset,"life":INF if anchored else 7.0,"data":db.asset(c.coreMine),"chips":player.chips(i)})
	for mine in mines:
		mine.life -= dt
		if mine.anchored:
			if mine.owner>=player.parts.size() or player.parts[mine.owner].hp<=0: mine.life=0; continue
			mine.position = player.parts[mine.owner].position + Vector2(mine.offset).rotated(player.facing.angle())
		var enemy = battle().nearest(mine.position,24)
		if enemy.is_empty(): continue
		var projectile = {"class":"BasicProjectile","projectileDamage":mine.data.mineDamage}
		var b = {"position":mine.position,"data":projectile,"damage":float(mine.data.mineDamage.hullDamage),"shield_damage":float(mine.data.mineDamage.shieldDamage),"friendly":true,"chips":mine.chips,"velocity":Vector2.RIGHT,"pierce":1,"hit":[]}
		battle().hit_enemy(enemy,b)
		mine.life=0
	mines = mines.filter(func(m):return m.life>0)
	for hole in black_holes:
		hole.life-=dt
		for e in battle().enemies:
			if e.hp<=0 or not e.damageable or (e.role=="friendly" if hole.friendly else e.role!="friendly"): continue
			if e.position.distance_to(hole.position)<hole.radius:
				e.hp-=hole.damage*dt
				if not e.mission_controlled and e.parent==0: e.position = Vector2(e.position).move_toward(hole.position,hole.force*dt)
		if not hole.friendly:
			for i in range(player.parts.size()):
				if player.parts[i].position.distance_to(hole.position)<hole.radius: battle().hurt_player(i,hole.damage*dt,hole.shield_damage*dt)
	black_holes = black_holes.filter(func(h): return h.life>0)
func continuous(core: Dictionary,at: Vector2,dir: Vector2,friendly: bool,chips: Dictionary,boost: float,dt: float,visual_owner:String=""):
	var projectile = db.asset(core.coreProjectile)
	var reach = db.range_units(core.get("turretRange",1))*48*(1+chip("MammothAreaPercentBoost",int(chips.get(5,0))))
	var damage = float(projectile.projectileDamage.hullDamage)*(1+boost)*(1+chip("MammothDamagePercentBoost",int(chips.get(5,0))))*dt
	var shield_damage = float(projectile.projectileDamage.shieldDamage)*(1+boost)*dt
	for e in battle().enemies:
		if e.hp<=0 or not e.damageable or (e.role=="friendly" if friendly else e.role!="friendly"): continue
		var delta: Vector2 = e.position-at
		if delta.length()<reach and absf(angle_difference(dir.angle(),delta.angle()))<0.2:
			battle().hit_enemy(e,{"data":projectile,"damage":damage,"shield_damage":shield_damage,"position":at,"friendly":friendly,"chips":{},"velocity":dir,"pierce":1})
	if not friendly:
		for i in range(player.parts.size()):
			var delta: Vector2 = player.parts[i].position-at
			if delta.length()<reach and absf(angle_difference(dir.angle(),delta.angle()))<0.2: battle().hurt_player(i,damage,shield_damage)
	battle().effects.append({"position":at,"end":at+dir*reach,"radius":reach,"life":0.06,"kind":"flame","owner":visual_owner})
