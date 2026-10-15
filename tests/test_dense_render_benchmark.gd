extends SceneTree
# Native renderer benchmark; intentionally independent from wall-clock simulation.
class ProfiledGame:
 extends "res://scripts/main.gd"
 var draw_samples = []
 func _draw():
  var started = Time.get_ticks_usec()
  super._draw()
  draw_samples.append((Time.get_ticks_usec()-started)/1000.0)
const DT = 1.0/60.0
const WARMUP = 60
const FRAMES = 180
func _initialize(): call_deferred("execute")
func stats(values:Array)->Dictionary:
 var ordered=values.duplicate();ordered.sort()
 var total=0.0
 for value in values: total+=float(value)
 return {"p50":ordered[ordered.size()/2],"p95":ordered[mini(ordered.size()-1,int(ordered.size()*0.95))],"mean":total/ordered.size(),"max":ordered[-1]}
func execute():
 if DisplayServer.get_name()=="headless":
  push_error("This benchmark requires a native renderer, not --headless")
  quit(1);return
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 DisplayServer.window_set_size(Vector2i(1440,900))
 Engine.max_fps=0
 seed(20261014)
 var game=ProfiledGame.new();root.add_child(game);await process_frame
 game.set_process(false);game.test_mode=true;game.save.fresh();game.save.path="user://dense-render-isolated.json";game.save.state.settings.skip_boss=true;game.selected_mission=game.db.named("Endless Mission");game.start_run()
 game.combat.enemies.clear();game.combat.bullets.clear();game.combat.patrols.clear();game.combat.effects.clear()
 var gun=game.db.named("Core_Gun_Gatling")
 var cells=[]
 for y in range(-5,6):
  for x in range(-5,6):cells.append(Vector2i(x,y))
 cells.sort_custom(func(a,b):return a.length_squared()<b.length_squared())
 for cell in cells:
  game.player.add_piece(gun.id,cell)
  if game.player.parts.size()==31:break
 for part in game.player.parts:part.hp=10000000.0;part.max_hp=10000000.0
 for i in range(64):
  var enemy=game.combat.spawn(game.db.pool["256" if i%4==0 else "255"],Vector2.from_angle(TAU*i/64.0)*(220.0+float(i%7)*60.0))
  enemy.hp=10000000.0;enemy.max_hp=10000000.0
 game.camera=game.player.head;game.center=Vector2(720,450);game.menu_background.visible=false;game.tutorials.visible=false;game.audio_system.shutdown()
 var frames=[];var draws=[];var objects=[];var cpu=[];var bullets=[];var effects=[];var emitters=[]
 for frame in range(WARMUP+FRAMES):
  if frame==WARMUP:game.draw_samples.clear()
  var started=Time.get_ticks_usec()
  for i in range(maxi(0,256-game.combat.bullets.size())):
   var angle=float(frame*17+i)*2.39996323
   var friendly=i%2==0
   game.combat.fire(gun,game.player.head+Vector2.from_angle(angle)*(60 if friendly else 600),Vector2.from_angle(angle)*(1 if friendly else -1),friendly,{},0,true)
  game.player.step(DT,Vector2.from_angle(frame*0.011),false)
  game.leg_phase+=game.player.velocity.length()*DT*0.075;game.player_legs.step(game.player,DT)
  game.combat.step(DT,game.player.head+Vector2.RIGHT*600,true)
  for effect in game.combat.effects:
   if effect.get("rendered",false):continue
   effect.rendered=true
   var type=int(effect.get("particle_type",303 if effect.kind=="explosion" else (305 if effect.kind=="hit" else 0)))
   if effect.kind in ["hit","shield_hit"] or (effect.kind=="explosion" and effect.has("fx_family")):type=0
   if type>0 and game.particle_effects.get_child_count()<200:game.particle_effects.play(type,effect.position,1,float(effect.get("duration",0)),effect.get("follow",{}))
  game.particle_effects.sync_flames(game.combat.effects)
  game.combat.audio_events.clear();game.player.feedback_events.clear()
  game.test_time+=DT;game.camera=game.player.head
  game.update_source_hud();game.sync_camera_layers();game.insect_layer.sync(game,DT);game.queue_redraw()
  var cpu_end=Time.get_ticks_usec()
  await process_frame
  await RenderingServer.frame_post_draw
  if frame>=WARMUP:
   frames.append((Time.get_ticks_usec()-started)/1000.0);cpu.append((cpu_end-started)/1000.0)
   draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
   bullets.append(game.combat.bullets.size());effects.append(game.combat.effects.size());emitters.append(game.particle_effects.get_child_count())
 var hp=0.0
 for enemy in game.combat.enemies:hp+=enemy.hp
 var report={"fixture_version":1,"scope":"Native rendered fixed-step dense battle: 31 modules, 64 durable tank/shield enemies, production projectile floor 256; real drawing, soft actors, weapon FX, HUD, background retained. Mission spawning/audio excluded. Wall frame time includes CPU and renderer; not user hardware FPS.","revision":OS.get_environment("RBPEW_REVISION"),"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"viewport":[1440,900],"vsync_requested":"disabled","vsync_reported_mode":DisplayServer.window_get_vsync_mode(),"vsync_note":"Driver may reject vsync changes; inspect native log for warnings. Reported enum alone does not guarantee compositor behavior.","warmup_frames":WARMUP,"measured_frames":FRAMES,"frame_ms":stats(frames),"simulation_prepare_ms":stats(cpu),"main_draw_build_ms":stats(game.draw_samples),"draw_calls":stats(draws),"render_objects":stats(objects),"bullets":stats(bullets),"effects":stats(effects),"particle_emitters":stats(emitters),"signature":{"enemies":game.combat.enemies.size(),"parts":game.player.parts.size(),"bullets":game.combat.bullets.size(),"hp_sum":hp,"rng":str(game.combat.rng.state),"head":[game.player.head.x,game.player.head.y]}}
 var path=OS.get_environment("RBPEW_DENSE_RENDER_OUTPUT")
 if path.is_empty():path="res://artifacts/dense-render-benchmark.json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("DENSE_RENDER_REPORT ",JSON.stringify(report))
 var screenshot=path.get_basename()+".png"
 var image=root.get_texture().get_image()
 var capture_error=image.save_png(screenshot)
 print("DENSE_RENDER_SCREENSHOT ",screenshot," result=",capture_error)
 await game.safe_shutdown()
