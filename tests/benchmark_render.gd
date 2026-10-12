extends SceneTree
func _initialize():call_deferred('execute')
func execute():
 seed(20261012)
 var game=load('res://main.tscn').instantiate();root.add_child(game);await process_frame
 game.set_process(false);game.test_mode=true;game.save.fresh();game.save.path='user://benchmark-render.json';game.save.state.settings.skip_boss=true;game.selected_mission=game.db.named('Endless Mission');game.start_run()
 var cells=[]
 for y in range(-5,6):
  for x in range(-5,6):cells.append(Vector2i(x,y))
 cells.sort_custom(func(a,b):return a.length_squared()<b.length_squared())
 for cell in cells:
  var name='Core_Shield' if game.player.parts.size()%4==0 else 'Core_Gun_Gatling'
  if game.player.parts.size()%9==0:name='Core_Drones_Engineer'
  game.player.add_piece(game.db.named(name).id,cell)
  if game.player.parts.size()==61:break
 var ticks=0;var cpu_start=Time.get_ticks_usec()
 for frame in range(600):
  game.player.step(1.0/60,Vector2.from_angle(frame/60.0*0.7),false)
  game.combat.step(1.0/60,game.player.head+Vector2.RIGHT*500,true);game.run.step(1.0/60)
  game.combat.audio_events.clear();game.combat.effects.clear();ticks+=1
 var cpu_usec=Time.get_ticks_usec()-cpu_start
 game.camera=game.player.head;game.center=Vector2(720,450);game.update_source_hud();game.menu_background.visible=false;game.tutorials.visible=false;game.particle_effects.clear();game.audio_system.shutdown()
 if OS.get_environment("RBPEW_CPU_ONLY")!="1":
  for i in range(30):game.queue_redraw();await process_frame
 var frames=0;var durations=[];var draws=[];var objects=[];var start=Time.get_ticks_usec();var previous=start
 while OS.get_environment('RBPEW_CPU_ONLY')!='1' and Time.get_ticks_usec()-start<15000000:
  game.queue_redraw();await process_frame
  var now=Time.get_ticks_usec();durations.append((now-previous)/1000.0);previous=now;frames+=1
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
 if frames==0:durations=[0];draws=[0];objects=[0]
 durations.sort();draws.sort();objects.sort()
 var report={'mode':'Identical frozen 600-tick full-capacity scene; all actor/UI/background graphics retained. Particles excluded only in this diagnostic; separate live benchmark retains them.','revision':OS.get_environment('RBPEW_REVISION'),'frames':frames,'real_seconds':(Time.get_ticks_usec()-start)/1000000.0,'fps':frames/15.0,'p95_frame_ms':durations[int(durations.size()*0.95)],'median_draw_calls':draws[int(draws.size()/2)],'median_render_objects':objects[int(objects.size()/2)],'cpu_600_ticks_ms':cpu_usec/1000.0,'combat_phase_usec':game.combat.phase_times,'parts':game.player.parts.size(),'enemies':game.combat.enemies.size(),'bullets':game.combat.bullets.size(),'head':[game.player.head.x,game.player.head.y],'hq_hp':game.player.parts[0].hp}
 var label=OS.get_environment('RBPEW_BENCH_LABEL')
 FileAccess.open('res://artifacts/'+label+'-render-benchmark.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));
 if OS.get_environment('RBPEW_CPU_ONLY')!='1':await game.capture(label+'-render-benchmark')
 await game.safe_shutdown()
