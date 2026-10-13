extends RefCounted
# Presentation metadata only. Never consumes gameplay RNG or changes rewards.
const CLASSES = ["BlockReward", "CountBasicReward", "PercentBasicReward", "CrusedReward", "MainCoreTurretReward", "MainCoreDroneReward", "TurretLevelUpReward", "DroneLevelUpReward", "MineFieldLevelUpReward", "ShieldLevelUpReward", "FuelTankLevelUpReward", "LevelUpReward"]

static func describe(player, reward: Dictionary, drones: Array = []) -> Dictionary:
	var kind = str(reward.get("class", ""))
	var result = {"kind":"reward", "reward_id":reward.get("id", ""), "reward_class":kind, "title":player.db.title(reward), "status":"active", "part_uids":[], "details":{}, "life":2.0}
	var details: Dictionary = result.details
	match kind:
		"BlockReward":
			result.status = "pending_module"
			details.target_ids = [reward.blockCore]
			details.count = player.reward_module_count(reward)
		"CountBasicReward":
			result.status = "pending_charge"
			details.action = {8:"swap",9:"duplicate",20:"move",21:"wall"}.get(int(reward.rewardType), "")
			details.count = int(reward.get("count", reward.get("rewardCount", 1)))
		"PercentBasicReward", "CrusedReward":
			details.stat_changes = {str(reward.rewardType):float(reward.percent)} if kind == "PercentBasicReward" else {str(reward.buffRewardType):float(reward.buffPercent), str(reward.debuffRewardType):float(reward.debuffPercent)}
			for i in range(player.parts.size()):
				if player.parts[i].hp <= 0: continue
				for stat in details.stat_changes:
					if stat_affects_part(player,i,int(stat),drones):
						result.part_uids.append(player.parts[i].feedback_uid)
						break
		"MainCoreTurretReward", "MainCoreDroneReward":
			result.part_uids.append(player.parts[0].feedback_uid)
			details.target_ids = [reward.get("core", reward.get("drone", ""))]
		_:
			details.target_ids = reward.get("coresList", []).duplicate()
			details.level = int(player.levels.get(reward.get("id", ""), 0))
			details.modifiers = {}
			for field in reward:
				if field.ends_with("Percent") or field == "addDronesCount": details.modifiers[field] = reward[field]
			for i in range(player.parts.size()):
				var p: Dictionary = player.parts[i]
				if p.hp <= 0: continue
				if p.id in details.target_ids or player.effective_core(i).get("id", "") in details.target_ids:
					result.part_uids.append(p.feedback_uid)
			for drone in drones:
				if drone.data.id in reward.get("dronesList", []) and drone.owner < player.parts.size() and player.parts[drone.owner].hp > 0:
					var uid = player.parts[drone.owner].feedback_uid
					if uid not in result.part_uids: result.part_uids.append(uid)
			if result.part_uids.is_empty(): result.status = "dormant"
	return result

static func snapshot(player, index: int) -> Dictionary:
	if index < 0 or index >= player.parts.size(): return {}
	var p: Dictionary = player.parts[index]
	var core: Dictionary = player.effective_core(index)
	var active = p.hp > 0 and p.stun <= 0
	var state = {"uid":p.feedback_uid, "position":p.position, "alive":p.hp > 0, "active":active, "reinforced":bool(p.wall), "cloaked":bool(p.get("cloaked",false)), "shield":float(p.shield) if core.get("class") == "ShieldCore" else 0.0, "shield_capacity":float(core.get("maxShieldHealth",0)) * (1 + player.upgrade_bonus(core.id,"ShieldHealthPercent")), "shield_delay":float(p.shield_delay), "shield_broken":bool(p.shield_broken), "repair_targets":[], "chip_links":[], "chips":player.chips(index), "upgrades":[], "upgrade_levels":{}, "pulses":p.get("feedback_pulses",{}).duplicate()}
	for id in player.levels:
		var reward: Dictionary = player.db.asset(id)
		if p.id in reward.get("coresList",[]) or core.id in reward.get("coresList",[]):
			state.upgrades.append(id)
			state.upgrade_levels[id] = int(player.levels[id])
	if active and core.get("class") == "RepairCore":
		for other in player.adjacent_part_indices(index,true):
			if player.parts[other].hp > 0 and player.parts[other].hp < player.parts[other].max_hp: state.repair_targets.append(other)
	if p.hp > 0 and core.has("coreChip"):
		var chip_type = int(player.db.asset(core.coreChip).chipType)
		for other in player.adjacent_part_indices(index):
			if player.parts[other].hp > 0 and player.chips(other).has(chip_type): state.chip_links.append(other)
	return state

static func stat_affects_part(player, index: int, stat: int, drones: Array = []) -> bool:
	if stat in [10,11,12]: return index == 0
	if stat == 16: return index > 0
	var core: Dictionary = player.effective_core(index)
	if stat in [13,14,17]:
		return index == 0 and core.has("coreProjectile") and (stat != 13 or player.db.asset(core.coreProjectile).get("class") != "ContinuousProjectile")
	if stat == 3: return index > 0 and core.has("coreProjectile")
	if stat in [2,15]:
		if index > 0 and core.has("coreProjectile") and (stat != 2 or player.db.asset(core.coreProjectile).get("class") != "ContinuousProjectile"): return true
		if core.has("coreDrone") and player.db.asset(core.coreDrone).get("class") == "ProjectileDrone": return true
		for drone in drones:
			if drone.owner == index and drone.data.get("class") == "ProjectileDrone": return true
	return false
