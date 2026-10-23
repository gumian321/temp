extends RefCounted
## Per-run offer history. Opening an already cached hand must not advance it.
const HISTORY_LIMIT=4
const OFFENSIVE=["gatling","shotgun","cannon","flak","sniper","tesla","emp","flame","rocket","nuke","sonic","blackhole","mine","mine_spawner","drone_bay","toxin","boneblade","parasite"]
const OFFENSIVE_STATS=[2,3,13,14,15,17]
var session:WeakRef
var db
var history:Array=[]
var last_branch:Dictionary={}
func _init(owner_run):
	session=weakref(owner_run);db=owner_run.db
func run():return session.get_ref()
func variant(reward:Dictionary)->String:
	var key=db.armament_variant(reward)
	return {"drone_unit":"drone_bay","repair_drone":"repair_bay","scrap_drone":"scrap_bay","mine_unit":"mine"}.get(key,key)
func family(reward:Dictionary)->String:
	# The body card, head card and upgrade of one weapon count as the same offer.
	var key=variant(reward)
	if not key.is_empty():return "organ:"+key
	match str(reward.get("class","")):
		"PercentBasicReward":return "stat:"+str(int(reward.rewardType))
		"CountBasicReward":return "action:"+str(int(reward.rewardType))
		"CrusedReward":return "risk:%d:%d"%[int(reward.buffRewardType),int(reward.debuffRewardType)]
	return str(reward.id)
func age(key:String)->int:
	for offset in history.size():
		if key in history[history.size()-1-offset]:return offset+1
	return HISTORY_LIMIT+1
func context()->Dictionary:
	var result={"owned":{},"active_cores":{},"active_drones":{},"body_weapons":0}
	var player=run().player
	for i in player.parts.size():
		if float(player.parts[i].hp)<=0:continue
		var core:Dictionary=player.effective_core(i)
		result.active_cores[core.id]=true;result.active_cores[player.parts[i].id]=true
		var key=variant(core)
		if not key.is_empty():result.owned[key]=true
		if i>0 and key in OFFENSIVE:result.body_weapons+=1
	for id in player.pending:
		var key=variant(db.asset(id))
		if not key.is_empty():result.owned[key]=true
	if player.has_method("detached_module_count"):
		for group in player.detached_fragments:
			for part in group.parts:
				var key=variant(db.asset(part.id))
				if not key.is_empty():result.owned[key]=true
	for drone in run().combat.drones:
		if int(drone.owner)>=player.parts.size() or float(player.parts[drone.owner].hp)<=0:continue
		result.active_drones[drone.data.id]=true
	return result
func role(reward:Dictionary,build:Dictionary)->String:
	var kind=str(reward.get("class",""));var key=variant(reward)
	if "LevelUp" in kind:
		var active=reward.get("coresList",[]).any(func(id):return build.active_cores.has(id)) or reward.get("dronesList",[]).any(func(id):return build.active_drones.has(id))
		if not active:return "reserve"
		return "build" if key in OFFENSIVE else "support"
	if kind in ["BlockReward","MainCoreTurretReward","MainCoreDroneReward"]:
		if key in OFFENSIVE:return "build" if build.owned.has(key) else "new"
		return "support"
	if kind=="PercentBasicReward":return "build" if int(reward.rewardType) in OFFENSIVE_STATS else "support"
	if kind=="CrusedReward":return "risk"
	return "support"
func remaining(pool:Array,chosen:Array)->Array:
	var families=chosen.map(func(reward):return family(reward))
	return pool.filter(func(reward):return family(reward) not in families)
func usable(pool:Array,build:Dictionary)->Array:
	return pool.filter(func(reward):return role(reward,build)!="reserve")
func weighted_pick(pool:Array,build:Dictionary,anchor:Array)->Dictionary:
	var rarity_counts:Dictionary={}
	for reward in pool:
		var rarity=int(reward.rarity)
		rarity_counts[rarity]=int(rarity_counts.get(rarity,0))+1
	var chances:Dictionary={}
	for row in db.stores.RewardDataStore.rewardRarityList:chances[int(row.rarity)]=float(row.rarityChance)
	var weights:Array=[];var total=0.0
	for reward in pool:
		var weight=float(chances.get(int(reward.rarity),1))/int(rarity_counts[int(reward.rarity)])
		# Keep source-pack frequency as a preference, with stronger build relevance.
		if reward.id in anchor:weight*=1.3
		if "LevelUp" in str(reward.get("class","")) and role(reward,build)!="reserve":weight*=3.0
		if reward.get("class")=="BlockReward" and role(reward,build)=="new":weight*=1.6
		weights.append(weight);total+=weight
	var roll=run().rng.randf()*total
	for i in pool.size():
		roll-=float(weights[i])
		if roll<=0:return pool[i]
	return pool.back()
func pick(pool:Array,build:Dictionary,desired:String,anchor:Array,rarity:int=4,strict_role:bool=false)->Dictionary:
	if pool.is_empty():return {}
	var preferred=pool.filter(func(reward):return role(reward,build)==desired and (not strict_role or reward.get("class")=="BlockReward"))
	if preferred.is_empty():preferred=pool
	# A fixed role must not force the same lone weapon into every successive hand.
	if not strict_role and preferred.all(func(reward):return age(family(reward))==1):
		var alternatives=pool.filter(func(reward):return age(family(reward))>1)
		if not alternatives.is_empty():preferred=alternatives
	if rarity<4:
		var exact=preferred.filter(func(reward):return int(reward.rarity)==rarity)
		if exact.is_empty():exact=pool.filter(func(reward):return int(reward.rarity)==rarity)
		if not exact.is_empty():preferred=exact
	# Prefer families absent for the last two hands. Small pools relax by age.
	var freshest=0
	for reward in preferred:freshest=maxi(freshest,mini(3,age(family(reward))))
	preferred=preferred.filter(func(reward):return mini(3,age(family(reward)))==freshest)
	# When a weapon returns to the hand, alternate its two meaningful paths.
	# Family history still keeps base/head/upgrade/path cards out of the same hand.
	var alternatives=preferred.duplicate()
	preferred=preferred.filter(func(reward):
		if not reward.has("mutation_branch"):return true
		if last_branch.get(reward.mutation_weapon,"")!=reward.mutation_branch:return true
		return not alternatives.any(func(other):return other.has("mutation_branch") and other.mutation_weapon==reward.mutation_weapon and other.mutation_branch!=reward.mutation_branch))
	return weighted_pick(preferred,build,anchor)
func compose(primary:Array,fallback:Array,anchor:Array,rarity:int,mixed:bool)->Array:
	var build=context();var chosen:Array=[]
	var early=mixed and int(run().opened)<3 and int(build.body_weapons)<3
	var plan=["new","new","support"] if early else ["build","new","support"]
	for slot in 3:
		var pool=remaining(primary,chosen)
		var useful=usable(pool,build)
		if useful.is_empty():useful=usable(remaining(fallback,chosen),build)
		if not useful.is_empty():pool=useful
		elif pool.is_empty():pool=remaining(fallback,chosen)
		if pool.is_empty():break
		var card=pick(pool,build,plan[slot] if mixed else "any",anchor,rarity if slot==0 else 4,early and slot<2)
		if not card.is_empty():chosen.append(card)
	return chosen
func remember(chosen:Array):
	if chosen.is_empty():return
	for reward in chosen:
		if reward.has("mutation_branch"):last_branch[reward.mutation_weapon]=reward.mutation_branch
	history.append(chosen.map(func(reward):return family(reward)))
	while history.size()>HISTORY_LIMIT:history.pop_front()
