extends "res://tests/test_centipede_scene.gd"
func settle():
 for i in 4:await process_frame
func shot(tag:String):
 game.queue_redraw();await settle()
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var path="res://artifacts/passive-feedback-"+tag+".png"
 check(root.get_texture().get_image().save_png(path)==OK,"Native capture "+tag);captures.append(path)
func acquire(reward:Dictionary):
 game.save.state.unlocked.append(reward.id);game.run.rewards.enqueue(true);game.run.offers=[reward]
 check(game.run.take_reward(reward),"Acquire "+reward.name)
 game.passive_fx.tick(game,0)
func execute():
 root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle();game.set_process(false)
 game.save.fresh();game.save.state.settings.skip_boss=true;game.start_run()
 var p=game.player
 for name in ["Core_Gun_Gatling","Core_Chip_Mammoth","Core_Shield","Core_Repair","Core_Gun_Cannon","Core_Clocking","Core_FuelTank"]:
  check(p.append_segment(game.db.named(name).id),"Install "+name)
 game.camera=p.head+Vector2(-170,0);game.zoom=1.3
 game.passive_fx.tick(game,0);game.passive_fx.notices.clear();p.step_feedback(3)
 var charge=game.db.named("Reward_Count_WallCores_2")
 if charge.is_empty():
  check(false,"Required named charge fixture exists");quit(1);return
 acquire(charge);check(not p.parts[1].wall and p.actions.wall==2,"Reward grants charge without phantom armor")
 await shot("charge-pending")
 game.passive_fx.notices.clear()
 check(p.reinforce(1),"Actual reinforce action")
 game.passive_fx.tick(game,0)
 var reinforced_uid=p.parts[1].feedback_uid
 var cloak_before=p.parts[5].get("cloaked",false)
 p.parts[5].hp-=20;game.combat.step(.1,Vector2.RIGHT,false,false)
 check(p.parts[5].feedback_pulses.has("healed"),"Repair stitches follow healed target")
 check(p.parts[5].get("cloaked",false),"Cloak uses actual coverage")
 p.pulse_chip_sources(1)
 check(p.parts[2].feedback_pulses.has("chip_trigger"),"Chip trigger belongs to source")
 check(p.passive_state(2).chip_links.has(1),"Chip link targets actual compatible neighbor")
 await shot("active-supports")
 p.step_feedback(3);game.combat.hurt_player(3,50,99999)
 check(p.parts[3].shield_broken and p.parts[3].feedback_pulses.has("shield_break"),"Actual shield break visible")
 await shot("shield-break")
 game.combat.step(p.parts[3].shield_delay+.01,Vector2.RIGHT,false,false)
 check(p.parts[3].shield>0 and p.parts[3].feedback_pulses.has("shield_recharge"),"Actual shield recovery visible")
 await shot("shield-recharge")
 var shield_upgrade=game.db.kind("ShieldLevelUpReward")[0]
 acquire(shield_upgrade);check(p.passive_state(3).upgrades.has(shield_upgrade.id),"Upgrade mark stays on matching module")
 await shot("upgrade-applied")
 var dormant=game.db.kind("TurretLevelUpReward").filter(func(r):return p.reward_feedback(r).status=="dormant")[0]
 game.passive_fx.notices.clear();acquire(dormant)
 check(game.passive_fx.detail.text.contains("储备"),"Dormant upgrade clearly stored")
 await shot("dormant-upgrade")
 var curse=game.db.kind("CrusedReward")[0]
 game.passive_fx.notices.clear();acquire(curse)
 check(game.passive_fx.detail.text.contains("+") and game.passive_fx.detail.text.contains("-"),"Curse shows benefit and cost together")
 check(game.passive_fx.stat_readout.visible,"Global stat ledger visible")
 await shot("curse-stats")
 var before=game.passive_fx.seen_events
 game.passive_fx.tick(game,0);check(game.passive_fx.seen_events==before,"Acquisition consumed exactly once")
 game.screen="pause";var time=game.passive_fx.clock;var left=game.passive_fx.notices[0].left
 game.passive_fx.tick(game,2);check(game.passive_fx.clock==time and game.passive_fx.notices[0].left==left,"Pause freezes visual timers")
 game.screen="game";game.passive_fx.tick(game,.1);check(game.passive_fx.seen_events==before,"Resume does not replay acquisition")
 p.move_piece_to_segment(1,5);check(p.parts[1].feedback_uid==reinforced_uid and p.passive_state(1).reinforced,"Armor follows identity after reorder")
 p.parts[1].hp=0;check(not p.passive_state(1).alive,"Dead module has no passive overlay")
 p.step_feedback(5);check(p.parts.all(func(part):return part.feedback_pulses.is_empty()),"All transient triggers expire")
 game.start_run();check(game.passive_fx.notices.is_empty() and game.passive_fx.seen_events==0,"Restart clears notice and renderer state")
 game.screen="build"
 check(game.player.append_segment(game.db.named("Core_Gun_Gatling").id),"Install inside direct assembly")
 game.passive_fx.tick(game,0)
 check(game.passive_fx.notices.is_empty() and not game.passive_fx.card.visible,"Assembly install toast cannot cover the inventory tray")
 check(game.player.parts[1].feedback_pulses.has("installed"),"Assembly retains local installed-segment feedback")
 check(game.player.append_segment(game.db.named("Core_Shield").id),"Two unarmored segments make the two-charge reward eligible")
 acquire(charge)
 check(game.passive_fx.card.visible and game.passive_fx.notices[0].event.kind=="reward","Assembly still shows reward notifications")
 game.passive_fx.notices.clear();game.screen="game"
 check(game.player.append_segment(game.db.named("Core_Gun_Cannon").id),"Install during combat")
 game.passive_fx.tick(game,0)
 check(game.passive_fx.card.visible and game.passive_fx.notices[0].event.kind=="installed","Combat installation notification remains visible")
 game.screen="build";game.passive_fx.tick(game,0)
 check(game.passive_fx.notices.is_empty() and not game.passive_fx.card.visible,"Entering assembly removes a queued install toast")
 game.screen="game"
 var view=load("res://scripts/reward_choice.gd").new();view.game=game
 var classes={};var mapped=0;var added=0
 for reward in game.db.catalog.values():
  if reward.get("class","") not in load("res://scripts/reward_feedback_state.gd").CLASSES:continue
  check(not view.effect_text(reward).strip_edges().is_empty(),"Truthful text mapping "+reward.name);classes[reward["class"]]=true;mapped+=1
  if reward.get("project_added",false):added+=1
 check(mapped-added==129 and classes.size()==12,"Complete source reward class mapping, plus project-added mutations")
 view.free()
 check(game.passive_fx.textures.size()==6,"Six generated overlays cached")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
 FileAccess.open("res://artifacts/passive-visual-feedback-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
