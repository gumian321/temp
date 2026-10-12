extends SceneTree
var checks=[]
func _initialize():
 var db=load('res://scripts/source_db.gd').new()
 for core in db.catalog.values():
  if not core.has('coreProjectile'):continue
  for chip_type in [0,1,2,3,4,5,6]:
   var player=load('res://scripts/centipede.gd').new(db);var battle=load('res://scripts/combat.gd').new(db,player)
   var target=battle.spawn(db.pool['250'],Vector2(120,0));target.hp=100000.0;target.max_hp=100000.0;target.mission_controlled=true;target.guns=[]
   var chips={} if chip_type==0 else {chip_type:2}
   var projectile=db.asset(core.coreProjectile)
   if projectile.get('class')=='ContinuousProjectile':battle.special.continuous(core,Vector2.ZERO,Vector2.RIGHT,true,chips,0,0.1)
   else:battle.fire(core,Vector2.ZERO,Vector2.RIGHT,true,chips)
   var emitted=battle.bullets.size()+battle.effects.size()+battle.barrages.size()>0 or target.hp<100000
   for frame in range(60):battle.step(1.0/60,Vector2(120,0),false)
   var finite=true
   for bullet in battle.bullets:finite=finite and Vector2(bullet.position).is_finite() and is_finite(float(bullet.damage))
   checks.append({'core':core.name,'projectile_class':projectile.get('class'),'chip_type':chip_type,'emitted':emitted,'finite':finite,'passed':emitted and finite})
 var report={'scope':'All catalog projectile cores emit and simulate at 60 Hz with each individual chip tier 2. Integration coverage, not exhaustive combinations or damage parity. Stationary high-health target is a disclosed test fixture.','checks':checks,'count':checks.size(),'passed':checks.all(func(c):return c.passed)}
 FileAccess.open('res://artifacts/weapon-catalog-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print('WEAPON_CATALOG ',checks.size(),' ',report.passed);quit(0 if report.passed else 1)
