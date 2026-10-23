extends RefCounted
var session: WeakRef
var db
var queue: Array = []
var level_deck: Array = []
var game_deck: Array = []
var level_index = 0
var game_index = 0
var active_pack: Dictionary = {}
var pacing
func _init(run):
	session = weakref(run)
	db = run.db
	pacing=preload("res://scripts/reward_pacing.gd").new(run)
	level_deck = build_deck("packLevelUpFreq")
	game_deck = build_deck("packGameFreq")
func run(): return session.get_ref()
func shuffle(items: Array) -> Array:
	for i in range(items.size()-1,0,-1):
		var j = run().rng.randi_range(0,i)
		var old = items[i]; items[i] = items[j]; items[j] = old
	return items
func build_deck(field: String) -> Array:
	var layers: Array = []
	for id in db.stores.RewardDataStore.allRewardPacksList:
		var pack = db.asset(id)
		if not pack.packRewardsList.any(func(r): return r in run().save.state.unlocked): continue
		for i in range(int(pack[field])):
			while layers.size() <= i: layers.append([])
			layers[i].append(id)
	var deck: Array = []
	for layer in shuffle(layers): deck.append_array(shuffle(layer))
	return deck
func available(pack: Dictionary) -> bool:
	return pack.get("packRewardsList",[]).any(func(id): return run().can_reward(db.asset(id)))
func next_pack(level_up: bool) -> String:
	var deck = level_deck if level_up else game_deck
	for i in range(deck.size()):
		var index = level_index if level_up else game_index
		var id: String = deck[index%deck.size()]
		if level_up: level_index += 1
		else: game_index += 1
		if available(db.asset(id)): return id
	return db.stores.RewardDataStore.cursedRewardPack
func choose_pack(ids: Array, rarity: int) -> String:
	var selected = ids.filter(func(id): return available(db.asset(id)))
	if selected.is_empty(): return db.stores.RewardDataStore.cursedRewardPack
	if rarity != 4:
		var exact = selected.filter(func(id): return db.asset(id).packRewardsList.any(func(rid): return int(db.asset(rid).rarity)==rarity and run().can_reward(db.asset(rid))))
		if not exact.is_empty(): selected = exact
	return selected[run().rng.randi_range(0,selected.size()-1)]
func random_rarity(candidates: Array) -> int:
	var rarities: Array = []
	for reward in candidates:
		if int(reward.rarity) not in rarities: rarities.append(int(reward.rarity))
	if rarities.is_empty(): return 4
	var total = 0.0
	for row in db.stores.RewardDataStore.rewardRarityList:
		if int(row.rarity) in rarities: total += float(row.rarityChance)
	var value = run().rng.randf()*total
	for row in db.stores.RewardDataStore.rewardRarityList:
		if int(row.rarity) in rarities:
			value -= float(row.rarityChance)
			if value <= 0: return int(row.rarity)
	return rarities[0]
func enqueue(level_up: bool, drop: Dictionary = {}):
	var rarity = int(drop.get("rarity",4))
	var id = choose_pack(drop.pack_ids,rarity) if drop.has("pack_ids") else (choose_pack(game_deck,rarity) if rarity != 4 and not level_up else next_pack(level_up))
	var pack = db.asset(id)
	var rewards: Array = pack.packRewardsList.map(func(r): return db.asset(r)).filter(func(r): return r.id in run().save.state.unlocked)
	var available_rarities: Array = rewards.map(func(r): return int(r.rarity))
	if rarity not in available_rarities:
		var lower = available_rarities.filter(func(r): return r<rarity)
		rarity = lower.max() if not lower.is_empty() and rarity != 4 else random_rarity(rewards)
	queue.append({"id":id,"rarity":rarity,"mixed":not drop.has("pack_ids"),"level_up":level_up})
	run().packs = queue.size()
func conflict(a: Dictionary,b: Dictionary) -> bool:
	if pacing.family(a)==pacing.family(b):return true
	if a.has("rewardType") and b.has("rewardType"):return a.rewardType==b.rewardType
	if a.get("class")=="MainCoreDroneReward" and b.get("class")=="MainCoreDroneReward":return a.drone==b.drone
	if a.get("class")=="BlockReward" and b.get("class")=="BlockReward": return a.blockCore == b.blockCore
	return false
func candidates(pack_ids:Array)->Array:
	var result:Array=[];var seen:Dictionary={}
	for id in pack_ids:
		for reward_id in db.asset(id).get("packRewardsList",[]):
			if seen.has(reward_id):continue
			seen[reward_id]=true
			var reward=db.asset(reward_id)
			if run().can_reward(reward):result.append(reward)
	return result
func roll() -> Array:
	# Tests/debug may explicitly inject pack count; give each injected pack a real source deck entry.
	var required: int = run().packs
	while queue.size()<required: enqueue(true)
	if queue.is_empty(): return []
	active_pack = queue[0].duplicate()
	if not available(db.asset(active_pack.id)):active_pack.id=next_pack(true);active_pack.rarity=4
	var pack = db.asset(active_pack.id)
	var mixed=bool(active_pack.get("mixed",false))
	var pack_ids:Array=[active_pack.id]
	if mixed:
		var field="packLevelUpFreq" if active_pack.get("level_up",true) else "packGameFreq"
		pack_ids=db.stores.RewardDataStore.allRewardPacksList.filter(func(id):return int(db.asset(id).get(field,0))>0)
	var primary=candidates(pack_ids)
	var fallback=candidates(db.stores.RewardDataStore.allRewardPacksList)
	var rarity=4 if mixed and active_pack.get("level_up",true) else int(active_pack.rarity)
	var chosen=pacing.compose(primary,fallback,pack.get("packRewardsList",[]),rarity,mixed)
	var bonus:Dictionary=db.asset(db.stores.RewardDataStore.packReward)
	if run().rng.randf()<float(db.stores.RewardDataStore.packRewardChance) and chosen.size()==3 and run().can_reward(bonus) and pacing.age(pacing.family(bonus))>2 and not chosen.any(func(reward):return conflict(reward,bonus)):
		chosen[chosen.size()-1]=bonus
	pacing.remember(chosen)
	return shuffle(chosen)
func consume():
	if not queue.is_empty(): queue.pop_front()
	run().packs = queue.size()
	active_pack.clear()
func recycle():
	if queue.is_empty(): return
	var cost=roundi(maxi(1,run().player.parts.size()-1)*float(db.stores.RewardDataStore.ScrapsPerRewardPack))
	var count=maxi(1,roundi(cost*float(db.stores.RewardDataStore.ScrapsRecyclePercent)))
	var offset=Vector2.from_angle(run().combat.loot_rng.randf()*TAU)*run().combat.loot_rng.randf_range(4.5,5.5)*48
	run().recycled_packs.append({'start':run().player.head,'position':run().player.head,'target':run().player.head+offset,'age':0.0,'count':count})
	consume()
	run().opened += 1
	run().offers.clear()
