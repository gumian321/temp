extends SceneTree
const Snapshot=preload("res://scripts/shield_presentation.gd")
const Feedback=preload("res://scripts/passive_feedback.gd")
const Health=preload("res://scripts/enemy_health_layer.gd")
var checks:Array=[]

class Database extends RefCounted:
	var calls=0
	var catalog={"shield":{"class":"ShieldCore","maxShieldHealth":100.0,"ShieldRange":4.0},"gun":{"class":"ProjectileCore"}}
	func asset(id)->Dictionary:calls+=1;return catalog.get(id,{})

class Battle extends RefCounted:
	var db=Database.new()
	var enemies:Array=[]

class Game extends Node2D:
	var combat=Battle.new()
	var db=combat.db
	var screen="game"
	var radar_mode=false
	var zoom=1.0
	func world(point:Vector2)->Vector2:return point+Vector2(720,450)

class LivingTrace extends RefCounted:
	var commands:Array=[]
	func add(mode:int,at:Vector2,extent:Vector2,angle:float,state:Color,event:Color=Color(0,0,0,0))->bool:
		commands.append([mode,at,extent,angle,state,event]);return true

func check(passed:bool,label:String):
	checks.append({"passed":passed,"label":label})
	if not passed:push_error(label)

func actor(uid:int,point:Vector2,shield:float=-1,role:String="enemy")->Dictionary:
	var guns:Array=[{"id":"gun"}]
	if shield>=0:guns.append({"id":"shield","shield":shield,"feedback_shield_hit_serial":0})
	return {"uid":uid,"position":point,"kind":"AISwarmingUnit","radius":15.0,"hp":100.0,"max_hp":100.0,"role":role,"stun":0.0,"guns":guns,"warp":0.0}

func _initialize():call_deferred("execute")
func execute():
	root.size=Vector2i(1440,900)
	var game=Game.new();root.add_child(game)
	check(Snapshot.for_canvas(game,game.combat)==null,"standalone painter without main metadata falls back without metadata errors")
	var first=actor(1,Vector2.ZERO,60.0);var second=actor(2,Vector2(20,0),20.0,"patrol")
	var target=actor(3,Vector2(10,40));var offscreen=actor(4,Vector2(4000,0),40.0)
	var friendly=actor(5,Vector2(60,30),90.0,"friendly");var stunned=actor(6,Vector2(-80,0),100.0);stunned.stun=1.0
	var dead=actor(7,Vector2.ZERO,100.0);dead.hp=0.0
	game.combat.enemies=[first,second,target,offscreen,friendly,stunned,dead]
	var snapshot=Snapshot.new();snapshot.use_snapshot=true;game.set_meta(&"shield_presentation",snapshot)
	var legacy=Feedback.new();legacy.living=LivingTrace.new()
	var cached=Feedback.new();cached.living=LivingTrace.new()
	var old_health=Health.new();old_health.game=game
	var new_health=Health.new();new_health.game=game
	for stage in 6:
		if stage==1:
			first.guns[1].shield=0.0;first.guns[1].feedback_shield_hit_serial=1
			offscreen.guns[1].feedback_shield_hit_serial=2
		if stage==2:
			first.guns[1].shield=50.0;first.stun=1.0
			second.guns=[{"id":"gun"}] # Same-frame gun replacement after combat.
		if stage==3:
			first.stun=0.0;second.guns=[{"id":"shield","shield":80.0}]
			game.combat.enemies=[target,second,first,offscreen,friendly,stunned,dead]
		if stage==4:first.hp=0.0
		if stage==5:game.combat.enemies=[target]
		legacy.clock=10.0+stage*.1;cached.clock=legacy.clock
		legacy.living.commands.clear();cached.living.commands.clear()
		legacy.paint_enemy_shields(game,game.combat,1.0);old_health.rebuild()
		snapshot.prepare(game.combat);var prepared_calls=game.db.calls;game.db.calls=0
		cached.paint_enemy_shields(game,game.combat,1.0,snapshot.sources);new_health.rebuild(true)
		check(game.db.calls==0,"stage %d reuses prepared sources without any catalog rescans"%stage)
		check(legacy.living.commands==cached.living.commands,"stage %d retains exact ordered shield instance commands"%stage)
		check(legacy.enemy_shield_states==cached.enemy_shield_states,"stage %d retains offscreen hit/break/recharge histories"%stage)
		check(old_health.bars==new_health.bars and old_health.shield_sources==new_health.shield_sources,"stage %d retains exact HP/shield fractions and first-provider order"%stage)
		if stage<5:check(prepared_calls>0,"stage %d exercises real source scanning"%stage)
		if stage==0:check(snapshot.sources.map(func(s):return [s.enemy.uid,s.index])==[[1,1],[2,1],[4,1],[5,1],[6,1]],"live source order includes stunned/offscreen providers and excludes dead providers")
	# Manual rebuild remains immediate even after this frame has a valid cache.
	game.combat.enemies=[first,target];first.hp=100.0;first.guns=[{"id":"shield","shield":70.0}];snapshot.prepare(game.combat)
	first.guns=[{"id":"gun"}];new_health.rebuild()
	check(new_health.shield_sources.is_empty(),"manual same-frame rebuild observes a debug gun replacement without stale cache")
	snapshot.use_snapshot=false;game.db.calls=0;new_health.rebuild(true)
	check(game.db.calls>0,"legacy flag falls back to original live scanner")
	check(snapshot.current(null).is_empty(),"clearing a missing combat releases prior frame source references")
	old_health.free();new_health.free();game.free()
	var passed=checks.all(func(item):return item.passed)
	print(JSON.stringify({"suite":"shield_presentation","passed":passed,"checks":checks,"scope":"Exact source order, overlay instance commands and histories, health fractions, same-frame gun replacement, stun, death and zero-shield scene; no simulation updates."}))
	quit(0 if passed else 1)
