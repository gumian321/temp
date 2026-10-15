extends "res://tests/test_centipede_scene.gd"
## All rating tiers, both playable bodies, exact values, navigation, and native captures.
func settle():
 for i in 4:await process_frame
func press_key(code:int):
 var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await settle()
 e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await settle()
func press_joy(code:int):
 var e=InputEventJoypadButton.new();e.button_index=code;e.pressed=true;Input.parse_input_event(e);await settle()
 e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await settle()
func fixture(grade:String,score:int,meta:int,won:bool,all_rows:bool=true):
 var breakdown={}
 for rating in game.db.stores.RatingDataStore.RatingTypesList:
  breakdown[int(rating.ratingType)]=1234+int(rating.ratingType) if all_rows else 0
 game.run.finished=true;game.run.won=won
 game.run.result={"grade":grade,"score":score,"meta":meta,"won":won,"kills":123,"time":754.0,"breakdown":breakdown}
 game.show_result()
 await settle()
func result_node():return game.panel.get_node_or_null("ResultScreen")
func shot(tag:String):
 if DisplayServer.get_name()=="headless":return
 await create_timer(0.45).timeout
 await RenderingServer.frame_post_draw
 var image=root.get_texture().get_image()
 var path="res://artifacts/result-rank-"+tag+".png"
 check(image!=null and not image.is_empty(),"Native renderer produced "+tag)
 if image==null or image.is_empty():return
 check(image.save_png(path)==OK,"Saved "+tag)
 captures.append({"path":path,"width":image.get_width(),"height":image.get_height(),"window_width":root.size.x,"window_height":root.size.y})
func execute():
 root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle();game.set_process(false)
 game.test_mode=true;game.save.path="user://result-rank-ui-isolated.json";game.save.fresh();game.save.state.settings.skip_boss=true
 var tiers=game.db.stores.RatingDataStore.LetterRatingsList
 check(tiers.size()==17,"All 17 source rating tiers present")
 var total_cases=0
 for character in ["centipede","spider"]:
  game.save.state.selected_character=character;game.start_run();await settle()
  check(game.player.character_id==character,"Actual run body is "+character)
  for won in [false,true]:
   for tier in tiers:
    var grade=str(tier.title);var score=int(tier.scoreValue);var meta=int(tier.metaPoints)
    var before=game.save.state.duplicate(true)
    await fixture(grade,score,meta,won)
    var view=result_node()
    check(view!=null,"Result root exists "+character+" "+grade+" "+str(won))
    if view==null:continue
    check(view.get_meta("grade")==grade,"Original tier retained "+grade)
    check(view.get_node("Score").text==str(score),"Exact score "+str(score))
    check(view.get_node("MetaReward").text=="+"+str(meta),"Exact awarded research "+str(meta))
    check(view.get_node("RunSummary").text.contains("12:34") and view.get_node("RunSummary").text.contains("123"),"Exact time and kills")
    var badge=view.get_node("RankBadge");var symbols=""
    for image in badge.get_children():
     symbols+=str(image.get_meta("glyph",""))
     check(image is TextureRect and image.texture is AtlasTexture and image.texture.atlas!=null,"Generated glyph texture loads "+grade)
     check(Rect2(Vector2.ZERO,badge.size).encloses(Rect2(image.position,image.size)),"Glyph fits rank card "+grade)
    check(symbols==grade,"Generated glyphs preserve full tier "+grade)
    var row_count=0
    for child in view.get_children():
     if str(child.name).begins_with("Breakdown"):
      check(child.get_node("Title").text==child.get_meta("title") and child.get_node("Value").text==str(child.get_meta("value")),"Exact breakdown values")
      row_count+=1
    check(row_count==game.db.stores.RatingDataStore.RatingTypesList.size(),"No nonzero breakdown row dropped")
    check(game.save.state==before,"Rendering never awards currency or mutates save")
    check(visible_text(game.panel).contains(game.db.ui("EXPEDITION COMPLETE" if won else "EXPEDITION ENDED","远征完成" if won else "远征结束")),"Outcome header matches win/loss")
    total_cases+=1
 check(total_cases==68,"Covered 17 tiers × 2 characters × 2 outcomes")
 # Empty, negative breakdown, large totals, and an unchanged saved award on redisplay.
 await fixture("F",0,5,false,false)
 check(not visible_text(result_node()).contains("1235"),"Zero breakdown rows omitted")
 check(result_node().get_node("Score").text=="0","Zero score readable")
 game.run.result.breakdown[1]=-123;game.run.result.score=123456789;game.show_result();await settle()
 check(result_node().get_node("Score").text=="123456789","Large total retained exactly")
 check(result_node().get_node("Breakdown0/Value").text=="-123","Negative source value retained exactly")
 for extent in [Vector2i(1440,900),Vector2i(1280,720),Vector2i(1024,768)]:
  root.size=extent;await settle()
  for won in [true,false]:
   await fixture("SSS+" if won else "D-",250000 if won else 15000,250 if won else 25,won)
   game.run.result.breakdown={9:25000,10:10000,1:180000,3:20000,4:10000,6:5000} if won else {1:10000,3:5000}
   game.show_result();await settle()
   check(Rect2(Vector2.ZERO,Vector2(1440,900)).encloses(result_node().get_rect()),"Result fits logical project canvas "+str(extent))
   await shot(("win" if won else "loss")+"-%dx%d"%[extent.x,extent.y])
 root.size=Vector2i(1440,900);await settle()
 await fixture("A",100000,120,true)
 game.run.result.breakdown={9:25000,10:5000,1:50000,3:10000,4:7500,6:2500}
 game.show_result();await settle();await shot("grade-A-1440x900")
 await fixture("F",0,5,false,false);await shot("grade-F-1440x900")
 # Real input and actions; each reopening must free its previous result root.
 root.size=Vector2i(1440,900);await settle()
 for action in ["BaseButton","EvolveButton","AgainButton"]:
  await fixture("A+",120000,35,true)
  var old=result_node();var button=old.get_node(action)
  button.grab_focus();await settle();check(root.gui_get_focus_owner()==button,"Focusable action "+action)
  await press_key(KEY_ENTER)
  check(game.screen=={"BaseButton":"home","EvolveButton":"lab","AgainButton":"game"}[action],"Keyboard activates "+action)
  check(not is_instance_valid(old),"Old result freed after "+action)
 for i in 3:
  await fixture("B-",70000,25,false);var old=result_node()
  await press_key(KEY_ESCAPE)
  check(game.screen=="home" and not is_instance_valid(old),"Repeated Escape dismisses result "+str(i))
 await fixture("B-",70000,25,false)
 await press_joy(JOY_BUTTON_B)
 check(game.screen=="home","Controller B dismisses result")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={"checks":checks,"captures":captures,"cases":total_cases,"passed":checks.all(func(c):return c.passed)}
 FileAccess.open("res://artifacts/result-rank-ui-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 if DisplayServer.get_name()!="headless":FileAccess.open("res://artifacts/result-rank-ui-native-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report));quit(0 if report.passed else 1)
