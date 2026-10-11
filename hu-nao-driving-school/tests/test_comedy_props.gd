extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var props=preload("res://game/comedy.gd").new();root.add_child(props)
 var rules=preload("res://game/rules.gd").new()
 var count:int=props.get_child_count()
 for kind in range(3,6):
  rules.reset(kind);rules.start();rules.event("driver","prank",kind)
  props.update_effects(rules.s,.016)
  var sounds:int=props.played.size()
  props.update_effects(rules.s,.016)
  check(props.played.size()==sounds,"same authoritative stage must not replay sound")
  check(props.caption.visible,"every prank has visible cue")
  rules.event("coach","counter",kind);props.update_effects(rules.s,.016)
  check(props.played.size()==sounds+1,"counter produces distinct one-shot feedback")
  check(rules.s.act_target=="driver","backlash stage targets student")
  if kind==3:
   for i in range(10):
    var p:Vector3=props.cloud_positions[i]
    check(p.y<=1.055 and p.y>=.91 and p.z>=.32 and p.z<=.49,"gas stays inside seat-local bounds")
  if kind==4:check(props.bag.visible and props.tissue.visible,"bag and tissue visible on reversal")
  if kind==5:check(props.recorder.visible,"recorder visible on reversal")
  var clip=props.make_clip(kind,"counter")
  check(clip.data.size()>10000 and clip.data.size()<44100,"bounded synthesized audio sample")
 for i in range(200):
  rules.perform(3,"counter",3,"driver");props.update_effects(rules.s,.016)
 check(props.played.size()<=64,"sound dedup history bounded")
 check(props.get_child_count()==count,"prop nodes preallocated; no per-event node growth")
 rules.reset(100);props.update_effects(rules.s,.016)
 check(not props.clouds.visible and not props.recorder.visible and not props.tissue.visible,"return to room clears visuals")
 await create_timer(.3).timeout
 props.synth.stop()
 props.queue_free()
 await process_frame
 print("COMEDY_PROPS_PASS" if failures==0 else "COMEDY_PROPS_FAIL"," checks=",checks," failures=",failures)
 finish.call_deferred(failures)
func finish(count: int) -> void:
 quit(1 if count else 0)
