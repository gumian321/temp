extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/centipede.gd")
const Save = preload("res://scripts/save_store.gd")
const Battle = preload("res://scripts/combat.gd")
const Run = preload("res://scripts/run_state.gd")
var checks = 0
var failures: Array = []
func check(ok,message):
	checks += 1
	if not ok: failures.append(message); printerr(message)
func _initialize():
	var db = DB.new()
	var save = Save.new(db)
	save.fresh()
	var p = Body.new(db)
	var b = Battle.new(db,p)
	var r = Run.new(db,save,p,b,db.kind("Mission")[0],0)
	check(not r.rewards.level_deck.is_empty(),"source frequency deck populated")
	for i in range(20):
		r.rewards.enqueue(true)
		var offers = r.roll_rewards()
		check(offers.size()==3,"pack %d produces three offers including locked previews"%i)
		var selectable = offers.filter(func(v):return r.can_reward(v))
		check(not selectable.is_empty(),"pack %d has an eligible reward"%i)
		if not selectable.is_empty(): check(r.take_reward(selectable[0]),"pack %d consumes source reward"%i)
		p.pending.clear()
	check(r.packs==0,"reward queue drained")
	r.rewards.enqueue(false,{"rarity":3})
	check(r.rewards.queue[0].rarity<=3,"container rarity preserved or source downgrade")
	var before = r.scraps
	r.rewards.recycle()
	check(r.scraps==before and r.packs==0 and r.recycled_packs.size()==1,"source recycling emits a scrap pack without direct currency credit")
	r.step_recycled_packs(1.3)
	check(r.recycled_packs.is_empty() and not b.loot.is_empty(),"recycled pack scatters physical scraps after flight and shrink")
	var report = {"checks":checks,"passed":checks-failures.size(),"failures":failures,"scope":"Real source reward decks, unlocked eligibility, twenty pack selections, rarity and recycling."}
	FileAccess.open("res://artifacts/reward-test-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(1 if not failures.is_empty() else 0)
