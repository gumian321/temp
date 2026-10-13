extends "res://tests/test_centipede_scene.gd"
var geometry:Array=[]
func settle():
 for i in 4:await process_frame
func shot(tag:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var path="res://artifacts/hud-"+tag+".png"
 check(root.get_texture().get_image().save_png(path)==OK,"Capture "+tag);captures.append(path)
func execute():
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
 game.set_process(false);game.save.fresh();game.save.state.settings.skip_boss=true;game.test_mode=false
 for i in 3:
  game.begin_run();await settle()
  check(game.screen=="game","Start/restart %d enters combat without confirmation"%i)
  var before=game.run.elapsed;game._process(.016)
  check(game.run.elapsed>before and game.screen=="game","First frame advances without tip input")
 var h=game.battle_hud
 for instrument in [h.health,h.fuel,h.danger,h.modules,h.drones]:
  check(instrument.icon is TextureRect and instrument.icon.texture is AtlasTexture,"Instrument uses generated raster artwork: "+instrument.glyph)
 check(h.fuel.bar.value==0 and not h.fuel.visible,"Zero fuel capacity hides the irrelevant instrument")
 check(h.health.amount.text=="500 / 500" and h.health.bar.value==1,"Initial health uses real maximum")
 check(h.modules.amount.text=="0 / 60" and h.drones.amount.text=="4 / 30","Initial capacities use source limits")
 game.combat.hurt_player(0,125,0);game._process(.016)
 check(is_equal_approx(h.health.bar.value,.75),"Damage refreshes remaining health in the real loop")
 game.player.install_module(game.db.named("Core_FuelTank").id,1,4)
 game.player.fuel=game.player.max_fuel*.5;h.refresh()
 check(is_equal_approx(h.fuel.bar.value,.5) and h.fuel.amount.text.contains("50%"),"Fuel reports half of actual tank capacity")
 var meter=h.modules
 for pair in [[0,60],[60,60],[65,60],[-3,60],[3,0]]:
  meter.capacity(pair[0],pair[1],"无上限")
  check(meter.bar.value>=0 and meter.bar.value<=1,"Capacity fill bounded for "+str(pair))
 check(meter.amount.text=="3 / 无上限" and meter.bar.value==0,"No limit is not represented as a full or dividing-by-zero bar")
 meter.capacity(65,60,"无上限");check(meter.amount.text=="65 / 60" and meter.bar.value==1,"Over-cap numeric count remains truthful")
 for heat in [0.0,1.0,1.65]:
  game.run.heat=heat;h.refresh()
  check(is_equal_approx(h.danger.bar.value,minf(heat,1)) and h.danger.amount.text=="%d%%"%roundi(heat*100),"Cumulative danger "+str(heat))
 game.run.heat=.42;game.run.elapsed=65;h.refresh()
 check(h.timer.text.contains("12:55"),"Countdown remains text with remaining time")
 game.selected_mission=game.db.named("Endless Mission");h.refresh()
 check(h.timer.text.contains("01:05") and h.timer.tooltip_text.contains("已进行"),"Endless shows elapsed text, not a countdown bar")
 game.selected_mission=game.db.named("Survival Mission")
 game.player.install_module(game.db.named("Core_Gun_Cannon").id,2,4)
 var head_count=game.combat.drones.filter(func(d):return d.owner==0).size()
 game.combat.add_drone(1,game.combat.drones[0].data);h.refresh()
 check(h.drones.amount.text.begins_with(str(head_count)+" /"),"Head drone capacity excludes module-owned drones")
 game.run.packs=2;game.run.scraps=37;h.refresh()
 check(h.counters.text.contains("2") and h.counters.text.contains("37"),"Packs and scrap remain numeric text")
 for dimensions in [Vector2i(1440,900),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=dimensions;await settle();game.queue_redraw();await settle()
  var viewport=root.get_visible_rect();var good=true
  var controls=[h.mission,h.health,h.fuel,h.timer,h.danger,h.counters,h.modules,h.drones,h.build_button]
  var area=0.0
  for control in controls:
   if not control.visible:continue
   var rect=control.get_global_rect()
   good=good and viewport.encloses(rect) and rect.end.y<=100
   area+=rect.get_area()
   for child in control.get_children():
    if (child is Label or child is TextureRect) and child.visible:
     good=good and viewport.encloses(child.get_global_rect()) and rect.encloses(child.get_global_rect())
  for left in range(controls.size()):
   for right in range(left+1,controls.size()):
    if controls[left].visible and controls[right].visible:
     good=good and not controls[left].get_global_rect().intersects(controls[right].get_global_rect())
  good=good and area<viewport.get_area()*.06
  var backing_area=0.0
  for rect in h.instrument_backings():
   good=good and viewport.encloses(rect) and rect.end.y<=100
   backing_area+=rect.get_area()
  good=good and backing_area<viewport.get_area()*.03
  good=good and h.build_button.size.y<=44
  good=good and viewport.encloses(h.keys.get_global_rect()) and viewport.encloses(h.radar_label.get_global_rect())
  check(good,"Actual controls stay within 100px edge band, do not overlap and occupy under 6% at "+str(dimensions))
  geometry.append({"window":[dimensions.x,dimensions.y],"passed":good,"occupied_area":area,"fraction":area/viewport.get_area()})
  await shot("%dx%d"%[dimensions.x,dimensions.y])
 for fraction in [1.0,.1,0.0]:
  game.player.parts[0].hp=game.player.parts[0].max_hp*fraction
  game.player.fuel=game.player.max_fuel*fraction
  h.refresh()
  check(is_equal_approx(h.health.bar.value,fraction) and is_equal_approx(h.fuel.bar.value,fraction),"Armor and fuel remain accurate at "+str(fraction))
  check(h.health.warning==(fraction<=.25) and h.fuel.warning==(fraction<=.25),"Low/empty resource warnings at "+str(fraction))
  for count_value in [0,1,30]:
   h.drones.capacity(count_value,30,"∞")
   check(h.drones.get_global_rect().encloses(h.drones.amount.get_global_rect()),"Drone counter fits at "+str(count_value))
  await shot("state-"+str(roundi(fraction*100)))
 root.size=Vector2i(1440,900);await settle()
 game.run.packs=0;game.run.rewards.queue.clear()
 await click_at(h.build_button.get_global_rect().get_center());check(game.screen=="build","E build button remains clickable")
 game.show_game();await settle();check(game.battle_hud!=h and game.battle_hud.modules.amount.text=="2 / 60","Returning rebuilds HUD with current values")
 check(game.db.read_json("videos").size()>0 and not game.db.scene_config.LoadingPanelContorller.tipsList.is_empty(),"Tips data and video resources retained")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={"checks":checks,"geometry":geometry,"captures":captures,"passed":checks.all(func(c):return c.passed)}
 FileAccess.open("res://artifacts/battle-hud-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
