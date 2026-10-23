extends "res://tests/test_mutation_weapons.gd"
const Branches=preload("res://scripts/mutation_branches.gd")
const Run=preload("res://scripts/run_state.gd")
func evolved(branch:String)->Dictionary:
	var f=fixture();f.player.levels[Branches.reward_id(branch)]=1;return f
func spawned(f:Dictionary,at:Vector2)->Dictionary:
	var enemy=f.battle.spawn(db.pool["250"],at);enemy.hp=100000;enemy.max_hp=enemy.hp;enemy.guns=[];enemy.mission_controlled=true;return enemy
func instant_pool(f:Dictionary):
	shoot(f,"toxin");var shot=f.system.shots.back();shot.position=f.enemy.position;f.system.pop(shot,true)
func flight(f:Dictionary)->Dictionary:
	var time=0.0;var reach=0.0
	while not f.system.shots.is_empty() and time<4:
		for shot in f.system.shots:reach=maxf(reach,float(shot.position.x))
		f.system.step(1.0/120);time+=1.0/120
	return {"time":time,"reach":reach}
func execute():
	db=DB.new()
	var save=Store.new(db,"user://mutation-branches.json",false);save.state.meta=10000
	for weapon in ["toxin","boneblade","parasite"]:
		var parent=db.research.filter(func(n):return n.nodeRewardsList[0]=="expanded_"+weapon+"_reward")[0]
		var branches=db.research.filter(func(n):return n.has("mutation_branch") and str(int(n.previousUpgradeTreeNode.fileID))==parent.id)
		check(branches.size()==2,"Two research children exist for "+weapon)
		check(not save.unlock_research(branches[0],0),"Branch research cannot bypass the base research: "+weapon)
		for i in 3:check(save.unlock_research(parent,i),"Sequential base research unlocks: "+weapon+" / "+str(i))
		for node in branches:
			var reward=db.asset(node.nodeRewardsList[0])
			check(save.unlock_research(node,0) and save.available(reward.id),"Both permanent paths may be researched: "+reward.mutation_branch)
			check(db.title(reward)==Branches.DEFINITIONS[reward.mutation_branch].zh and db.text(reward.rewardDesc).contains("："),"Branch keeps its own title and mechanics description")
			check(db.reward_sprite(reward)!=db.core_sprite(db.asset(reward.coresList[0])),"Branch has dedicated artwork")
			check(not reward.has("DamagePercent") and not reward.has("CoreHealthPercent"),"Branch does not inherit unrelated cannon bonuses")
	var loaded=Store.new(db,save.path)
	check(Branches.DEFINITIONS.keys().all(func(branch):return loaded.available(Branches.reward_id(branch))),"All six research unlocks survive a save reload")
	var f=fixture();var run=Run.new(db,save,f.player,f.battle,db.named("Survival Mission"),0)
	var a=db.asset(Branches.reward_id("toxin_spread"));var b=db.asset(Branches.reward_id("toxin_concentrate"))
	check(not run.can_reward(a),"An unequipped or unupgraded weapon cannot receive a branch card")
	f.player.levels.expanded_toxin_upgrade=1;f.player.pending.append("expanded_toxin_core")
	check(not run.can_reward(a),"A pending organ alone does not enable a specialization")
	f.player.pending.clear();f.player.add_piece("expanded_toxin_core",f.player.next_segment_cell())
	check(run.can_reward(a) and run.can_reward(b),"A live upgraded weapon makes both researched paths eligible")
	var pacing=run.rewards.pacing;var last="";var alternates=true
	for i in 8:
		var hand=pacing.compose([a,b],[],[],4,false)
		alternates=alternates and hand.size()==1 and hand[0].id!=last
		last=hand[0].id;pacing.remember(hand)
	check(alternates,"Repeated branch opportunities alternate paths while retaining one card per weapon family")
	save.state.disabled.append(a.id)
	check(not run.can_reward(a) and run.can_reward(b),"Branch cards honor the saved reward filter")
	save.state.disabled.erase(a.id)
	run.packs=1;run.offers=[a,b];check(run.take_reward(a),"The ordinary reward transaction selects a branch")
	check(not run.can_reward(a) and not run.can_reward(b) and Branches.selected(f.player,"toxin")=="toxin_spread","A selected path excludes repeats and its opposing path for this run")
	check(f.player.reward_feedback(a).part_uids.size()==1,"Branch feedback identifies the affected live organ")
	f.player.remove_parts([1]);check(not run.can_reward(b),"Losing the organ cannot reset the branch commitment")
	f.player.set_hq_weapon("expanded_toxin_hq");shoot(f,"toxin","player:0")
	check(f.system.shots.back().branch=="toxin_spread","The same family specialization applies to a replacement head weapon")
	var fresh=fixture();fresh.player.set_hq_weapon("expanded_toxin_hq");fresh.player.levels.expanded_toxin_upgrade=1
	var fresh_run=Run.new(db,save,fresh.player,fresh.battle,db.named("Survival Mission"),0)
	check(fresh_run.can_reward(a) and fresh_run.can_reward(b),"A fresh run can choose either researched path again")
	fresh.player.parts[0].hp=0
	check(not fresh_run.can_reward(a),"A dead organ does not enable branch cards")
	# Poison coverage, lingering and strongest-source expiration, using real hit logic.
	var broad=evolved("toxin_spread");var fringe=spawned(broad,Vector2(120,110));shoot(broad,"toxin");advance(broad.system,.8)
	check(broad.system.pools.any(func(pool):return pool.trail) and broad.system.pools.any(func(pool):return not pool.trail and is_equal_approx(pool.radius,135.3)),"Marsh projectile lays small path pools and a wider impact pool")
	check(fringe.hp<100000 and broad.system.pools.all(func(pool):return pool.duration==6),"Wide persistent ground deals actual damage beyond the base pool radius")
	check(is_equal_approx(broad.system.poisoned[broad.enemy.uid].damage,7*1.2*.8),"Marsh trades poison DPS for coverage without stacking overlapping puddles")
	var normal=fixture();var normal_fringe=spawned(normal,Vector2(120,110));shoot(normal,"toxin");advance(normal.system,.8)
	check(normal_fringe.hp==100000,"The same fringe target is outside the base weapon's damaging ground")
	var dense=evolved("toxin_concentrate");instant_pool(dense);advance(dense.system,.5)
	var dense_hp=float(dense.enemy.hp);advance(dense.system,1.0)
	check(is_equal_approx(dense_hp-dense.enemy.hp,7*1.2*2.4),"Concentrated poison deals exactly 2.4x base poison DPS")
	check(is_equal_approx(dense.system.pools[0].radius,61.5) and dense.system.pools[0].duration==3,"Dense venom has the smaller, shorter-lived pool described on its card")
	dense.enemy.position=Vector2(2000,0);advance(dense.system,2)
	check(dense.system.poisoned.has(dense.enemy.uid),"Dense poison continues after two seconds outside the pool")
	advance(dense.system,1.2);check(dense.system.poisoned.is_empty(),"Dense poison expires after its three-second linger")
	var mixing=evolved("toxin_concentrate");instant_pool(mixing);advance(mixing.system,.3)
	mixing.system.pools[0].life=0;mixing.player.levels.clear();instant_pool(mixing);advance(mixing.system,3.1)
	check(mixing.system.poisoned.has(mixing.enemy.uid) and is_equal_approx(mixing.system.poisoned[mixing.enemy.uid].damage,8.4),"A weak pool cannot perpetually refresh an expired stronger poison source")
	var blocked=evolved("toxin_spread");blocked.battle.terrain=Wall.new();blocked.enemy.position=Vector2(150,0);shoot(blocked,"toxin");advance(blocked.system,1.5)
	check(blocked.enemy.hp==100000 and blocked.system.pools.all(func(pool):return pool.position.x<80),"Wide and trail pools respect cave walls and line of sight")
	# Distinct projectiles, return damage and travel time, not simulated visual clones.
	var fan=evolved("boneblade_fan");fan.enemy.position=Vector2(250,0)
	var left=spawned(fan,Vector2.RIGHT.rotated(-.30)*250);var right=spawned(fan,Vector2.RIGHT.rotated(.30)*250)
	shoot(fan,"boneblade")
	check(fan.system.shots.size()==3 and fan.system.shots[0].velocity!=fan.system.shots[1].velocity,"Fan evolution launches three independently simulated trajectories")
	advance(fan.system,.48)
	check([left,right,fan.enemy].all(func(enemy):return enemy.hp<100000),"Three fan directions sweep three separated real targets")
	check(fan.system.shots.all(func(shot):return is_equal_approx(shot.damage,10.8)),"Each fan blade pays the stated 40 percent damage cost")
	advance(fan.system,2);check(fan.system.shots.is_empty(),"All three fan blades return and clean up")
	var fast=evolved("boneblade_recall");shoot(fast,"boneblade");var fast_flight=flight(fast)
	var plain=fixture();shoot(plain,"boneblade");var plain_flight=flight(plain)
	check(fast_flight.time<plain_flight.time*.7 and fast_flight.reach>=plain_flight.reach*.97,"Swift recall completes its real flight faster without shortening the outbound range")
	check(is_equal_approx(100000-fast.enemy.hp,45.0),"Swift blade deals one 18-damage outbound hit and one 27-damage return hit")
	check(is_equal_approx(fast.player.upgrade_bonus("expanded_boneblade_core","RateOfFirePercent"),.4),"Swift recall increases the real firing rate through the existing upgrade calculation")
	var fast_wall=evolved("boneblade_recall");fast_wall.battle.terrain=Wall.new();fast_wall.enemy.position=Vector2(150,0);shoot(fast_wall,"boneblade");advance(fast_wall.system,2)
	check(fast_wall.enemy.hp==100000,"High-speed blades cannot tunnel through cave walls")
	# Broods are bounded, independent target-seeking units with distinct size/behavior.
	var swarm=evolved("parasite_swarm");shoot(swarm,"parasite");advance(swarm.system,.35)
	check(swarm.system.larvae.size()==4 and swarm.system.larvae.all(func(larva):return is_equal_approx(larva.damage,8*.65*.65)),"Swarm hatches four reduced-damage larvae")
	var second=spawned(swarm,Vector2(160,90));var third=spawned(swarm,Vector2(160,-90))
	for larva in swarm.system.larvae:larva.target=0
	advance(swarm.system,.2)
	check(swarm.system.larvae.any(func(larva):return larva.target==second.uid) and swarm.system.larvae.any(func(larva):return larva.target==third.uid),"Swarm distributes its stable targets instead of piling onto one enemy")
	for i in 5:shoot(swarm,"parasite")
	advance(swarm.system,.4);check(swarm.system.larvae.size()==10,"Swarm respects ten larvae per source organ")
	var hunter=evolved("parasite_hunter");shoot(hunter,"parasite");advance(hunter.system,.35)
	check(hunter.system.larvae.size()==1 and is_equal_approx(hunter.system.larvae[0].damage,8*.65*3),"Hunter hatches one independently simulated heavy larva with triple bite damage")
	check(hunter.system.larvae[0].speed==261 and hunter.system.larvae[0].life>7.7,"Hunter has its advertised movement speed and longer lifetime")
	hunter.enemy.position+=Vector2(90,0);hunter.system.larvae[0].lunge_delay=0;advance(hunter.system,1.0/120)
	check(hunter.system.larvae[0].lunge>0,"Hunter uses a real short lunge toward its prey")
	var hp=float(hunter.enemy.hp);advance(hunter.system,1)
	check(hunter.enemy.hp<hp,"Hunter closes the gap and deals actual melee damage")
	for i in 6:shoot(hunter,"parasite")
	advance(hunter.system,.6);check(hunter.system.larvae.size()==3,"Heavy hunters respect their three-per-organ cap")
	for branch in ["parasite_swarm","parasite_hunter"]:
		var wall_brood=evolved(branch);wall_brood.battle.terrain=Wall.new();wall_brood.enemy.position=Vector2(95,0)
		shoot(wall_brood,"parasite");advance(wall_brood.system,2)
		check(wall_brood.enemy.hp==100000 and wall_brood.system.larvae.all(func(larva):return larva.position.x<=80-float(larva.radius)),"Crawling and lunging broods cannot move or bite through cave walls: "+branch)
		var mass=evolved(branch)
		for owner in 5:
			mass.player.add_piece("expanded_parasite_core",mass.player.next_segment_cell())
			for i in 6:shoot(mass,"parasite","player:"+str(owner+1))
		advance(mass.system,.5)
		var weight=0
		for larva in mass.system.larvae:weight+=int(larva.weight)
		check(weight<=24 and not mass.system.larvae.is_empty(),"Global weighted brood limit remains bounded: "+branch)
		advance(mass.system,9);check(mass.system.larvae.is_empty(),"Expired brood releases its population budget: "+branch)
	for branch in Branches.DEFINITIONS:
		var sample=evolved(branch);var key=Branches.DEFINITIONS[branch].weapon;shoot(sample,key);advance(sample.system,11)
		check(sample.system.shots.is_empty() and sample.system.pools.is_empty() and sample.system.poisoned.is_empty() and sample.system.larvae.is_empty(),"All branch transient state expires: "+branch)
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"fast_flight":fast_flight,"base_flight":plain_flight}
	FileAccess.open("res://artifacts/mutation-branches-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
