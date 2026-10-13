extends "res://tests/test_centipede_scene.gd"
func settle():
 for i in 4:await process_frame
func offer_fixture(kind:String)->Dictionary:
 for reward in game.db.kind(kind):
  if game.run.can_reward(reward):return reward
 return {}
func pack_with(reward:Dictionary):
 game.run.rewards.enqueue(true);game.run.offers=[reward,reward,reward]
func execute():
 root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
 game.set_process(false);game.save.fresh();game.save.state.settings.skip_boss=true;game.start_run();await settle()
 for r in game.db.kind("PercentBasicReward"):game.save.state.unlocked.append(r.id)
 var module=offer_fixture("BlockReward");var stat=offer_fixture("PercentBasicReward")
 check(not module.is_empty() and not stat.is_empty(),"Use eligible real source reward definitions")
 pack_with(module);var before=game.run.elapsed;game.show_pause();game._process(.1);await settle()
 check(game.screen=="pause" and game.run.elapsed==before,"Rewards do not interrupt an explicit pause")
 game.show_game();game._process(.1);await settle()
 check(game.screen=="rewards" and game.reward_ui.buttons.size()==3,"One earned pack automatically opens three choices")
 for i in 30:game._process(.1)
 check(game.run.elapsed==before,"Combat timer pauses for reward modal")
 await capture("reward-flow-01-choice")
 var token=game.reward_epoch;game.choose_reward(module,token);game.choose_reward(module,token);await settle()
 check(game.run.packs==0 and game.run.opened==1 and game.player.pending.size()==int(module.coresCount),"Duplicate click consumes exactly one reward")
 check(game.screen=="build" and game.build_ui.selected_data.get("kind")=="inventory","Module proceeds directly to selected placement")
 var pending=game.player.pending.size();game.build_ui.drop({"kind":"slot","segment":1,"slot":99},game.build_ui.selected_data)
 check(game.player.pending.size()==pending,"Illegal placement retains module")
 await capture("reward-flow-02-place")
 game.postpone_rewards();await settle();game._process(.1)
 check(game.screen=="game" and game.player.pending.size()==pending,"Postpone installation retains items and resumes combat")
 game.show_build();await settle()
 check(game.screen=="build" and game.reward_flow_active,"E construction resumes deferred installation")
 for i in pending:
  await click_at(game.build_ui.slots[i].get_global_rect().get_center())
 check(game.player.pending.is_empty() and game.screen=="game","Choosing legal slots installs all items and resumes automatically")
 game.show_build();await settle();check(game.screen=="build" and not game.reward_flow_active,"E still opens free construction when no reward is pending")
 game.show_game();await settle()
 for i in 6:game.run.rewards.enqueue(true)
 game.run.offers=[stat,stat,stat];game._process(.1);await settle()
 check(game.screen=="rewards","Six-pack threshold has no automatic build/return loop")
 var offers=game.run.offers.duplicate(true);game.postpone_rewards();await settle()
 for i in 20:game._process(.016)
 check(game.screen=="game" and game.run.packs==6 and game.run.offers==offers,"Postponing preserves six packs and rolled choices without reopening")
 game.show_build();await settle();before=game.run.elapsed
 for i in 6:
  game.run.offers=[stat,stat,stat];game.choose_reward(stat,game.reward_epoch);await settle()
  check(game.run.packs==5-i,"Queue consumes one pack per choice %d"%i)
 check(game.screen=="game" and game.player.pending.is_empty() and game.run.elapsed==before,"Non-entity rewards apply directly and queue resumes only when finished")
 pack_with(module);game._process(.01);await settle();game.postpone_rewards();await settle()
 game.run.rewards.enqueue(true);game._process(.01);await settle()
 check(game.screen=="rewards" and game.run.packs==2,"New pickup wakes a postponed queue")
 # Artificially fill capacity after offer display to exercise stale availability.
 while game.player.parts.size()<61:game.player.append_segment(module.blockCore)
 token=game.reward_epoch;var packs=game.run.packs;game.choose_reward(module,token);await settle()
 check(game.run.packs==packs and game.player.pending.is_empty(),"Full capacity rejects stale selection without consumption")
 game.show_rewards();await settle()
 check(game.reward_ui.buttons.all(func(b):return b.disabled),"No eligible choice is disabled and retained")
 await capture("reward-flow-03-full")
 game.postpone_rewards();await settle();game._process(.01)
 check(game.screen=="game" and game.run.packs==packs,"No-slot path can continue without discarding reward")
 game.show_build();await settle();game.player.parts[0].hp=0;game.choose_reward(module,game.reward_epoch);game._process(.01);await settle()
 check(game.screen=="result" and game.run.packs==packs,"Death closes reward UI and cannot consume a reward")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
 FileAccess.open("res://artifacts/reward-flow-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
