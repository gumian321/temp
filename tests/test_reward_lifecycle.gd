extends SceneTree
var game
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:push_error(title)
func settle():
	await process_frame
	await process_frame
func pack(reward):
	game.run.rewards.enqueue(true);game.run.offers=[reward];game.show_rewards()
func execute():
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.fresh();game.start_run();await settle()
	var reward=game.db.kind("BlockReward").filter(func(r):return game.run.can_reward(r))[0]
	pack(reward);game.choose_reward(reward,game.reward_epoch);game.postpone_rewards();await settle()
	check(game.screen=="game" and game.reward_snoozed,"Same-frame postponement cancels queued reward navigation")
	check(game.player.pending.size()==1 and game.run.packs==0,"Postponement retains the already earned module exactly once")
	game.player.pending.clear()
	pack(reward);game.recycle_reward(game.reward_epoch);game.show_menu();await settle()
	check(game.screen=="home","Queued recycle callback cannot reopen gameplay after returning home")
	check(game.run.packs==0,"Cancelled navigation does not undo the completed recycle")
	game.start_run();pack(reward);game.choose_reward(reward,game.reward_epoch);await settle()
	check(game.screen=="build" and game.player.pending.size()==1,"Current reward callback still opens normal placement")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/reward-lifecycle-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));game.cursor_system.shutdown();game.audio_system.shutdown();game.queue_free();await settle()
	quit(0 if report.passed else 1)
