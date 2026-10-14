extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
var checks:Array=[]
var db
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func actor(b,at:Vector2):
	var e=b.spawn(db.pool["250"],at)
	e.guns=[];e.mission_controlled=true;e.hp=100000.0;e.max_hp=e.hp;e.warp=0.0
	return e
func flame_case(hq:bool,level:int):
	var p=Body.new(db)
	var core=db.named("Core_Gun_Flame Thrower")
	var reward=db.named("Reward_LevelUP_Gun_FlameThrower")
	# There is no stock HQ flame reward: exercise the shared HQ dispatch with
	# the real continuous core, without modifying catalog IDs or reward lists.
	var index=0 if hq else 1
	if hq:p.hq_weapon=core.id
	else:p.append_segment(core.id);p.parts[0].cooldown=999.0
	p.levels[reward.id]=level
	p.stats={"14":0.4,"15":0.2,"17":0.3,"3":0.1}
	var b=Battle.new(db,p)
	var origin=p.weapon_origin(index)
	var reach=db.range_units(core.turretRange)*48*(1+(0.3 if hq else 0.1)+0.05*level)
	var e=actor(b,origin+Vector2.RIGHT*(reach-1.0))
	var beyond=actor(b,origin+Vector2.RIGHT*(reach+1.0))
	var rng_before=b.rng.state
	b.step(0.01,origin+Vector2.RIGHT*1000,false)
	var prefix=("HQ" if hq else "body")+" flame level "+str(level)
	check(is_equal_approx(e.max_hp-e.hp,100*(1+(0.4 if hq else 0.2)+0.25*level)*0.01),prefix+" uses matching damage stat and DamagePercent")
	check(beyond.hp==beyond.max_hp,prefix+" stops at upgraded range")
	var flames=b.effects.filter(func(f):return f.kind=="flame" and f.get("owner","")=="player:"+str(index))
	check(flames.size()==1 and is_equal_approx(flames[0].radius,reach),prefix+" cone uses matching range stat and RangePercent")
	check(b.rng.state==rng_before,prefix+" does not consume gameplay RNG")
	var shield=db.kind("ShieldCore")[0]
	e.guns=[{"id":shield.id,"shield":10000.0,"shield_delay":100.0,"angle":0.0,"cooldown":0.0}]
	b.step(0.01,origin+Vector2.RIGHT*1000,false)
	check(is_equal_approx(10000.0-e.guns[0].shield,100*(1+(0.4 if hq else 0.2)+0.25*level)*0.01),prefix+" applies DamagePercent and matching stat to shield damage")
func mine_case(name:String,reward_name:String,level:int):
	var p=Body.new(db)
	var core=db.named(name)
	var reward=db.named(reward_name)
	p.append_segment(core.id);p.velocity=Vector2.RIGHT*10
	p.levels[reward.id]=level
	var b=Battle.new(db,p)
	b.rng.seed=9876
	var expected_rng=RandomNumberGenerator.new();expected_rng.state=b.rng.state
	var count=1 if name=="Core_MinesField" else int(core.minesCountPerSpawn)
	if name=="Core_MinesField":expected_rng.randi_range(0,int(float(core.maxMinesCount)*(1+float(reward.maxMinesCountPercent)*level))-1)
	b.special.step(0.01)
	var base=1.0/maxf(0.05,float(core.minesRechargeRate)) if name=="Core_MinesField" else float(core.minesSpawnRate)
	var interval=maxf(0.05,base*(1+float(reward.minesRechargeRatePercent)*level))
	check(is_equal_approx(p.parts[1].cooldown,interval),name+" level "+str(level)+" interval follows source negative percentage")
	check(p.parts[1].cooldown>=0.05,name+" cooldown remains nonnegative")
	check(b.special.mines.size()==count,name+" spawn count unchanged")
	check(b.rng.state==expected_rng.state,name+" spawn consumes only its slot selection RNG")
	if name=="Core_MinesField":
		var cap=int(float(core.maxMinesCount)*(1+float(reward.maxMinesCountPercent)*level))
		for i in range(cap+3):p.parts[1].cooldown=0;b.special.step(0)
		check(b.special.mines.size()==cap,name+" level "+str(level)+" respects upgraded cap")
func _initialize():call_deferred("execute")
func execute():
	db=DB.new()
	for hq in [false,true]:
		for level in range(3):flame_case(hq,level)
	for level in [0,1,2,20]:
		mine_case("Core_MinesField","Reward_LevelUP_MineField",level)
		mine_case("Core_MineSpawner","Reward_LevelUP_MineSpawner",level)
	var p=Body.new(db);var b=Battle.new(db,p)
	var flame=db.named("Core_Gun_Flame Thrower")
	var e=actor(b,Vector2(20,0));var before=b.rng.state
	b.special.continuous(flame,Vector2.ZERO,Vector2.RIGHT,true,{},-2,0.01,"test",-2)
	check(e.hp==e.max_hp and b.effects[-1].radius==0,"Extreme negative continuous modifiers cannot heal or reverse the cone")
	check(b.rng.state==before,"Direct continuous modifiers consume no gameplay RNG")
	b.effects.clear()
	b.special.continuous(flame,Vector2.ZERO,Vector2.RIGHT,true,{},0,0.01,"test")
	check(is_equal_approx(b.effects[-1].radius,db.range_units(flame.turretRange)*48),"Existing enemy/allied continuous callers retain unmodified base range")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/passive-upgrade-effects-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
