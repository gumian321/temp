extends "res://tests/test_brood.gd"
var measurements:Array=[]
func execute():
 var db=DB.new();var body=Body.new(db);var battle=Battle.new(db,body)
 var grub_ids=[]
 for id in db.pool:
  var e=battle.spawn(db.pool[id],Vector2.ZERO)
  if not e.is_empty() and Brood.eligible(e) and Brood.species(e)=="grub":grub_ids.append({"pool":id,"prefab":e.prefab,"name":e.name,"kind":e.kind})
 check(not grub_ids.is_empty(),"Actual source enemy prefabs use the grub art")
 for species in Brood.SPECIES:
  var cycles=[]
  for fps in [30,60,120]:
   var e=specimen(species);e.radius=15.0
   var rig=Rig.new();root.add_child(rig);rig.setup(e)
   var biggest=0.0;var max_joint_speed=0.0;var previous=Vector2.ZERO
   var initial_hp=e.hp
   for frame in range(fps*4):
    var direction=Vector2.RIGHT if frame<fps else (Vector2.UP if frame<fps*2 else (Vector2.ZERO if frame<fps*3 else Vector2.LEFT))
    e.position+=direction*96.0/fps
    if direction!=Vector2.ZERO:e.angle=rotate_toward(e.angle,direction.angle(),2.5/fps)
    var before=rig.legs[0].node.rotation
    Soft.step(e,1.0/fps);rig.pose(1.0/fps)
    biggest=maxf(biggest,rig.visual_offset.distance_to(previous));previous=rig.visual_offset
    max_joint_speed=maxf(max_joint_speed,absf(angle_difference(before,rig.legs[0].node.rotation))*fps)
   check(biggest<.04 and max_joint_speed<15,"Bounded start/stop/turn body and legs: %s %dFPS"%[species,fps])
   check(e.hp==initial_hp,"Visual pose does not change health")
   measurements.append({"species":species,"fps":fps,"max_offset_step":biggest,"max_leg_radians_per_second":max_joint_speed,"gait_cycles":rig.gait/TAU})
   # Explicit wrap boundary is interpolated over the short arc.
   rig.display_heading=PI-.01;e.angle=-PI+.01-PI/2;rig.pose(1.0/fps)
   check(absf(angle_difference(PI-.01,rig.display_heading))<.03,"No PI wrap flip: "+species)
   rig.free()
  var e=specimen(species);var before_position=e.position;var before_angle=e.angle;var initial_health=e.hp
  for family in ["cannon","gatling","flame","blackhole","shield"]:
   Soft.prepare(e)
   for f in range(240):
    Soft.impact(e,e.position+Vector2(-20,0),Vector2.RIGHT,10,family)
    Soft.step(e,1.0/120)
   check(e.soft_body.cue<=65 and e.soft_body.recoil.length()<=.231 and Array(e.soft_body.offset).all(func(v):return v.length()<=.301),"High-rate body feedback stays bounded: "+species+" "+family)
   for f in range(480):Soft.step(e,1.0/120)
   check(e.soft_body.hold==0 and e.soft_body.recoil.length()<.002 and Array(e.soft_body.offset).all(func(v):return v.length()<.002),"Body recovers after sustained fire: "+species+" "+family)
  check(e.position==before_position and e.angle==before_angle and e.hp==initial_health,"Hit animation leaves AI transform and HP untouched: "+species)
 # Real combat entry points, including elite/Boss parts and direct area ticks.
 var kinds={}
 for e in battle.enemies:
  if not Brood.eligible(e) or e.hp<=0:continue
  kinds[e.kind]=true
  var hp=e.hp;e.max_hp=maxf(e.max_hp,1000);e.hp=1000;e.guns=[]
  var projectile=db.named("Core_Gun_Gatling")
  var data=db.asset(projectile.coreProjectile)
  battle.hit_enemy(e,{"data":data,"damage":1.0,"shield_damage":1.0,"friendly":true,"chips":{},"position":e.position-Vector2(5,0),"velocity":Vector2.RIGHT,"pierce":1,"hit":[]})
  check(e.has("soft_body") and e.soft_body.cue>0,"Combat hit reaches body: "+str(e.kind))
 var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"measurements":measurements,"grub_source_ids":grub_ids,"actual_hit_kinds":kinds.keys()}
 FileAccess.open("res://artifacts/enemy-motion-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
