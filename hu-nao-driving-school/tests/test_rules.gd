extends SceneTree
const Rules = preload("res://game/rules.gd")
const Z := [0.0, 0.0, false, false]
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
 checks += 1
 if not ok:
  push_error("FAIL: " + text)
  failures += 1
func _init() -> void:
 var r = Rules.new()
 check(not r.event("driver", "prank", 0), "room blocks pranks")
 r.start()
 check(not r.event("coach", "prank", 0), "roles enforced")
 check(not r.event("driver", "prank", 6), "bad type rejected")
 for kind in range(6):
  r.reset(kind + 1); r.start()
  check(r.event("driver", "prank", kind), "prank available")
  check(r.s.resource == 20, "one resource debit")
  check(not r.event("driver", "prank", kind), "cooldown blocks repeat")
  check(r.s.anger == 0, "no damage before windup")
  check(r.s.act_phase=="windup" and r.s.act_kind==kind,"authoritative windup stage")
  check(r.event("coach", "counter", kind), "matching counter succeeds")
  if kind>=3:
   check(r.s.backlash[kind]>0 and r.s.backfires==1,"new counter bounces onto student")
   check(r.s.act_phase=="counter" and r.s.act_target=="driver","counter targets student")
   check(r.s.resource==15,"backfire costs five extra inspiration")
   for frame in range(91):r.step([0.0,0.0,false,true],Z)
   check(r.s.backlash.all(func(v):return v==0) and r.s.driver_repairs==1,"student can clean own backlash")
  for i in range(180): r.step(Z, Z)
  check(r.s.anger == 0 and r.s.counters == 1, "counter prevents hit")
  r.s.cooldown = 0
  r.s.resource=40
  check(r.event("driver", "prank", kind), "second prank available")
  for i in range(180): r.step(Z, Z)
  check(r.s.hits == 1 and r.s.anger == Rules.ANGER[kind], "windup resolves once")
  check(r.s.effects[kind] > 0, "effect persists")
  for i in range(91): r.step(Z, [0.0, 0.0, false, true])
  check(r.s.effects.all(func(v):return v==0) and r.s.repairs == 1, "all effects repair")
  r.s.resource = 100; r.s.cooldown = 0
  var before: float = r.s.anger
  r.event("driver", "prank", kind)
  for i in range(180): r.step(Z, Z)
  check(r.s.anger - before < Rules.ANGER[kind], "repeat payoff diminished")
 r.reset(8); r.start()
 for i in range(120): r.step([1.0, 0.0, false, false], Z)
 check(r.s.resource > 40 and r.s.speed > 8, "normal driving earns resource")
 var speed: float = r.s.speed
 for i in range(60): r.step([1.0, 0.0, false, false], [0.0, 0.0, true, false])
 check(absf(r.s.speed) < speed * .1, "coach brake overrules throttle")
 for i in range(181): r.step([1.0, 0.0, false, false], [0.0, 0.0, true, false])
 check(r.s.brake_locked and not r.s.brake, "holding coach brake cannot stall the whole match")
 for i in range(181): r.step(Z, Z)
 check(r.s.brake_charge == 3 and not r.s.brake_locked, "releasing brake recovers charge")
 r.reset(8); r.start()
 r.s.x = 36.99; r.s.z = 25; r.s.yaw = PI / 2; r.s.speed = 10
 var resource: float = r.s.resource
 r.step([1.0, 0.0, false, false], Z)
 check(r.s.crashes == 1 and r.s.anger == 0, "crash never awards anger")
 check(r.s.resource == resource and r.s.crash_cd > 0, "collision suspends income")
 r.reset(9); r.start()
 for i in range(18001): r.step(Z, Z)
 check(r.s.winner == "coach" and r.s.phase == "ended", "full 300 simulated seconds coach win")
 check(not r.event("driver", "prank", 0), "end blocks input")
 r.reset(10); r.start()
 r.s.anger = 90; r.event("driver", "prank", 2)
 for i in range(120): r.step(Z, Z)
 check(r.s.winner == "driver" and r.s.anger == 100, "anger win clamps to 100")
 r.reset(11)
 check(r.s.phase == "room" and r.s.hits == 0 and r.s.effects[2] == 0, "reset clears round")
 r.start()
 r.event("driver","prank",3)
 var old_z:float=r.s.z
 for frame in range(60):r.step([1.0,.25,false,false],Z)
 check(r.s.z!=old_z and r.s.speed>0,"comedy never locks driving")
 r.s.cooldown=0
 check(not r.event("driver","prank",4),"only one major windup even with cooldown reset")
 r.reset(12)
 check(r.s.act_phase=="idle" and r.s.backfires==0 and r.s.backlash.all(func(v):return v==0),"restart clears comedy and backlash")
 var a: Dictionary = r.s.duplicate(true)
 var b: Dictionary = r.s.duplicate(true)
 for i in range(240):
  Rules.drive(a, [.8, .5, false, false], false, Rules.DT)
 for i in range(120): Rules.drive(b, [.8, .5, false, false], false, Rules.DT)
 var checkpoint: Dictionary = b.duplicate(true)
 for i in range(120): Rules.drive(checkpoint, [.8, .5, false, false], false, Rules.DT)
 check(a == checkpoint, "kinematic motion replay matches")
 print("RULE_TESTS_PASS" if failures == 0 else "RULE_TESTS_FAIL", " checks=", checks, " failures=", failures)
 quit(0 if failures == 0 else 1)
