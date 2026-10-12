from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=r/'scripts/source_db.gd';s=p.read_text().replace('var textures:', 'var entities: Dictionary\nvar textures:').replace('\tpool = read_json("pool")','\tpool = read_json("pool")\n\tentities = read_json("entities")');p.write_text(s)
p=r/'scripts/combat.gd';s=p.read_text();start=s.index('func spawn(');end=s.index('\nfunc nearest(',start)
s=s[:start]+'''func source_component(components: Array, type: String) -> Dictionary:
	for c in components:
		if c["class"] == type: return c
	return {}

func entity(uid: int) -> Dictionary:
	for e in enemies:
		if e.uid == uid: return e
	return {}

func spawn_actor(prefab: String, blueprint: Dictionary, at: Vector2, role: String = "", objective: bool = false) -> Dictionary:
	var source: Dictionary = db.prefabs.get(prefab, {})
	var unit: Dictionary = blueprint.unit
	var movement: Dictionary = {}
	for c in blueprint.components:
		if str(c["class"]).ends_with("Movement"): movement = c
	var hp = float(unit.get("maxHealth", 100)) * health_modifier
	var e = {"uid": next_uid, "prefab": prefab, "source_id": blueprint.id, "name": source.get("name", blueprint.name), "kind": unit["class"], "unit": unit, "movement": movement, "position": at, "origin": at, "hp": hp, "max_hp": hp, "angle": 0.0, "cooldown": 0.0, "stun": 0.0, "guns": [], "parts": [], "radius": maxf(14.0, float(unit.get("formationSize", 1)) * 15.0), "role": role, "objective": objective, "age": 0.0, "warp": 0.0, "parent": 0, "offset": Vector2.ZERO, "render": blueprint.render, "slots": blueprint.slots, "components": blueprint.components, "group": "", "damageable": unit["class"] != "AIBossUnit", "boost_left": 0.0, "boost_cooldown": 0.0, "active": false, "range_modifier": 0.0, "damage_modifier": damage_modifier, "heat_speed": false, "target": Vector2.ZERO, "mission_controlled": false}
	next_uid += 1
	for slot in blueprint.slots:
		if slot.get("core") is String:
			e.guns.append({"id": slot.core, "cooldown": rng.randf(), "angle": 0.0, "offset": Vector2(slot.x, slot.y) * 48.0})
	enemies.append(e)
	return e

func spawn(prefab: String, at: Vector2, role: String = "", objective: bool = false) -> Dictionary:
	var definitions: Array = db.entities.get(prefab, [])
	var spawned = {}
	var first = {}
	for blueprint in definitions:
		if blueprint.unit["class"] in ["Asteroid", "ContainerObject", "MineController"]: continue
		var e = spawn_actor(prefab, blueprint, at + Vector2(blueprint.x, blueprint.y) * 48.0, role, objective)
		spawned[blueprint.id] = e
		if blueprint.parent_unit == "0" and first.is_empty(): first = e
	for blueprint in definitions:
		if not spawned.has(blueprint.id): continue
		var e: Dictionary = spawned[blueprint.id]
		if spawned.has(blueprint.parent_unit):
			var parent: Dictionary = spawned[blueprint.parent_unit]
			e.parent = parent.uid
			e.offset = e.position - parent.position
			parent.parts.append(e.uid)
			if parent.kind == "AIBossUnit":
				e.range_modifier = float(parent.unit.get("bossRangeModifer", 0))
				e.damage_modifier = float(parent.unit.get("bossDamageModifer", 1)) * damage_modifier
	for e in spawned.values():
		if e.kind != "AIBossUnit": continue
		var selected = {}
		e.hp = 0.0
		for uid in e.parts:
			var part = entity(uid)
			var type = int(part.unit.aIBossPartType)
			if not selected.has(type):
				var choices: Array = db.kind("AIBossPart").filter(func(v): return int(v.bossThreatLevel) == int(e.unit.aIThreatLevel) and int(v.aIBossPartType) == type)
				if not choices.is_empty(): selected[type] = choices[rng.randi_range(0, choices.size() - 1)]
			if selected.has(type):
				part.guns.clear()
				for i in range(selected[type].coresList.size()):
					var slot = part.slots[i] if i < part.slots.size() else {"x": 0, "y": 0}
					part.guns.append({"id": selected[type].coresList[i], "cooldown": rng.randf(), "angle": 0.0, "offset": Vector2(slot.x, slot.y) * 48.0})
			e.hp += part.hp
		e.max_hp = e.hp
	return first
''' + s[end:]
s=s.replace('var hit_count = 0','var hit_count = 0\nvar destroyed: Array = []\nvar heat = 0.0\nvar mission_target = Vector2.ZERO')
s=s.replace('if e.hp <= 0 or e.role == "friendly":','if e.hp <= 0 or not e.damageable or e.role == "friendly":').replace('return e.hp > 0 and e.role != "friendly"','return e.hp > 0 and e.damageable and e.role != "friendly"')
s=s.replace('\tfor e in enemies:\n\t\tif e.hp <= 0:', '\tfor e in enemies:\n\t\tif e.kind == "AIBossUnit":\n\t\t\te.hp = 0.0\n\t\t\tfor uid in e.parts:\n\t\t\t\te.hp += maxf(0, entity(uid).get("hp", 0))\n\t\tif e.hp <= 0:',1)
s=s.replace('\t\tvar target: Vector2 = player.head','\t\tvar target: Vector2 = player.head if not e.get("target_mission", false) else mission_target')
s=s.replace('if e.kind == "AIStation" or e.kind == "AIGuardUnitController":','if e.kind in ["AIStation", "AIStationPartController", "AIGuardUnitController", "AIBossPartController"] or e.mission_controlled:')
s=s.replace('''		if e.kind == "AIBossUnit" and fmod(e.age, 10) < 3:
			speed *= 1.7''','''		if e.kind == "AIBossUnit":
			e.active = delta.length() < float(e.unit.get("bossActionRadiuos", 30)) * 48.0
			var boost = source_component(e.components, "AIBossBoostSystem")
			e.boost_cooldown -= dt
			e.boost_left -= dt
			if e.boost_left > 0:
				speed = (float(e.movement.enginePower) + float(e.movement.get("boostEnginePower", 5))) * 48.0
			elif e.boost_left > -dt:
				e.boost_cooldown = float(boost.get("boostTimerDelay", 10))
			elif e.active and e.boost_cooldown <= 0 and delta.length() > float(boost.get("boostActivationRadious", 7.5)) * 48 and absf(angle_difference(e.angle, delta.angle())) < deg_to_rad(float(boost.get("boostActivationAngle", 25))):
				e.boost_left = float(boost.get("boostDuration", 3))
			elif e.heat_speed:
				var factor = maxf(1.0, heat) if e.active else heat
				speed *= factor * (float(e.movement.get("speedAfterTimerModifier", 2)) if factor > 1 else 1.0)
		if e.parent != 0:
			var parent = entity(e.parent)
			if not parent.is_empty():
				e.position = parent.position + Vector2(e.offset).rotated(parent.angle)
				e.angle = parent.angle
				delta = target - e.position''')
s=s.replace('e.angle = rotate_toward(e.angle, target_angle, float(e.movement.get("rotEngineModifier", 12)) * dt)','if e.boost_left <= 0: e.angle = rotate_toward(e.angle, target_angle, deg_to_rad(float(e.movement.get("enginePower", 2)) * float(e.movement.get("rotEngineModifier", 12))) * dt)')
s=s.replace('fire(core, e.position, delta.normalized(), false, {}, damage_modifier - 1.0)','fire(core, e.position + Vector2(gun.get("offset", Vector2.ZERO)).rotated(e.angle), delta.normalized(), false, {}, e.damage_modifier - 1.0)')
s=s.replace('if e.hp <= 0 or e.role == "friendly" or e.uid in b.hit:','if e.hp <= 0 or not e.damageable or e.role == "friendly" or e.uid in b.hit:')
s=s.replace('\t\tif e.hp <= 0:\n\t\t\tkills += 1','\t\tif e.hp <= 0:\n\t\t\tdestroyed.append({"uid": e.uid, "kind": e.kind, "group": e.group, "parent": e.parent, "objective": e.objective, "position": e.position, "unit": e.unit})\n\t\t\tkills += 1')
s=s.replace('other.uid != e.uid and other.role != "friendly"','other.uid != e.uid and other.damageable and other.role != "friendly"')
p.write_text(s)
p=r/'scripts/main.gd';s=p.read_text().replace('db.prefabs[e.prefab].get("render", [])','e.get("render", [])');p.write_text(s)
