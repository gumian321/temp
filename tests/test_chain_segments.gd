extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Run=preload("res://scripts/run_state.gd")
const Save=preload("res://scripts/save_store.gd")
var checks:Array=[]
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func _initialize():call_deferred("execute")
func execute():
	var db=DB.new()
	var body=Body.new(db)
	check(body.parts.size()==1 and body.segment_count()==0 and body.body_poses.size()==1,"A fresh centipede has only its head and zero body segments")
	var names=["Core_Gun_Gatling","Core_Gun_Cannon","Core_Gun_Shotgun","Core_Gun_Tesla"]
	for name in names:body.append_segment(db.named(name).id)
	check(body.segment_count()==4 and body.parts.size()==5,"Each new element creates exactly one occupied segment")
	var cannon:Dictionary=body.parts[body.part_at(2)]
	var moved:Dictionary=body.parts[body.part_at(4)]
	var owner=body.parts.find(moved)
	body.actions.move=0;body.actions.swap=0
	check(body.move_to_mount(owner,1) and body.parts.find(moved)==owner and moved.segment==1,"Dragging reorders the chain freely while preserving combat owner indices")
	check(body.parts[body.part_at(3)]==cannon,"Reordering preserves every element and its relative order")
	for frame in range(120):body.step(1.0/60,Vector2.RIGHT if frame<60 else Vector2.UP,false)
	var linked=true
	for segment in range(1,body.segment_count()+1):
		linked=linked and absf(Vector2(body.segment_pose(segment).point).distance_to(body.segment_pose(segment-1).point)-58)<0.001
	check(linked,"All reordered segments remain attached through turns")
	var battle=Battle.new(db,body)
	var dead_index=body.part_at(2)
	var next:Dictionary=body.parts[body.part_at(3)]
	var tail:Dictionary=body.parts[body.part_at(4)]
	var next_hp=float(next.hp)
	battle.hurt_player(dead_index,100000,100000)
	battle.step(0.01,body.head+Vector2.RIGHT*600,false)
	check(body.segment_count()==3 and body.parts.size()==4,"A destroyed middle segment is removed without destroying the tail")
	check(next.segment==2 and tail.segment==3 and next.hp==next_hp,"The following segments fill the gap and retain their independent health")
	check(body.motion.centers.size()==3 and body.body_poses.size()==4,"The shortened body drops the old tail solver state")
	while body.parts.size()>1:
		battle.hurt_player(1,100000,100000);battle.step(0.01,Vector2.RIGHT*600,false)
	check(body.segment_count()==0 and body.parts[0].hp>0,"Losing all body segments leaves a living head")
	body.append_segment(db.named(names[0]).id)
	check(body.segment_count()==1 and body.body_poses.size()==2,"A head-only survivor can grow a new first segment")
	var save=Save.new(db);save.fresh()
	body=Body.new(db);battle=Battle.new(db,body)
	var run=Run.new(db,save,body,battle,db.named("Endless Mission"),0)
	var block:Dictionary={}
	for reward in db.kind("BlockReward"):
		if save.available(reward.id):block=reward.duplicate();break
	block.coresCount=3;run.offers=[block];run.packs=1
	check(run.take_reward(block) and body.pending.size()==1 and body.segment_count()==0,"Even a source multi-element reward now grants one element, awaiting placement")
	check(body.install_module(body.pending[0],1) and body.segment_count()==1,"Placing that reward grows exactly one body segment")
	body.pending.clear()
	var stat=db.kind("PercentBasicReward")[0]
	if not save.available(stat.id):save.state.unlocked.append(stat.id)
	run.offers=[stat];run.packs=1
	var previous=body.segment_count()
	check(run.take_reward(stat) and body.segment_count()==previous and body.pending.is_empty(),"A stat upgrade applies directly without growing a segment")
	while body.segment_count()<60:body.append_segment(db.named(names[0]).id)
	check(not body.append_segment(db.named(names[0]).id) and body.segment_count()==60,"The chain enforces the existing 60-element capacity")
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false)
	check(game.screen=="home" and game.panel.get_child_count()>0,"Startup opens the menu directly without commercial loading pages")
	game.save.state.settings.skip_boss=true;game.start_run();game.show_build_ui();await process_frame
	check(game.player.segment_count()==0 and game.build_ui.slots.is_empty() and game.build_ui.insert_targets.size()==1,"The head-only assembly screen has one growth target and no nine-slot grid")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in range(12):OS.delay_msec(10);await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/chain-segments-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
