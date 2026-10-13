extends "res://tests/test_centipede_scene.gd"
const Body=preload("res://scripts/centipede.gd")
const DB=preload("res://scripts/source_db.gd")
const Legs=preload("res://scripts/centipede_legs.gd")
func execute():
 var db=DB.new();var measurements=[]
 var art=load("res://assets/blue_ink/centipede_leg_links.png").get_image()
 check(art.has_mipmaps() or art.get_width()==1536,"Generated atlas is loaded at original resolution")
 check(art.get_pixel(0,0).a==0 and art.get_pixel(700,480).a==0,"Generated links have real transparent margins")
 for fps in [30,60,120]:
  var p=Body.new(db);var control=Body.new(db);var rig=Legs.new();var max_slip=0.0;var stance_samples=0;var max_joint_error=0.0
  for frame in range(fps*6):
   var direction=Vector2.RIGHT if frame<fps*2 else (Vector2.UP if frame<fps*3 else (Vector2.LEFT if frame<fps*4 else Vector2.ZERO))
   var previous={}
   for key in rig.segments:
    previous[key]=rig.segments[key].legs.duplicate(true)
   p.step(1.0/fps,direction,false);control.step(1.0/fps,direction,false);rig.step(p,1.0/fps)
   for key in rig.segments:
    var state=rig.segments[key]
    for i in 4:
     var pose=state.poses[i];max_joint_error=maxf(max_joint_error,maxf(absf(pose.root.distance_to(pose.knee)-Legs.UPPER),absf(pose.knee.distance_to(pose.foot)-Legs.LOWER)))
     if previous.has(key):
      var old=previous[key][i];var now=state.legs[i]
      if now.u<.5 and old.u<.5 and now.u>=old.u and old.recovery==0 and now.recovery==0:
       max_slip=maxf(max_slip,Vector2(now.foot).distance_to(old.foot));stance_samples+=1
  check(p.head==control.head and p.parts==control.parts,"Leg animation leaves player simulation unchanged at %d FPS"%fps)
  check(stance_samples>100 and max_slip<.001,"Planted feet do not slide at %d FPS"%fps)
  check(max_joint_error<.002,"Two-link limb lengths remain fixed at %d FPS"%fps)
  var before=rig.segments.duplicate(true)
  for i in fps:rig.step(p,1.0/fps)
  check(rig.segments==before,"Idle legs settle and stop stepping at %d FPS"%fps)
  measurements.append({"fps":fps,"stance_samples":stance_samples,"max_slip":max_slip,"max_joint_error":max_joint_error})
 var upper=Legs.solve(Vector2(12,19),Vector2(5,49),1);var lower=Legs.solve(Vector2(12,-19),Vector2(5,-49),-1)
 check(upper.knee.is_equal_approx(lower.knee*Vector2(1,-1)),"Left and right knees mirror correctly")
 var report={"checks":checks,"measurements":measurements,"passed":checks.all(func(c):return c.passed)}
 FileAccess.open("res://artifacts/player-legs-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
