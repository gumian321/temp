extends "res://tests/test_centipede_scene.gd"
var clip_frame=0
var states=[]
func capture_state(tag:String,frames:int=36):
 var title=Label.new();title.text="LIVING SHIELD / "+tag.to_upper();title.position=Vector2(400,180);title.add_theme_font_size_override("font_size",26);root.add_child(title)
 title.add_theme_color_override("font_color",Color("203a4a"))
 var before=game.player.parts[3].shield
 for frame in range(frames):
  game.player.step_feedback(1.0/30.0)
  game.passive_fx.clock+=1.0/30.0
  game.test_time+=1.0/30.0
  game.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  var img=root.get_texture().get_image()
  check(img.save_png("res://artifacts/round14/shield-frames/frame-%04d.png"%clip_frame)==OK,"Native shield frame %d"%clip_frame)
  if frame==0:
   check(img.save_png("res://artifacts/round14/shield-"+tag+".png")==OK,"State capture "+tag)
   states.append({"state":tag,"counts":game.passive_fx.living.counts.duplicate(),"shield":before,"frame":clip_frame})
  clip_frame+=1
 title.queue_free()
func execute():
 if DisplayServer.get_name()=="headless":
  printerr("ERROR: Native renderer required for living shader scene");quit(1);return
 root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.set_process(false);game.save.fresh();game.save.state.settings.skip_boss=true;game.start_run()
 game.combat.enemies.clear();game.combat.bullets.clear();game.combat.effects.clear()
 for name in ["Core_Gun_Gatling","Core_Chip_Mammoth","Core_Shield","Core_Repair","Core_Gun_Cannon","Core_Clocking","Core_FuelTank"]:
  check(game.player.append_segment(game.db.named(name).id),"Install "+name)
 game.camera=game.player.head+Vector2(-170,0);game.zoom=1.3
 game.player.reinforce(1);game.player.pulse_chip_sources(1)
 game.player.parts[5].hp-=20;game.combat.step(.1,Vector2.RIGHT,false,false)
 game.passive_fx.tick(game,.2);game.passive_fx.notices.clear();game.passive_fx.card.hide()
 game.player.boost=true
 game.passive_fx.tick(game,.2);game.passive_fx.notices.clear();game.passive_fx.card.hide()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/round14/shield-frames"))
 check(game.passive_fx.living.nodes.size()==6 and game.passive_fx.living.material_count==6,"Six fixed MultiMesh ShaderMaterial batches")
 for node in game.passive_fx.living.nodes:check(node.material is ShaderMaterial,"Native passive material attached")
 await capture_state("sustain")
 var part=game.player.parts[3]
 var hit_at=part.position+Vector2.RIGHT*game.combat.shield_range(3)
 game.combat.hurt_player(3,0,1,{"position":hit_at,"velocity":Vector2.LEFT*200,"data":{},"friendly":false,"damage":0,"shield_damage":1})
 check(part.feedback_pulses.has("shield_hit"),"Real damage event emits local shield impact")
 await capture_state("hit",18)
 game.combat.hurt_player(3,0,99999,{"position":hit_at,"velocity":Vector2.LEFT*200,"data":{},"friendly":false,"damage":0,"shield_damage":1})
 check(part.shield_broken and part.feedback_pulses.has("shield_break"),"Real shield break state")
 await capture_state("break",24)
 game.combat.step(part.shield_delay+.01,Vector2.RIGHT,false,false)
 check(part.shield>0 and part.feedback_pulses.has("shield_recharge"),"Real recharge state")
 await capture_state("recover",36)
 var counts=game.passive_fx.living.counts.duplicate()
 check(counts[0]>0,"Shield shader instances visible after recovery")
 game.radar_mode=true;game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 check(game.passive_fx.living.nodes.all(func(n):return n.multimesh.visible_instance_count==0),"Radar early return clears all passive instances")
 game.radar_mode=false;game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 check(game.passive_fx.living.nodes[0].multimesh.visible_instance_count>0,"Leaving radar reconstructs shield")
 game.screen="pause";var pause_clock=game.passive_fx.clock;game.passive_fx.tick(game,1);game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 check(game.passive_fx.clock==pause_clock and game.passive_fx.living.nodes[0].multimesh.visible_instance_count>0,"Pause preserves shield with frozen shader time")
 game.screen="menu";game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 check(game.passive_fx.living.nodes.all(func(n):return n.multimesh.visible_instance_count==0),"Menu clears all passive instances")
 game.start_run();game.passive_fx.reset();game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 check(game.passive_fx.living.nodes.all(func(n):return n.multimesh.visible_instance_count==0),"Reset leaves no old passive instances")
 var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"states":states,"frames":clip_frame,"fps":30,"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"scope":"Production main renderer. Sustain, hit, break and recovery originate from real combat/player state. Fixed isolated save. No gameplay clock advancement during visual segments."}
 FileAccess.open("res://artifacts/round14/living-shader-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear()
 await create_timer(.2).timeout
 quit(0 if report.passed else 1)
