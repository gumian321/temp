extends SceneTree
const Index=preload("res://scripts/player_hull_index.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
var checks:Array=[]
class MockBody extends RefCounted:
	var parts:Array=[]
	func collision_radius(i:int)->float:return 40.0 if i==0 else 14.0+float(i%3)
func check(value:bool,message:String):
	checks.append({"passed":value,"name":message})
	if not value:push_error(message)
func _initialize():call_deferred("execute")
func first_hit(player,indices:Array,from:Vector2,to:Vector2)->int:
	for i in indices:
		var part:Dictionary=player.parts[i]
		if part.hp>0 and not part.cloaked and Geometry2D.get_closest_point_to_segment(part.position,from,to).distance_to(part.position)<player.collision_radius(i):return i
	return -1
func signature(battle)->Dictionary:
	return {"hp":battle.player.parts.map(func(p):return [p.hp,p.shield,p.stun]),"bullets":battle.bullets.map(func(b):return [b.position,b.velocity,b.life,b.damage,b.hit]),"rng":battle.rng.state,"kills":battle.kills,"effects":battle.effects.map(func(e):return [e.kind,e.life,e.position])}
func execute():
	var random=RandomNumberGenerator.new();random.seed=251060
	var mock=MockBody.new();var index=Index.new();var correct=true
	for layout in 20:
		mock.parts.clear()
		for i in 61:mock.parts.append({"position":Vector2(random.randf_range(-900,900),random.randf_range(-900,900)),"hp":100 if i%7 else 0,"cloaked":i%9==0})
		index.rebuild(mock)
		for sample in 500:
			var start=Vector2(random.randf_range(-1200,1200),random.randf_range(-1200,1200))
			var finish=start+Vector2.from_angle(random.randf()*TAU)*random.randf_range(0,1800)
			correct=correct and first_hit(mock,range(61),start,finish)==first_hit(mock,index.candidates(start,finish),start,finish)
	check(correct,"10,000 high-speed/negative-coordinate sweeps retain the same first living uncloaked hull")
	var db=preload("res://scripts/source_db.gd").new()
	var chip_cores:Array=db.catalog.values().filter(func(c):return c.has("coreChip") and str(c.get("class","")).ends_with("Core"))
	for character in ["centipede","beetle","spider"]:
		for shielded in [false,true]:
			var pairs:Array=[]
			for legacy in [true,false]:
				var p=Body.new(db);p.configure_character(character)
				for i in 12:
					var id=db.named("Core_Gun_Gatling").id
					if shielded:
						if i==0:id=db.named("Core_Shield").id
						if i==1:id=db.named("Core_Repair").id
						if i==2 and not chip_cores.is_empty():id=chip_cores[0].id
					p.append_segment(id)
				p.motion.reset();p.refresh_positions()
				for part in p.parts:part.hp=1000000;part.max_hp=1000000
				var battle=Battle.new(db,p);battle.use_player_hull_index=not legacy;battle.use_player_equipment_cache=not legacy;p.use_chip_fastpath=not legacy;pairs.append(battle)
			var equal=true
			for frame in 120:
				for battle in pairs:
					if shielded and frame==30:battle.player.parts[3].hp=0
					if shielded and frame==60:battle.player.set_hq_weapon(db.named("Core_Shield").id)
					for i in 4:
						var angle=float(frame*7+i)*2.39996;var direction=Vector2.from_angle(angle)
						battle.fire(db.named("Core_Gun_Gatling"),battle.player.head+direction*160,-direction,false,{},0,true)
					battle.player.step(1.0/60,Vector2.from_angle(frame*.011),false);battle.step(1.0/60,Vector2.RIGHT*500,false)
				equal=equal and signature(pairs[0])==signature(pairs[1])
			check(equal,"Actual "+character+(" shield/chip destruction + HQ replacement" if shielded else " gun-only loadout")+" retains bullet damage, positions, effects and RNG on every tick")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/player-hull-index-dense60.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
