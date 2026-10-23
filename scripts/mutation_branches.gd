extends RefCounted
## Permanent research unlocks both paths; a run commits each weapon family once.
const Art=preload("res://scripts/mutation_weapon_art.gd")
const DEFINITIONS={
	"toxin_spread":{"weapon":"toxin","node":"60101","parent":60001,"cell":0,"zh":"毒沼扩散","en":"Venom Marsh","brief_zh":"毒区半径 +65%","brief_en":"POOL RADIUS +65%","desc_zh":"毒囊：毒区半径 +65%、持续 6 秒，弹道沿途留下小毒洼；每秒毒伤为原来的 80%，重叠不叠伤。","desc_en":"Toxin: +65% pool radius, 6-second pools and smaller pools along the flight path. Poison DPS is 80% of normal; overlapping pools do not stack."},
	"toxin_concentrate":{"weapon":"toxin","node":"60102","parent":60001,"cell":1,"zh":"腐蚀浓毒","en":"Concentrated Venom","brief_zh":"每秒毒伤 ×2.4","brief_en":"POISON DPS x2.4","desc_zh":"毒囊：每秒毒伤 ×2.4，离开毒区后仍中毒 3 秒；毒区半径缩小 25%，持续 3 秒。深色浓毒弹偏重单体侵蚀。","desc_en":"Toxin: 2.4x poison DPS and poison lingers for 3 seconds after leaving. Pool radius -25%, duration 3 seconds. A dark dense projectile favors focused damage."},
	"boneblade_fan":{"weapon":"boneblade","node":"60201","parent":60002,"cell":0,"zh":"分叉骨刃","en":"Boneblade Fan","brief_zh":"三刃扇形往返","brief_en":"THREE RETURNING BLADES","desc_zh":"回旋骨刃：同时射出 3 枚骨刃，沿不同角度扫场并各自回收；每刃伤害为原来的 60%，出去与回来各命中一次。","desc_en":"Boneblade: launches three blades on separate fan trajectories, each returning independently. Each deals 60% damage and can hit once outbound and once returning."},
	"boneblade_recall":{"weapon":"boneblade","node":"60202","parent":60002,"cell":1,"zh":"疾返骨刃","en":"Swift Recall","brief_zh":"弹速 +80% · 射速 +40%","brief_en":"SPEED +80% / RATE +40%","desc_zh":"回旋骨刃：弹速 +80%、射速 +40%，射程不变，快速折返；返程伤害 +50%。保留单刃，集中切穿同一目标。","desc_en":"Boneblade: +80% speed, +40% fire rate, unchanged range and a tighter return. Return hits deal +50% damage. Keeps a single blade for focused cuts.","rate":0.4},
	"parasite_swarm":{"weapon":"parasite","node":"60301","parent":60003,"cell":0,"zh":"孵化虫群","en":"Brood Swarm","brief_zh":"每荚孵化 4 虫","brief_en":"FOUR LARVAE PER POD","desc_zh":"寄生荚：每荚孵化 4 只小幼虫，主动分散追敌；单虫伤害为原来的 65%，存活 5 秒，每器官最多 10 只。","desc_en":"Parasite: each pod hatches four smaller larvae that spread across enemies. Each deals 65% bite damage, lives for 5 seconds, and each organ supports up to ten."},
	"parasite_hunter":{"weapon":"parasite","node":"60302","parent":60003,"cell":1,"zh":"猎杀强虫","en":"Hunter Brood","brief_zh":"单只猎虫 · 咬击 ×3","brief_en":"ONE HUNTER / BITE x3","desc_zh":"寄生荚：每荚孵化 1 只重型猎虫，单次咬击 ×3、移速 +45%、存活 8 秒；每器官最多 3 只，集中追击并短距扑咬。","desc_en":"Parasite: each pod hatches one heavy hunter with 3x bite damage, +45% movement speed and an 8-second life. Up to three per organ; focuses prey and lunges to bite."}}
static func reward_id(branch:String)->String:return "expanded_"+branch+"_branch"
static func selected(player,weapon:String)->String:
	if weapon.is_empty():return ""
	for branch in DEFINITIONS:
		if DEFINITIONS[branch].weapon==weapon and int(player.levels.get(reward_id(branch),0))>0:return branch
	return ""
static func can_choose(player,reward:Dictionary)->bool:
	var weapon=str(reward.mutation_weapon)
	if not selected(player,weapon).is_empty() or int(player.levels.get("expanded_"+weapon+"_upgrade",0))<1:return false
	for i in player.parts.size():
		if player.parts[i].hp>0 and player.effective_core(i).get("mutation_weapon","")==weapon:return true
	return false
static func texture(branch:String)->Texture2D:
	var info:Dictionary=DEFINITIONS[branch]
	return Art.texture(str(info.weapon)+"_branches",int(info.cell))
static func core_texture(player,core:Dictionary)->Texture2D:
	var branch=selected(player,str(core.get("mutation_weapon","")))
	return texture(branch) if not branch.is_empty() else player.db.core_sprite(core)
static func install(db):
	for branch in DEFINITIONS:
		var info:Dictionary=DEFINITIONS[branch];var prefix="expanded_"+str(info.weapon)
		var reward={"id":reward_id(branch),"name":"Reward_Branch_"+branch,"class":"TurretLevelUpReward","mutation_branch":branch,"mutation_weapon":info.weapon,"coresList":[prefix+"_core",prefix+"_hq"],"rarity":2,"max_level":1,"rewardTextID":"Branch_"+branch,"rewardDesc":"Branch_"+branch+"_Desc","rewardStats":{},"rewardVideoClip":"","project_added":true}
		if info.has("rate"):reward.RateOfFirePercent=info.rate
		db.catalog[reward.id]=reward
		db.research.append({"id":info.node,"nodeBaseValue":4,"previousUpgradeTreeNode":{"fileID":info.parent},"prerequisite_level":3,"nodeRewardsList":[reward.id],"mutation_branch":branch,"project_added":true})
		for pack_id in db.stores.RewardDataStore.allRewardPacksList:
			if db.catalog[pack_id].name=="Level Up Reward Pack":db.catalog[pack_id].packRewardsList.append(reward.id)
static func install_names(db):
	var names=preload("res://scripts/insect_armaments.gd")
	for branch in DEFINITIONS:
		var info:Dictionary=DEFINITIONS[branch];var title="Branch_"+branch
		names.set_text(db,title,info.en,info.zh)
		names.set_text(db,title+"_Brief",info.brief_en,info.brief_zh)
		names.set_text(db,title+"_Desc",info.desc_en,info.desc_zh)
static func brief(db,reward:Dictionary)->String:return db.text("Branch_"+str(reward.mutation_branch)+"_Brief")
static func rule_text(db,reward:Dictionary)->String:
	var other=""
	for branch in DEFINITIONS:
		if DEFINITIONS[branch].weapon==reward.mutation_weapon and branch!=reward.mutation_branch:other=db.text("Branch_"+branch)
	return db.ui("After weapon upgrade Lv.1. Applies to all matching head/body weapons this run. Choosing this excludes %s for this run.","对应武器强化 1 次后可选。对本局全部同类头部与身体武器生效；选择后，本局不再出现「%s」。")%other
