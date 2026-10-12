extends SceneTree
func _initialize():call_deferred('execute')
func execute():
 var game=load('res://main.tscn').instantiate();root.add_child(game);await process_frame
 Input.warp_mouse(Vector2(1200,450))
 seed(20261012)
 setup_fixture(game)
 if OS.get_environment('RBPEW_WARMUP')=='1':
  var warm_start=Time.get_ticks_msec()
  while Time.get_ticks_msec()-warm_start<8000:await process_frame
  setup_fixture(game);await process_frame
 var frames=0;var peak=0;var bullets=0;var emitters=0;var draw_calls=0;var durations=[];var start=Time.get_ticks_msec();var previous=start
 while Time.get_ticks_msec()-start<30000:
  await process_frame
  var now=Time.get_ticks_msec();durations.append(now-previous);previous=now;frames+=1
  emitters=maxi(emitters,game.particle_effects.get_child_count());draw_calls=maxi(draw_calls,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
  peak=maxi(peak,game.combat.enemies.size());bullets=maxi(bullets,game.combat.bullets.size())
 durations.sort()
 await game.capture('14-full-capacity-combat')
 var report={'renderer':'Actual X11 Godot window, Mesa llvmpipe software rendering','fixture':'60 legally adjacent source modules at start; source damage and natural combat; no invulnerability.','elapsed_real_seconds':(Time.get_ticks_msec()-start)/1000.0,'profile':game.performance_samples,'revision':OS.get_environment('RBPEW_REVISION'),'frames':frames,'average_fps':frames/30.0,'p95_frame_ms':durations[int(durations.size()*0.95)],'peak_enemies':peak,'peak_bullets':bullets,'peak_particle_emitters':emitters,'peak_draw_calls':draw_calls,'llvmpipe_threads':OS.get_environment('LP_NUM_THREADS'),'warmup':OS.get_environment('RBPEW_WARMUP'),'remaining_parts':game.player.parts.size(),'screen':game.screen}
 FileAccess.open('res://artifacts/gui-stress-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));await game.safe_shutdown()

func setup_fixture(game):
 seed(20261012)
 game.test_time=0;game.performance_samples.clear()
 game.test_mode=true;game.save.fresh();game.save.path='user://stress-isolated.json';game.save.state.settings.skip_boss=true;game.selected_mission=game.db.named('Endless Mission');game.start_run()
 var cells=[]
 for y in range(-5,6):
  for x in range(-5,6):cells.append(Vector2i(x,y))
 cells.sort_custom(func(a,b):return a.length_squared()<b.length_squared())
 for cell in cells:
  var name='Core_Shield' if game.player.parts.size()%4==0 else 'Core_Gun_Gatling'
  if game.player.parts.size()%9==0:name='Core_Drones_Engineer'
  game.player.add_piece(game.db.named(name).id,cell)
  if game.player.parts.size()==61:break
