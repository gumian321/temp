extends "res://tests/test_centipede_scene.gd"
func settle():
 for i in 4:await process_frame
func shot(tag:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var path="res://artifacts/reward-progress-"+tag+".png"
 check(root.get_texture().get_image().save_png(path)==OK,"Capture "+tag);captures.append(path)
func execute():
 root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle();game.set_process(false)
 game.save.fresh();game.save.state.settings.skip_boss=true;game.start_run()
 var upgrades=game.db.kind("TurretLevelUpReward").slice(0,3)
 for r in upgrades:game.save.state.unlocked.append(r.id)
 var cap=int(game.db.stores.PlayerDataStore.get("levelUpsAllowed",3))
 game.player.levels[upgrades[1].id]=cap-1;game.player.levels[upgrades[2].id]=cap
 game.run.rewards.enqueue(true);game.run.offers=upgrades;game.show_rewards();await settle()
 check(game.reward_ui.faces[2].get_child(game.reward_ui.faces[2].get_child_count()-1).get_child(0).text=="已满级","Capped card explicitly says max level")
 check(game.reward_ui.progress_labels.size()==3,"Every evolution card has bottom-right progress")
 check(game.reward_ui.progress_labels[0].text=="0/%d"%cap,"Zero acquired level truthful")
 check(game.reward_ui.progress_labels[1].text=="%d/%d"%[cap-1,cap],"Current level uses actual cap")
 check(game.reward_ui.progress_labels[2].text=="%d/%d"%[cap,cap] and game.reward_ui.buttons[2].disabled,"Capped level displayed and unavailable")
 for i in 3:
  check(game.reward_ui.buttons[i].get_global_rect().encloses(game.reward_ui.progress_labels[i].get_global_rect()),"Badge stays inside card %d"%i)
 await shot("levels")
 var selected=upgrades[1];check(game.run.take_reward(selected),"Acquire next real upgrade")
 check(game.reward_ui.progress_info(selected).text=="%d/%d"%[cap,cap],"Badge source reflects selection immediately")
 game.run.rewards.enqueue(true)
 var charge=game.db.kind("CountBasicReward").filter(func(r):return r.rewardType==21)[0]
 var module=game.db.kind("BlockReward")[0];var stat=game.db.kind("PercentBasicReward")[0]
 for r in [charge,module,stat]:game.save.state.unlocked.append(r.id)
 game.player.actions.wall=7;game.player.change_stat(int(stat.rewardType),.2)
 game.run.offers=[charge,module,stat];game.show_rewards();await settle()
 check(game.reward_ui.progress_labels[0].text.contains("7") and not game.reward_ui.progress_labels[0].text.contains("/"),"Uncapped charge shows stored quantity without invented level")
 check(game.reward_ui.progress_labels[1].text.contains("槽位") and game.reward_ui.progress_labels[1].text.contains("60"),"Body counter clearly marked slots")
 check(game.reward_ui.progress_labels[2].text.contains("+20%"),"Stat counter shows actual accumulated attribute")
 check(game.reward_ui.reward_art(stat)!=game.db.reward_sprite(stat),"Stat art uses generated themed icon")
 check(not game.reward_ui.reward_title(stat).is_empty(),"Stat card has meaningful title")
 for cursed in game.db.kind("CrusedReward"):check(game.reward_ui.reward_art(cursed)!=null,"Curse uses generated evolution icon")
 await shot("nonlevels")
 game.db.language="English";game.show_rewards();await settle()
 for i in 3:check(game.reward_ui.buttons[i].get_global_rect().encloses(game.reward_ui.progress_labels[i].get_global_rect()),"English badge inside card %d"%i)
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
 FileAccess.open("res://artifacts/reward-progress-badges-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
