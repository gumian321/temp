extends SceneTree
var game: Node
var out:="/tmp/hn-v02-visual"
var records:Array=[]
const Z:=[0.0,0.0,false,false]
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
 run.call_deferred()
func frames(count: int) -> void:
 for i in range(count):await process_frame
func configure(kind: int, outcome: String) -> void:
 game.net.rules.reset(kind*10+outcome.length());game.net.rules.start()
 game.net.demo=true;game.net.hosting=true
 game.net.role="driver" if outcome=="counter" else "coach"
 game.world.glance=true
 if kind>=3:
  game.net.rules.event("driver","prank",kind)
  if outcome=="windup":
   for i in range(70):game.net.rules.step(Z,Z)
  elif outcome=="counter":
   game.net.rules.event("coach","counter",kind)
   for i in range(85):game.net.rules.step(Z,Z)
  else:
   for i in range(180):game.net.rules.step(Z,Z)
 game.net.state=game.net.rules.s.duplicate(true)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(out)
 game=load("res://game/play.tscn").instantiate();root.add_child(game)
 game.net.set_physics_process(false);game.set_physics_process(false)
 game.world.set_low(true);game.light_toggle.button_pressed=true
 await frames(6)
 for kind in [-1,3,4,5]:
  configure(kind,"hit")
  await frames(5)
  var samples:Array=[]
  for i in range(30):
   var before:=Time.get_ticks_usec()
   await process_frame
   samples.append((Time.get_ticks_usec()-before)/1000.0)
  samples.sort()
  var total:=0.0
  for v in samples:total+=v
  records.append({"kind":kind,"mean_ms":total/30,"p95_ms":samples[28],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
  if kind>=3:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/prank-%d-hit.png"%kind)
 for kind in [3,4,5]:
  for outcome in ["windup","counter"]:
   configure(kind,outcome);await frames(6)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/prank-%d-%s.png"%[kind,outcome])
 var report:={"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"low":true,"view":"coach inward glance; frozen rule checkpoint, animated props", "samples_per_case":30,"records":records,"note":"Actual graphical viewport. Software renderer. Capture fixture advances real rules then freezes state; not a live multiplayer screenshot."}
 FileAccess.open(out+"/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("COMEDY_CAPTURE_PASS ",JSON.stringify(report));quit()
