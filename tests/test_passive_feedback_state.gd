extends SceneTree
var checks = []
func check(ok: bool, label: String):
	checks.append({"name":label,"passed":ok})
	if not ok: printerr(label)
func _initialize():
	var db = load("res://scripts/source_db.gd").new()
	var p = load("res://scripts/centipede.gd").new(db)
	var battle = load("res://scripts/combat.gd").new(db,p)
	var feedback = load("res://scripts/reward_feedback_state.gd")
	var count = 0
	var classes = {}
	for reward in db.catalog.values():
		if reward.get("class", "") not in feedback.CLASSES: continue
		count += 1
		classes[reward["class"]] = true
		var event = p.reward_feedback(reward)
		check(event.reward_id == reward.id and event.reward_class == reward["class"] and not event.status.is_empty(), "Mapped " + reward.name)
		if reward["class"] == "BlockReward": check(event.status == "pending_module" and event.part_uids.is_empty(), "Module waits for install " + reward.name)
		if reward["class"] == "CountBasicReward": check(event.status == "pending_charge" and event.part_uids.is_empty(), "Build action is only a charge " + reward.name)
	check(count == 144 and classes.size() == 12,"All 129 source rewards, nine added weapon rewards and six branches map to 12 reachable classes")
	var pooled = {}
	for pack in db.kind("RewardPack"):
		for id in pack.packRewardsList: pooled[id] = true
	pooled[db.stores.RewardDataStore.packReward] = true
	var chain_count = 0
	for id in pooled:
		var reward: Dictionary = db.asset(id)
		check(reward.get("class") in feedback.CLASSES,"Reachable pack entry mapped " + str(id))
		if reward.get("class") != "CountBasicReward" or int(reward.rewardType) not in [8,9,20]: chain_count += 1
	check(pooled.size() == 128 and chain_count == 126,"Live pool covers 117 source rewards minus four retired actions plus 15 weapon/branch rewards")
	p.add_piece(db.named("Core_Shield").id,Vector2i(-1,0))
	p.take_feedback_events()
	p.add_piece(db.named("Core_Repair").id,Vector2i(-2,0))
	p.take_feedback_events()
	var save = load("res://scripts/save_store.gd").new(db)
	save.fresh()
	var run = load("res://scripts/run_state.gd").new(db,save,p,battle,db.kind("Mission")[0],0)
	var wall_reward: Dictionary = db.kind("CountBasicReward").filter(func(r):return int(r.rewardType) == 21 and int(r.rewardCount) == 2)[0]
	save.state.unlocked.append(wall_reward.id)
	run.rewards.enqueue(true)
	run.offers = [wall_reward]
	var armor_before = p.parts[1].max_hp
	check(run.take_reward(wall_reward),"Offered reinforcement reward can be acquired")
	var acquisition = p.take_feedback_events()
	check(acquisition.size() == 1 and acquisition[0].status == "pending_charge" and p.parts[1].max_hp == armor_before and not p.parts[1].wall,"Actual reward acquisition banks charge without claiming armor")
	check(not run.take_reward(wall_reward) and p.take_feedback_events().is_empty(),"Repeated selection cannot emit acquisition again")
	var original_uid = p.parts[1].feedback_uid
	var hp = p.parts[1].hp
	p.actions.wall = 1
	check(p.reinforce(1) and p.parts[1].hp > hp and p.passive_state(1).reinforced,"Reinforce mutates armor only on action")
	var events = p.take_feedback_events()
	check(events.size() == 1 and events[0].kind == "reinforced" and events[0].part_uids == [original_uid],"Reinforce emits exactly one targeted event")
	check(p.take_feedback_events().is_empty(),"Drained events do not replay")
	p.step_feedback(3)
	check(p.parts[1].feedback_pulses.is_empty(),"Transient pulses expire")
	for i in range(80): p.emit_feedback("reward")
	check(p.feedback_events.size() == 64,"Event buffer bounded")
	p.step_feedback(3)
	check(p.feedback_events.is_empty(),"Unconsumed events expire")
	var shield_upgrade = db.kind("ShieldLevelUpReward")[0]
	check(p.reward_feedback(shield_upgrade).status == "active","Installed upgrade has affected target")
	p.parts[1].hp = 0
	check(p.reward_feedback(shield_upgrade).status == "dormant","Destroyed target makes upgrade dormant")
	p.levels[shield_upgrade.id] = 1
	p.refresh_upgrades()
	check(p.parts[1].hp == 0,"Refreshing upgrade never revives destroyed module")
	p.reset()
	check(p.feedback_events.is_empty() and p.actions.wall == 0 and p.levels.is_empty(),"Restart clears feedback and acquired state")
	p.change_stat(10,-0.25)
	p.refresh_upgrades()
	check(p.parts[0].hp == p.parts[0].max_hp and p.parts[0].hp < 500,"Health curse clamps current health to reduced maximum")
	var hq_shield = db.named("Reward_HQ_Shield").core
	p.set_hq_weapon(hq_shield)
	check(p.effective_core(0).get("class") == "ShieldCore" and p.parts[0].shield > 0,"HQ shield equip initializes actual capacity")
	var before = p.parts[0].hp
	battle.hurt_player(0,10,99999)
	check(p.parts[0].hp == before and p.parts[0].shield_broken,"HQ shield intercepts and breaks on actual hit")
	check(p.parts[0].feedback_pulses.has("shield_break"),"Break trigger produces feedback")
	battle.step(p.parts[0].shield_delay + 0.01,Vector2.RIGHT,false,false)
	check(p.parts[0].shield > 0 and p.parts[0].feedback_pulses.has("shield_recharge"),"HQ shield recovers with recharge feedback")
	p.set_hq_weapon(db.stores.PlayerDataStore.mainTurretCore)
	check(p.parts[0].shield == 0 and not p.parts[0].shield_broken and p.passive_state(0).shield_capacity == 0,"Switching away removes stale shield state")
	battle.hurt_player(0,7,7)
	check(p.parts[0].hp == before - 7,"Old HQ shield no longer intercepts")
	p.add_piece(db.named("Core_Repair").id,Vector2i(-1,0))
	p.parts[0].hp -= 20
	battle.step(0.1,Vector2.RIGHT,false,false)
	check(p.parts[1].feedback_pulses.has("repair") and p.parts[0].feedback_pulses.has("healed"),"Repair feedback requires actual damaged recipient")
	p.parts[0].hp = p.parts[0].max_hp
	p.parts[1].hp = p.parts[1].max_hp
	battle.step(0.5,Vector2.RIGHT,false,false)
	check(not p.parts[1].feedback_pulses.has("repair"),"Full-health support does not claim repair")
	p.add_piece(db.named("Core_Shield").id,Vector2i(-2,0))
	p.actions.swap = 1
	var uid = p.parts[1].feedback_uid
	p.swap_piece(1,2)
	check(p.parts[1].feedback_uid == uid,"Part identity survives reordering")
	var chain = load("res://scripts/chain_centipede.gd").new(db)
	chain.levels[shield_upgrade.id] = 2
	check(chain.reward_feedback(shield_upgrade).status == "dormant","Upgrade without matching module stays dormant")
	chain.append_segment(db.named("Core_Shield").id)
	var installed = chain.take_feedback_events()
	check(installed.size() == 1 and installed[0].kind == "installed" and chain.parts[1].feedback_pulses.has("installed"),"Live chain install emits targeted feedback")
	check(chain.passive_state(1).upgrade_levels.get(shield_upgrade.id,0) == 2,"Later install inherits persistent upgrade rank")
	var hq_health = db.kind("PercentBasicReward").filter(func(r):return int(r.rewardType) == 10)[0]
	check(chain.reward_feedback(hq_health).part_uids == [chain.parts[0].feedback_uid],"HQ-only stat targets only HQ")
	chain.append_segment(db.named("Core_Chip_Mammoth").id)
	check(chain.passive_state(2).chip_links == [1],"Compatible chip link uses current spine adjacency")
	chain.pulse_chip_sources(1)
	check(chain.parts[2].feedback_pulses.has("chip_trigger"),"Actual modified action pulses its supplying chip")
	chain.parts[2].hp = 0
	check(chain.passive_state(2).chip_links.is_empty() and chain.chips(1).is_empty(),"Dead chip loses links and gameplay modifier")
	chain.parts[2].hp = chain.parts[2].max_hp
	chain.append_segment(db.named("Core_Clocking").id)
	chain.append_segment(db.named("Core_Shield").id)
	var cb = load("res://scripts/combat.gd").new(db,chain)
	cb.step(0.01,Vector2.RIGHT,false,false)
	check(chain.parts[4].cloaked and chain.parts[4].feedback_pulses.has("cloak") and not chain.parts[0].cloaked,"Cloak acquisition pulse follows actual coverage, excludes HQ")
	chain.parts[3].stun = 1.0
	cb.step(0.01,Vector2.RIGHT,false,false)
	check(not chain.parts[4].cloaked,"Stunned cloak source removes actual coverage")
	var report = {"checks":checks,"passed":checks.all(func(c):return c.passed),"reward_count":count,"class_count":classes.size()}
	FileAccess.open("res://artifacts/passive-feedback-state-test-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
