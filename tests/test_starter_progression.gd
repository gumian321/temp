extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Save=preload("res://scripts/save_store.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Run=preload("res://scripts/run_state.gd")
var checks:Array=[]
func check(value:bool,title:String):
	checks.append({"name":title,"passed":value})
	if not value:printerr("FAIL: ",title)
func _initialize():call_deferred("execute")
func execute():
	var db=DB.new()
	var store=Save.new(db,"user://starter-progression.json",false)
	var starters:Array=[]
	for weapon in DB.STARTER_WEAPONS:starters.append(db.named("Reward_Block_Gun_"+weapon).id)
	check(starters.size()==5 and starters.all(func(id):return store.available(id)),"A new profile can immediately obtain all five starting weapons")
	var initial_guns=store.state.unlocked.filter(func(id):return db.asset(id).get("name","").begins_with("Reward_Block_Gun_"))
	check(initial_guns.size()==5,"Only the five agreed basic weapons enter the initial weapon pool")
	var retired=db.catalog.values().filter(func(r):return r.get("retired",false))
	check(retired.size()==4 and retired.all(func(r):return not store.available(r.id)),"Both tiers of paid move and swap are retired")
	check(db.research.all(func(n):return n.nodeRewardsList.all(func(id):return not db.asset(id).get("retired",false))),"Evolution no longer sells retired rearrangement rewards")
	check(db.stores.RewardDataStore.allRewardPacksList.all(func(id):return db.asset(id).packRewardsList.all(func(rid):return not db.asset(rid).get("retired",false))),"Reward packs cannot use retired rewards as selectable or locked cards")
	var research_ids=db.research.map(func(n):return n.id)
	check(db.research.all(func(n):return int(n.previousUpgradeTreeNode.fileID)==0 or str(int(n.previousUpgradeTreeNode.fileID)) in research_ids),"Every remaining evolution prerequisite still exists")
	var duplicate_node=db.research.filter(func(n):return n.id=="20685")[0]
	check(int(duplicate_node.previousUpgradeTreeNode.fileID)==20680,"The surviving branch bypasses both removed prerequisites")
	# Simulate a real older save, including locked cards excluded by the old filter.
	store.state.unlocked=db.read_json("stores").RewardDataStore.rewardsUnlockedList.duplicate()
	for reward in retired:store.state.unlocked.append(reward.id)
	var shotgun=db.named("Reward_Block_Gun_Shotgun").id
	var rocket=db.named("Reward_Block_Gun_Rocket").id
	var gatling=db.named("Reward_Block_Gun_Gatling").id
	store.state.disabled=[shotgun,rocket,gatling,retired[0].id]
	store.state.meta=4321;store.state.scores={"kept-mission":900};store.state.settings.volume=0.23
	check(store.save(),"Older-profile fixture saves successfully")
	store=Save.new(db,store.path)
	check(store.available(shotgun) and store.available(rocket),"Existing profiles gain and enable the two new starter weapons")
	check(not store.available(gatling) and gatling in store.state.disabled,"An intentional exclusion of an already owned weapon is preserved")
	check(retired.all(func(r):return r.id not in store.state.unlocked and r.id not in store.state.disabled),"Existing profiles drop obsolete unlocks and filters")
	check(store.state.meta==4321 and int(store.state.scores["kept-mission"])==900 and is_equal_approx(store.state.settings.volume,0.23),"Migration preserves currency, earned scores and settings")
	check(store.reset_skill_progress() and starters.all(func(id):return store.available(id)),"Debug reset also restores the new five-weapon initial pool")
	var loaded=Save.new(db,store.path)
	check(loaded.state.unlocked==store.state.unlocked and loaded.state.meta==10000,"The new initial skill pool persists after reset and reload")
	var player=Body.new(db);var battle=Battle.new(db,player)
	var run=Run.new(db,store,player,battle,db.kind("Mission")[0],0)
	run.rng.seed=87241
	check(starters.all(func(id):return run.can_reward(db.asset(id))),"All five weapons are usable in the normal starting character")
	var seen:Array=[];var valid=true
	for i in 24:
		run.rewards.queue=[{"id":db.named("Gun Reward Pack").id,"rarity":4}]
		run.packs=1;run.offers.clear()
		var offers=run.roll_rewards()
		valid=valid and offers.size()==3 and offers.all(func(r):return not r.get("retired",false))
		for reward in offers:
			if reward.id in starters and reward.id not in seen:seen.append(reward.id)
	check(valid and seen.size()==5,"Real three-choice weapon rolls offer every starter without obsolete cards")
	var codex=load("res://scripts/reward_pool_ui.gd").new();root.add_child(codex)
	codex.setup(db,store,func():pass,func():pass)
	check(codex.groups.all(func(group):return group.all(func(id):return not db.asset(id).get("retired",false))),"Reward-pool controls no longer show move or swap groups")
	check(codex.groups.filter(func(group):return group[0]==rocket).size()==1,"The newly unlocked rocket weapon appears only once in reward-pool controls")
	codex.queue_free();await process_frame
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/starter-progression-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
