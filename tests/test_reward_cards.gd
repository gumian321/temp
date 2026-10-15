extends "res://tests/test_centipede_scene.gd"
func settle():
 for i in 5:await process_frame
func shot(tag:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var path="res://artifacts/reward-cards-"+tag+".png"
 check(root.get_texture().get_image().save_png(path)==OK,"Capture "+tag);captures.append(path)
func inspect_layout(tag:String):
 var view=game.reward_ui;var viewport=root.get_visible_rect();var board=view.board.get_global_rect()
 check(viewport.encloses(board),"Panel inside viewport: "+tag)
 check(board.get_center().distance_to(viewport.get_center())<1,"Panel centred: "+tag)
 for i in view.buttons.size():
  var button=view.buttons[i];var face=view.faces[i]
  check(button.get_theme_stylebox("normal") is StyleBoxFlat,"Reward card uses Neon glass skin: "+tag+str(i))
  check(button.get_theme_color("font_color")==load("res://scripts/game_ui.gd").TEXT,"Reward text stays bright: "+tag+str(i))
  check(board.encloses(button.get_global_rect()),"Card inside panel: "+tag+str(i))
  for child in face.get_children():
   check(button.get_global_rect().encloses(child.get_global_rect()),"Card content inside card: "+tag+str(i)+str(child.get_index()))
  check(not view.effect_labels[i].text.is_empty(),"Effect text exists: "+tag+str(i))
 check(board.encloses(view.postpone_button.get_global_rect()) and board.encloses(view.recycle_button.get_global_rect()),"Footer accessible: "+tag)
func execute():
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle();game.set_process(false)
 game.save.fresh();game.save.state.settings.skip_boss=true;game.start_run();game.run.rewards.enqueue(true)
 var selected=[]
 for rarity in [0,1,3]:
  for reward in game.db.kind("BlockReward"):
   if int(reward.rarity)==rarity and not str(reward.rewardDesc).is_empty():selected.append(reward);game.save.state.unlocked.append(reward.id);break
 check(selected.size()==3,"Use real source rewards with three rarity levels")
 game.run.offers=selected.duplicate();game.show_rewards();await settle()
 for dimensions in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  root.size=dimensions;await settle();var tag="%dx%d"%[dimensions.x,dimensions.y];inspect_layout(tag);await shot(tag)
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.content_scale_size=Vector2i(1440,900);root.size=dimensions;await settle();inspect_layout("scaled-"+str(dimensions))
 root.content_scale_size=Vector2i.ZERO
 root.size=Vector2i(1280,720);game.db.language="English";game.show_rewards();await settle();inspect_layout("English");await shot("english")
 # Long real source titles and descriptions remain bounded with full hover detail.
 var all=game.db.kind("BlockReward");all.sort_custom(func(a,b):return game.db.title(a).length()>game.db.title(b).length())
 game.run.offers=all.slice(0,3);game.show_rewards();await settle();inspect_layout("long-titles")
 check(game.reward_ui.buttons.all(func(b):return not b.tooltip_text.is_empty()),"Full effect is available as tooltip")
 game.db.language="Chinese (simplified)";game.run.offers=selected.duplicate();game.show_rewards();await settle()
 var before=game.run.opened;var token=game.reward_epoch
 await click_at(game.reward_ui.buttons[0].get_global_rect().get_center())
 game.choose_reward(selected[0],token);await settle()
 check(game.run.opened==before+1 and game.screen=="build","Redesigned card click enters placement exactly once")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
 FileAccess.open("res://artifacts/reward-cards-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
