extends SceneTree
## Production camera, draw and particle transforms under repeated heavy volleys.
var game
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
 checks.append({"name":title,"passed":ok})
 if not ok:printerr("FAIL: ",title)
func execute():
 root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.set_process(false);game.test_mode=false
 game.save.fresh();game.save.path="user://camera-stability-isolated.json"
 game.save.state.settings.skip_boss=false
 var modes:Dictionary={}
 for mission_id in game.db.stores.MissionDataStore.missionsList:
  game.selected_mission=game.db.asset(mission_id)
  game.start_run()
  var mode=str(game.run.mode.get("class",""))
  modes[mode]=true
  check(game.camera_focus.is_empty() and game.camera==game.player.head,"Opening immediately follows player: "+str(game.selected_mission.get("name","")))
 game.selected_mission=game.db.named("Survival Mission");game.start_run()
 game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
 game.run.rewards.queue.clear();game.run.packs=0
 game.tutorials.movement_shown=true;game.tutorials.radar_shown=true;game.tutorials.fuel_shown=true
 game.combat.enemies.clear();game.combat.drones.clear()
 var anchor:Vector2=game.player.head
 var peak_kick=0.0
 var peak_jitter=0.0
 var peak_luminance_delta=0.0
 var peak_changed_fraction=0.0
 var previous_kick=Vector2.ZERO
 var previous_samples:Array=[]
 var captures=0
 for frame in range(100):
  if frame%5==0:
   game.combat.effects.append({"kind":"muzzle","position":anchor,"direction":Vector2.RIGHT,"radius":18.0,"life":0.1,"fx_duration":0.1,"fx_family":"cannon","friendly":true,"particle_type":0})
   game.combat.effects.append({"kind":"explosion","position":anchor+Vector2(200,0),"direction":Vector2.RIGHT,"radius":150.0,"life":0.3,"fx_duration":0.3,"fx_family":"cannon","friendly":true,"particle_type":0,"hit_pause":0.023})
  game._process(1.0/60.0)
  game.player.head=anchor;game.camera=anchor
  peak_kick=maxf(peak_kick,game.camera_kick.length())
  peak_jitter=maxf(peak_jitter,game.camera_kick.distance_to(previous_kick));previous_kick=game.camera_kick
  game.queue_redraw();await process_frame
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   var image=root.get_texture().get_image()
   var samples:Array=[]
   for y in range(310,710,4):
    for x in range(40,300,4):
     var c=image.get_pixel(x,y);samples.append(c.r*0.2126+c.g*0.7152+c.b*0.0722)
   if not previous_samples.is_empty():
    var delta=0.0;var changed=0
    for i in samples.size():
     var d=absf(samples[i]-previous_samples[i]);delta+=d
     if d>0.003:changed+=1
    peak_luminance_delta=maxf(peak_luminance_delta,delta/samples.size())
    peak_changed_fraction=maxf(peak_changed_fraction,float(changed)/samples.size())
   previous_samples=samples;captures+=1
 check(peak_kick<0.01 and peak_jitter<0.01,"Repeated player fire and explosions do not shake the viewport")
 if captures>0:
  check(peak_luminance_delta<0.0001 and peak_changed_fraction<0.001,"Untouched terrain stays pixel-stable during volleys")
 game.camera=anchor-Vector2(300,80)
 game._process(1.0/60.0)
 var particle_anchor=game.particle_layer.transform*anchor
 check(particle_anchor.distance_to(game.world(anchor))<0.01,"Particles and world use the same final camera transform")
 game.camera=anchor
 var boss=game.combat.spawn(game.db.pool["55"],anchor+Vector2(500,0))
 boss.guns=[];boss.mission_controlled=true
 game._process(1.0/60.0)
 check(not game.camera_focus.is_empty() and game.camera_focus.boss,"A later boss event still triggers its cinematic")
 game._process(1.0/60.0)
 check((game.particle_layer.transform*anchor).distance_to(game.world(anchor))<0.01,"Cinematic motion also keeps particle transforms aligned")
 game.camera_focus.clear();game.combat.enemies.clear();game.camera=anchor
 game.combat.effects.clear()
 game.combat.effects.append({"kind":"hit","position":anchor+Vector2(30,0),"direction":Vector2.RIGHT,"radius":6.0,"life":0.1,"fx_duration":0.1,"fx_family":"impact","friendly":false,"particle_type":0,"player_hit":true})
 var damage_peak=0.0;var damage_step=0.0;var damage_previous=game.camera_kick
 for frame in 90:
  game._process(1.0/60.0)
  damage_peak=maxf(damage_peak,game.camera_kick.length())
  damage_step=maxf(damage_step,game.camera_kick.distance_to(damage_previous));damage_previous=game.camera_kick
 check(damage_peak>0.0 and damage_peak<=1.0 and damage_step<=0.101 and game.camera_kick.length()<0.001,"Player damage retains a bounded smooth nudge and settles")
 game.camera_kick=Vector2.ONE;game.start_run()
 check(game.camera_kick==Vector2.ZERO,"Restart clears the previous run camera feedback")
 var report={"checks":checks,"passed":checks.all(func(c):return c.passed),"modes":modes.keys(),"rendered_frames":captures,"player_damage_peak_offset":damage_peak,"player_damage_peak_step":damage_step,"peak_camera_offset":peak_kick,"peak_frame_jitter":peak_jitter,"peak_terrain_luminance_delta":peak_luminance_delta,"peak_changed_terrain_fraction":peak_changed_fraction}
 var suffix=OS.get_environment("CAMERA_REPORT_SUFFIX")
 FileAccess.open("res://artifacts/camera-stability"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report))
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear()
 game.process_mode=Node.PROCESS_MODE_DISABLED
 for i in 12:OS.delay_msec(10);await process_frame
 game.queue_free();await process_frame;await process_frame
 quit(0 if report.passed else 1)
