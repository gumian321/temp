extends "res://tests/test_centipede_scene.gd"
func execute():
 root.size=Vector2i(1440,900);game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_process(false);game.save.fresh();game.save.state.settings.skip_boss=true;game.start_run();game.camera_focus.clear();game.combat.enemies.clear();game.combat.drones.clear();game.tutorials.visible=false;game.tutorials.movement_shown=true;game.tutorials.fuel_shown=true;game.tutorials.radar_shown=true
 game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0};game.zoom=2.2
 game.player.install_module(game.db.named("Core_Gun_Cannon").id,2,4)
 game.player.install_module(game.db.named("Core_FuelTank").id,4,4);game.player.fuel=game.player.max_fuel
 DirAccess.make_dir_recursive_absolute("res://artifacts/player-leg-frames")
 var step=0
 for stage in ["straight","turn","boost","stop"]:
  for action in ["move_right","move_up","boost"]:Input.action_release(action)
  if stage in ["straight","boost"]:Input.action_press("move_right")
  if stage=="turn":Input.action_press("move_up")
  if stage=="boost":Input.action_press("boost")
  for i in 60:
   game._process(1.0/60);game.combat.enemies.clear();game.combat.bullets.clear();game.camera=(game.player.head+Vector2(game.player.segment_pose(game.player.segment_count()).point))*.5
   if i%4==0 and DisplayServer.get_name()!="headless":
    game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
    var img=root.get_texture().get_image();img.resize(1152,720,Image.INTERPOLATE_LANCZOS);img.save_jpg("res://artifacts/player-leg-frames/frame-%03d.jpg"%step,.92);step+=1
  check(game.screen=="game" and game.player_legs.segments.size()==game.player.segment_count(),"Real leg rig stays attached during "+stage)
  if stage in ["straight","turn","stop"]:await capture("player-legs-"+stage)
 check(game.player.velocity.length()<.01,"Real input release stops the head")
 game.show_build_ui();await capture("player-legs-build-preview")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await process_frame;await process_frame
 var report={"checks":checks,"frames":step,"captures":captures,"passed":checks.all(func(c):return c.passed)}
 FileAccess.open("res://artifacts/player-legs-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
