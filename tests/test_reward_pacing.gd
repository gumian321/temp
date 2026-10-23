extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Save=preload("res://scripts/save_store.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Run=preload("res://scripts/run_state.gd")
var db
var checks:Array=[]
var samples:Array=[]
func check(value:bool,title:String):
	checks.append({"name":title,"passed":value})
	if not value:printerr("FAIL: ",title)
func _initialize():call_deferred("execute")
func fixture(seed_value:int,all_unlocked:bool=false)->Dictionary:
	var save=Save.new(db,"user://reward-pacing.json",false)
	if all_unlocked:
		save.state.unlocked=db.catalog.values().filter(func(reward):return str(reward.get("class","")).ends_with("Reward") and not reward.get("retired",false)).map(func(reward):return reward.id)
	var player=Body.new(db);var battle=Battle.new(db,player)
	var run=Run.new(db,save,player,battle,db.named("Survival Mission"),0)
	run.rng.seed=seed_value
	return {"save":save,"player":player,"battle":battle,"run":run}
func owned_weapons(f:Dictionary)->Array:
	var result:Array=[]
	for i in f.player.parts.size():
		var core:Dictionary=f.player.effective_core(i)
		if core.has("coreProjectile") or core.has("coreDrone") or core.get("class") in ["MinesCore","MineSpawnerCore"]:
			result.append(db.armament_variant(core))
	return result
func new_body_weapon(reward:Dictionary,owned:Array)->bool:
	if reward.get("class")!="BlockReward":return false
	var core=db.asset(reward.blockCore)
	var offensive=core.has("coreProjectile") or core.get("class") in ["MinesCore","MineSpawnerCore"] or db.asset(core.get("coreDrone","")).get("class")=="ProjectileDrone"
	return offensive and db.armament_variant(core) not in owned
func install_pending(f:Dictionary):
	while not f.player.pending.is_empty():
		if not f.player.add_piece(f.player.pending[0],f.player.next_segment_cell()):break
		f.player.pending.pop_front()
func execute():
	db=DB.new()
	var overlap_total=0;var adjacent_pairs=0;var same_hands=0;var repeated_pairs=0;var all_selectable=true;var distinct=true;var early_variety=true;var support_choices=true;var upgrades=0;var dormant=0
	for seed_value in range(24):
		var f=fixture(30200+seed_value,seed_value>=12)
		var recent:Array=[];var opening:Array=[]
		for round_index in 12:
			var owned=owned_weapons(f)
			f.run.rewards.enqueue(true)
			var offers=f.run.roll_rewards()
			all_selectable=all_selectable and offers.size()==3 and offers.all(func(reward):return f.run.can_reward(reward))
			var families=offers.map(func(reward):return f.run.rewards.pacing.family(reward))
			for i in families.size():distinct=distinct and families.count(families[i])==1
			if round_index<3:
				var novel_count=offers.filter(func(reward):return new_body_weapon(reward,owned)).size()
				if novel_count<2:print("OPENING_DIAGNOSTIC ",JSON.stringify({"seed":seed_value,"round":round_index,"owned":owned,"cards":offers.map(func(reward):return {"name":reward.name,"variant":db.armament_variant(reward),"core_class":db.asset(reward.get("blockCore","")).get("class","")})}))
				early_variety=early_variety and novel_count>=2
				var has_support=offers.any(func(reward):return not new_body_weapon(reward,owned) and (reward.get("class")!="MainCoreTurretReward" or db.asset(reward.core).get("class")=="ShieldCore"))
				if not has_support:print("SUPPORT_DIAGNOSTIC ",JSON.stringify({"seed":seed_value,"round":round_index,"cards":offers.map(func(reward):return reward.name)}))
				support_choices=support_choices and has_support
				opening.append(offers.map(func(reward):return db.title(reward)))
			if not recent.is_empty():
				var overlap=families.filter(func(key):return key in recent.back()).size()
				overlap_total+=overlap;adjacent_pairs+=1
				if overlap==3:same_hands+=1
			if recent.size()>=2 and families.filter(func(key):return key in recent[-1] and key in recent[-2]).size()>=2:repeated_pairs+=1
			recent.append(families)
			for reward in offers:
				if "LevelUp" in str(reward.get("class","")):
					upgrades+=1
					if f.player.reward_feedback(reward,f.battle.drones).status=="dormant":dormant+=1
			var preferred=offers.filter(func(reward):return new_body_weapon(reward,owned))
			var selected:Dictionary=preferred[0] if not preferred.is_empty() else offers[round_index%offers.size()]
			check(f.run.take_reward(selected),"A paced choice is accepted: seed %d, round %d"%[seed_value,round_index])
			install_pending(f)
		if seed_value in [0,12]:samples.append({"profile":"initial" if seed_value==0 else "all_unlocked","first_three_hands":opening})
	check(all_selectable,"All 864 normal offered cards are unlocked, enabled and currently usable")
	check(distinct,"No hand repeats a weapon across body, head, upgrade or quantity tiers")
	check(early_variety and support_choices,"Each of the first three hands offers two different unowned body weapons plus another choice")
	check(same_hands==0,"No identical adjacent hands across 24 seeded twelve-choice runs")
	check(repeated_pairs==0,"No pair of weapon/effect families persists across three successive hands")
	check(float(overlap_total)/adjacent_pairs<=1.0,"Adjacent hands average at most one shared weapon/effect family")
	check(upgrades>0 and dormant==0,"Equipped weapon upgrades appear without unrelated stored upgrades filling ordinary hands")
	var cached=fixture(991)
	cached.run.rewards.enqueue(true);var first=cached.run.roll_rewards().duplicate(true);var rng_state=cached.run.rng.state;var history=cached.run.rewards.pacing.history.duplicate(true)
	for i in 20:check(cached.run.roll_rewards()==first,"Reopening retains the same offered cards %d"%i)
	check(cached.run.rng.state==rng_state and cached.run.rewards.pacing.history==history,"Reopening consumes no RNG and no extra anti-repeat history")
	cached.run.rewards.recycle();cached.run.rewards.enqueue(true);cached.run.roll_rewards()
	check(cached.run.rewards.pacing.history.size()==2,"Recycling records the displayed hand and advances once on the next reveal")
	var fresh=fixture(991);fresh.run.rewards.enqueue(true)
	check(fresh.run.roll_rewards()==first,"A new run resets history and reproduces an explicitly seeded opening")
	var narrow=fixture(123)
	var gun=db.named("Reward_Block_Gun_Gatling");var shotgun=db.named("Reward_Block_Gun_Shotgun")
	narrow.save.state.unlocked=[gun.id,db.named("Reward_Block_Gun_Gatling_2").id,db.named("Reward_HQ_Gun_Gatling").id,shotgun.id]
	narrow.run.rewards.enqueue(true);var few=narrow.run.roll_rewards()
	check(few.size()==2 and few.all(func(reward):return narrow.run.can_reward(reward)),"Two available weapon families produce two genuine options instead of duplicate or locked filler")
	narrow.run.rewards.consume();narrow.run.offers.clear();narrow.save.state.disabled=narrow.save.state.unlocked.duplicate()
	narrow.run.rewards.enqueue(true)
	check(narrow.run.roll_rewards().is_empty() and narrow.run.packs==1,"An exhausted pool retains its reward for postponing or recycling without inventing an unlock")
	var filtered=fixture(918,true);var bonus=db.stores.RewardDataStore.packReward
	filtered.save.state.disabled=[bonus,"expanded_toxin_reward","expanded_toxin_head_reward","expanded_toxin_upgrade"]
	var original_disabled=filtered.save.state.disabled.duplicate();var original_unlocked=filtered.save.state.unlocked.duplicate();var enabled_only=true
	for i in 60:
		filtered.run.rewards.enqueue(true);var offers=filtered.run.roll_rewards()
		enabled_only=enabled_only and offers.all(func(reward):return reward.id not in original_disabled)
		filtered.run.rewards.recycle()
	check(enabled_only and filtered.save.state.disabled==original_disabled and filtered.save.state.unlocked==original_unlocked,"Normal and bonus choices never re-enable excluded rewards or modify unlocks")
	var capped=fixture(504,true)
	while capped.player.parts.size()<61:capped.player.append_segment(gun.blockCore)
	for reward in db.catalog.values():
		if "LevelUp" in str(reward.get("class","")):capped.player.levels[reward.id]=3
	capped.run.rewards.enqueue(true);var capped_offers=capped.run.roll_rewards()
	check(capped_offers.size()==3 and capped_offers.all(func(reward):return capped.run.can_reward(reward) and reward.get("class")!="BlockReward" and not "LevelUp" in str(reward.get("class",""))),"Full body and maximum upgrade levels reroute newly rolled choices to legal rewards")
	var themed=fixture(816,true);themed.save.state.disabled=[bonus]
	var pack=db.named("Gun Reward Pack")
	themed.run.rewards.enqueue(false,{"pack_ids":[pack.id],"rarity":3});var loot=themed.run.roll_rewards()
	check(loot.size()==3 and loot.all(func(reward):return reward.id in pack.packRewardsList) and loot.any(func(reward):return int(reward.rarity)==3),"Explicit weapon loot stays weapon-themed and retains an available legendary choice")
	var graded=fixture(284,true);graded.save.state.disabled=[bonus]
	graded.run.rewards.enqueue(false,{"rarity":3});var grade=int(graded.run.rewards.queue[0].rarity)
	check(graded.run.roll_rewards().any(func(reward):return int(reward.rarity)==grade),"A graded container keeps its earned rarity in a mixed hand")
	check(filtered.run.rewards.pacing.history.size()<=4,"Long sessions keep a bounded offer history")
	var report={"passed":checks.all(func(item):return item.passed),"checks":checks,"samples":samples,"adjacent_pairs":adjacent_pairs,"average_shared_families":float(overlap_total)/adjacent_pairs,"identical_adjacent_hands":same_hands,"pairs_repeated_three_hands":repeated_pairs,"equipped_upgrade_offers":upgrades,"dormant_upgrade_offers":dormant}
	FileAccess.open("res://artifacts/reward-pacing-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
