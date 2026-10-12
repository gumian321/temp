extends SceneTree
func _initialize():
 var db=load('res://scripts/source_db.gd').new();var p=load('res://scripts/centipede.gd').new(db);var b=load('res://scripts/combat.gd').new(db,p)
 var actor={}
 for prefab in db.entities:
  for blueprint in db.entities[prefab]:
   if blueprint.unit.get('class')=='AISwarmingUnit':actor=b.spawn_actor(prefab,blueprint,Vector2(250,0));break
  if not actor.is_empty():break
 var core=db.named('Core_AI_Drones_Attack');actor.guns=[];var gun={'id':core.id}
 b.ensure_enemy_drones(actor,gun,core)
 var count=b.enemy_drones.size();var fired=false;var launched=false
 for i in range(240):
  b.step_enemy_drones(1.0/60)
  fired=fired or b.bullets.any(func(bullet):return not bullet.friendly and bullet.data.id==db.asset(core.coreDrone).droneProjectile)
  launched=launched or b.enemy_drones.any(func(d):return not d.docked and d.position.distance_to(actor.position)>5)
 actor.hp=0;b.step_enemy_drones(1.0/60)
 var report={'source_drone_count':count,'launched':launched,'hostile_projectiles_fired':fired,'removed_after_owner_destroyed':b.enemy_drones.is_empty(),'passed':count==int(core.DroneCount) and fired and launched and b.enemy_drones.is_empty()}
 FileAccess.open('res://artifacts/enemy-drone-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
