extends SceneTree
const Battle=preload("res://scripts/combat.gd")
var checks:Array=[]
class Wall extends RefCounted:
	var enabled=true
	var rays=0
	var blocked:Dictionary={}
	func dig():pass
	func ray_clear(_from:Vector2,to:Vector2)->bool:
		rays+=1
		return not blocked.has(to)
class Reference extends "res://scripts/combat.gd":
	# Pre-optimization selection oracle, including source-order ties and shields.
	func target_for(core:Dictionary,at:Vector2,reach:float)->Dictionary:
		var config:Dictionary=db.asset(core.get("radarConfiguration",""))
		var radar:String=config.get("class","ClosetTargetRadarConfiguration")
		var candidates:Array=[];var shielded:Array=[]
		for e in target_candidates(at,reach):
			if e.hp<=0 or not e.damageable or e.role=="friendly" or float(e.get("warp",0))>0 or e.get("cloaked",false) or at.distance_squared_to(e.position)>=reach*reach:continue
			candidates.append(e)
			if config.get("priortizeShield",true) and e.stun<=0:
				for gun in e.guns:
					var shield=db.asset(gun.id)
					if shield.get("class")=="ShieldCore" and float(gun.get("shield",shield.maxShieldHealth))>0:shielded.append(e);break
		if candidates.is_empty():return {}
		if radar=="RandomRadarConfiguration":
			candidates=candidates.filter(func(e):return terrain.ray_clear(at,target_position(e)))
			return candidates[rng.randi_range(0,candidates.size()-1)] if not candidates.is_empty() else {}
		shielded=shielded.filter(func(e):return terrain.ray_clear(at,target_position(e)))
		if not shielded.is_empty():candidates=shielded
		var result:Dictionary={}
		var best=0.0 if radar in ["BiggestTargetRadarConfiguration","FurthestRadarConfiguration"] else (1.0 if radar=="LowestHealthTargetRadarConfiguration" else INF)
		for e in candidates:
			var value=at.distance_squared_to(e.position)
			match radar:
				"BiggestTargetRadarConfiguration","SmallestTargetRadarConfiguration":value=e.max_hp
				"LowestHealthTargetRadarConfiguration":
					if e.get("repair_owner",0)!=0:continue
					value=float(e.hp)/float(e.max_hp)
				"StunnedRadarConfiguration":
					if (e.kind.begins_with("AI") or e.kind=="TraderUnit") and terrain.ray_clear(at,target_position(e)):result=e
					continue
			if (value>best if radar in ["BiggestTargetRadarConfiguration","FurthestRadarConfiguration"] else value<best):
				if not terrain.ray_clear(at,target_position(e)):continue
				best=value;result=e
		return result

func check(value:bool,message:String):
	checks.append({"passed":value,"name":message})
	if not value:push_error(message)
func _initialize():call_deferred("execute")
func execute():
	var db=preload("res://scripts/source_db.gd").new()
	var player=preload("res://scripts/centipede.gd").new(db)
	var current=Battle.new(db,player);var reference=Reference.new(db,player)
	var wall=Wall.new();var old_wall=Wall.new();var random=RandomNumberGenerator.new();random.seed=251025
	for i in 32:
		var actor=current.spawn(db.pool["250"],Vector2(480-i*12,0));actor.guns.clear()
	reference.enemies=current.enemies
	current.terrain=wall;reference.terrain=old_wall
	var nearest={"radarConfiguration":db.kind("ClosetTargetRadarConfiguration")[0].id}
	check(current.target_for(nearest,Vector2.ZERO,600).uid==reference.target_for(nearest,Vector2.ZERO,600).uid,"Open corridor chooses the same nearest target")
	var optimized_rays=wall.rays;var previous_rays=old_wall.rays
	check(optimized_rays==1 and previous_rays==32,"Priority ordering cuts 32 intermediate visibility rays to the one winning ray")
	var configurations=["ClosetTargetRadarConfiguration","FurthestRadarConfiguration","BiggestTargetRadarConfiguration","SmallestTargetRadarConfiguration","LowestHealthTargetRadarConfiguration","StunnedRadarConfiguration","RandomRadarConfiguration"]
	var matches=true;var rng_matches=true
	for scenario in 120:
		wall.blocked.clear();old_wall.blocked.clear()
		for e in current.enemies:
			e.position=Vector2(random.randi_range(-4,4)*80,random.randi_range(-4,4)*80)
			e.max_hp=random.randi_range(1,4)*100;e.hp=e.max_hp*float(random.randi_range(0,4))/4
			e.role="friendly" if random.randf()<.15 else "";e.warp=1.0 if random.randf()<.1 else 0.0
			e.cloaked=random.randf()<.1;e.stun=1.0 if random.randf()<.2 else 0.0;e.guns.clear()
			if random.randf()<.25:e.guns.append({"id":db.named("Core_Shield").id,"shield":100 if random.randf()>.2 else 0})
			if random.randf()<.5:wall.blocked[e.position]=true
		old_wall.blocked=wall.blocked.duplicate()
		for name in configurations:
			var core={"radarConfiguration":db.kind(name)[0].id}
			current.rng.seed=scenario*31;reference.rng.seed=scenario*31
			matches=matches and current.target_for(core,Vector2.ZERO,500).get("uid",0)==reference.target_for(core,Vector2.ZERO,500).get("uid",0)
			rng_matches=rng_matches and current.rng.state==reference.rng.state
	check(matches,"840 occluded targeting cases preserve shields, ties, dead/hidden/friendly filters and special radar behavior")
	check(rng_matches,"Random targeting consumes exactly the same RNG state")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"open_corridor_rays":{"before":previous_rays,"after":optimized_rays}}
	FileAccess.open("res://artifacts/cave-target-priority-20261025.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
