extends RefCounted
const DEFINITIONS={
	"toxin":{"suffix":"Toxin","node":"60001","parent":20693,"damage":7.0,"rate":0.65,"range":1,"speed":430.0,"rarity":1},
	"boneblade":{"suffix":"Boneblade","node":"60002","parent":22852,"damage":18.0,"rate":0.8,"range":1,"speed":620.0,"rarity":1},
	"parasite":{"suffix":"Parasite","node":"60003","parent":20690,"damage":8.0,"rate":0.45,"range":2,"speed":460.0,"rarity":1}}
static func named(db,name:String)->Dictionary:
	for value in db.catalog.values():
		if value.get("name")==name:return value
	return {}
static func install(db):
	var core_template=named(db,"Core_Gun_Cannon")
	var turret_template=named(db,"Turret_Gun_Cannon")
	var projectile_template=db.catalog[core_template.coreProjectile]
	var reward_template=named(db,"Reward_Block_Gun_Cannon")
	var upgrade_template=named(db,"Reward_LevelUP_Gun_Cannon")
	for key in DEFINITIONS:
		var info:Dictionary=DEFINITIONS[key]
		var prefix="expanded_"+key
		var projectile=projectile_template.duplicate(true)
		projectile.merge({"id":prefix+"_projectile","name":info.suffix+"Projectile","class":"BasicProjectile","projectileDamage":{"hullDamage":info.damage,"shieldDamage":info.damage},"projectileSpeed":info.speed/48.0,"projectileLifeTime":1.8,"targetPiercingCount":1,"fx_family":key,"project_added":true},true)
		projectile.erase("projectileEffectArea")
		db.catalog[projectile.id]=projectile
		var turret=turret_template.duplicate(true)
		turret.merge({"id":prefix+"_turret","name":"Turret_Gun_"+info.suffix,"turretSprite":prefix+"_sprite","turretsBarrels":"","project_added":true},true)
		db.catalog[turret.id]=turret
		db.sprites[prefix+"_sprite"]={"name":key,"path":"res://assets/new_weapons/"+key+"_atlas.png","insect_variant":key}
		var core=core_template.duplicate(true)
		core.merge({"id":prefix+"_core","name":"Core_Gun_"+info.suffix,"coreTurret":turret.id,"coreProjectile":projectile.id,"turretRange":info.range,"turretRateOfFire":info.rate,"turretRotateSpeed":300,"turretErrorAngle":8,"mutation_weapon":key,"fx_family":key,"project_added":true},true)
		db.catalog[core.id]=core
		var head=core.duplicate(true);head.id=prefix+"_hq";head.name="HQ_Gun_"+info.suffix
		db.catalog[head.id]=head
		var reward=reward_template.duplicate(true)
		reward.merge({"id":prefix+"_reward","name":"Reward_Block_Gun_"+info.suffix,"blockCore":core.id,"rarity":info.rarity,"rewardVideoClip":"","project_added":true},true)
		reward.rewardStats={"HullDamage":2,"ShieldDamage":2,"Range":3,"RateOfFire":2,"PartsCount":1,"DronesCount":0,"LevelUp":0}
		db.catalog[reward.id]=reward
		var head_reward=reward.duplicate(true)
		head_reward.merge({"id":prefix+"_head_reward","name":"Reward_HQ_Gun_"+info.suffix,"class":"MainCoreTurretReward","core":head.id},true)
		head_reward.erase("blockCore");head_reward.erase("coresCount")
		db.catalog[head_reward.id]=head_reward
		var upgrade=upgrade_template.duplicate(true)
		upgrade.merge({"id":prefix+"_upgrade","name":"Reward_LevelUP_Gun_"+info.suffix,"coresList":[core.id,head.id],"rarity":2,"DamagePercent":0.25,"RateOfFirePercent":0.15,"RangePercent":0.05,"rewardVideoClip":"","project_added":true},true)
		upgrade.rewardStats.LinkedReward=reward.id
		db.catalog[upgrade.id]=upgrade
		db.research.append({"id":info.node,"nodeBaseValue":3,"previousUpgradeTreeNode":{"fileID":info.parent},"nodeRewardsList":[reward.id,head_reward.id,upgrade.id],"project_added":true})
		for pack_id in db.stores.RewardDataStore.allRewardPacksList:
			var pack:Dictionary=db.catalog[pack_id]
			if pack.name=="Gun Reward Pack":pack.packRewardsList.append(reward.id)
			elif pack.name=="HQ Reward Pack":pack.packRewardsList.append(head_reward.id)
			elif pack.name=="Level Up Reward Pack":pack.packRewardsList.append(upgrade.id)
