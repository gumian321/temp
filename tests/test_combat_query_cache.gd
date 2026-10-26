extends SceneTree
const Grid=preload("res://scripts/combat_spatial_index.gd")
const Body=preload("res://scripts/chain_centipede.gd")
var checks=[]
func _initialize():call_deferred("execute")
func check(value:bool,message:String):
	checks.append({"name":message,"passed":value})
	if not value:push_error(message)
func oracle(actors:Array,low:Vector2,high:Vector2)->Array:
	var first=Vector2i((low/Grid.CELL).floor());var last=Vector2i((high/Grid.CELL).floor());var result=[]
	for actor in actors:
		var cell=Vector2i((Vector2(actor.position)/Grid.CELL).floor())
		if cell.x>=first.x and cell.x<=last.x and cell.y>=first.y and cell.y<=last.y:result.append(actor)
	return result
func execute():
	var db=preload("res://scripts/source_db.gd").new();var grid=Grid.new();var actors=[]
	var rng=RandomNumberGenerator.new();rng.seed=20261026
	for i in 240:actors.append({"uid":i,"position":Vector2(rng.randf_range(-2000,2000),rng.randf_range(-1500,1500)),"kind":"AISwarmingUnit","radius":18.0,"role":"","guns":[],"hp":100.0,"damageable":true})
	grid.rebuild(actors,db);var matches=true;var copies=true
	for frame in 60:
		for i in 12:
			var entity=actors[(frame*13+i)%actors.size()]
			entity.position+=Vector2(rng.randf_range(-200,200),rng.randf_range(-200,200));grid.moved(entity)
		for sample in 50:
			var at=Vector2(rng.randf_range(-1800,1800),rng.randf_range(-1400,1400));var reach=rng.randf_range(1,650)
			var low=at-Vector2.ONE*reach;var high=at+Vector2.ONE*reach
			var expected=oracle(actors,low,high)
			var first=grid.query(low,high);var second=grid.query(low,high)
			matches=matches and first==expected and second==expected
			first.clear();copies=copies and grid.query(low,high)==expected
	check(matches,"6,000 cached/uncached queries retain brute-force cell membership and source order through negative coordinates and actor movement")
	check(copies,"Returned arrays retain original independent-container semantics")
	check(grid.query_cache.size()<=Grid.MAX_QUERIES,"Candidate query cache is bounded at 128 ranges")
	var low=Vector2(-500,-500);var high=Vector2(500,500)
	var selected=grid.query(low,high)
	if not selected.is_empty():selected[0].hp=0
	check(grid.query(low,high)==oracle(actors,low,high),"Candidate entries retain live HP and actor dictionaries")
	var costs={}
	for cached in [false,true]:
		grid.use_query_cache=cached;var began=Time.get_ticks_usec()
		for query in 2400:
			var at=Vector2((query%12)*80-480,0);grid.query(at-Vector2.ONE*300,at+Vector2.ONE*300)
		costs["cached_ms" if cached else "original_ms"]=(Time.get_ticks_usec()-began)/1000.0
	var player=Body.new(db)
	for reward in db.catalog.values():
		if reward.has("coresList") or reward.has("dronesList"):player.levels[reward.id]=1+(player.levels.size()%3)
	var fields=["DamagePercent","RangePercent","RateOfFirePercent","CoreHealthPercent","ShieldHealthPercent","ShieldRechargeRatePercent","TankCapacityPercent"]
	var cores=[]
	for core in db.catalog.values():
		if core.has("class") and str(core["class"]).ends_with("Core"):cores.append(core.id)
	var bonuses={};player.use_upgrade_cache=false
	for id in cores:
		for field in fields:bonuses[[id,field]]=player.upgrade_bonus(id,field)
	player.use_upgrade_cache=true;player.begin_support_tick();var correct=true
	for repeat in 3:
		for id in cores:
			for field in fields:correct=correct and player.upgrade_bonus(id,field)==bonuses[[id,field]]
	player.end_support_tick()
	check(correct,"Tick-local upgrade cache preserves original summation order for all actual cores and seven upgrade fields")
	player.levels.clear();player.begin_support_tick()
	check(player.upgrade_bonus(db.named("Core_Gun_Gatling").id,"DamagePercent")==0,"New tick immediately observes changed upgrade levels")
	player.end_support_tick()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"query_timing":costs,"upgrade_core_count":cores.size(),"timing_scope":"2,400 repeated candidate queries only, not game FPS."}
	FileAccess.open("res://artifacts/combat-query-cache-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	quit(0 if report.passed else 1)
