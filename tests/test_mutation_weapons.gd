extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Store=preload("res://scripts/save_store.gd")
const Art=preload("res://scripts/mutation_weapon_art.gd")
var checks:Array=[]
var db
class Wall extends RefCounted:
	var enabled=true
	func dig():pass
	func wall_hit(start:Vector2,finish:Vector2,radius:float=0)->Dictionary:
		if start.x<80-radius and finish.x>=80-radius:return {"position":Vector2(80-radius,finish.y),"normal":Vector2.LEFT}
		return {}
	func ray_clear(start:Vector2,finish:Vector2)->bool:return (start.x<80)==(finish.x<80)
	func move(start:Vector2,finish:Vector2,radius:float)->Vector2:return Vector2(minf(finish.x,80-radius),finish.y) if start.x<80 else finish
func check(value:bool,title:String):
	checks.append({"name":title,"passed":value})
	if not value:printerr("FAIL: ",title)
func _initialize():call_deferred("execute")
func fixture()->Dictionary:
	var player=Body.new(db);var battle=Battle.new(db,player);battle.drones.clear()
	var enemy=battle.spawn(db.pool["250"],Vector2(120,0));enemy.hp=100000.0;enemy.max_hp=enemy.hp;enemy.guns=[];enemy.mission_controlled=true
	return {"player":player,"battle":battle,"enemy":enemy,"system":battle.mutation_weapons}
func advance(system,seconds:float):
	for i in roundi(seconds*120):system.step(1.0/120)
func shoot(f:Dictionary,key:String,source:String=""):
	f.battle.fire(db.asset("expanded_"+key+"_core"),Vector2.ZERO,Vector2.RIGHT,true,{},0,false,0,1,source)
func execute():
	db=DB.new()
	var store=Store.new(db,"user://mutation-weapons.json",false);store.state.meta=10000
	for key in ["toxin","boneblade","parasite"]:
		var core=db.asset("expanded_"+key+"_core")
		check(not core.is_empty() and db.armament_variant(core)==key and not db.armament_description(core).is_empty(),"Mounted/reward identity resolves for "+key)
		for cell in 4:
			var texture=Art.texture(key,cell)
			check(texture!=null and texture.get_width()>10 and texture.atlas.get_image().detect_alpha()!=Image.ALPHA_NONE,"Generated transparent art loads: "+key+" cell "+str(cell))
		var node=db.research.filter(func(n):return n.nodeRewardsList[0]=="expanded_"+key+"_reward")[0]
		check(not store.unlock_research(node,1),"The head version requires its earlier body-weapon evolution: "+key)
		check(store.unlock_research(node,0),"New weapon can be researched from its initial weapon prerequisite: "+key)
		check(store.available(node.nodeRewardsList[0]),"Research adds the new weapon to the available reward pool: "+key)
	var toxin=fixture();shoot(toxin,"toxin");advance(toxin.system,.5)
	check(toxin.system.pools.size()==1 and toxin.system.shots.is_empty(),"One venom impact creates exactly one persistent pool")
	var after_impact=float(toxin.enemy.hp)
	advance(toxin.system,.6)
	check(toxin.enemy.hp<after_impact and toxin.system.poisoned.has(toxin.enemy.uid),"Venom pools apply real periodic poison damage")
	var poison_damage=float(toxin.system.poisoned[toxin.enemy.uid].damage)
	shoot(toxin,"toxin");advance(toxin.system,.4)
	check(toxin.system.pools.size()==2 and is_equal_approx(float(toxin.system.poisoned[toxin.enemy.uid].damage),poison_damage),"Overlapping poison refreshes without doubling damage")
	toxin.enemy.position=Vector2(1000,0);var outside=float(toxin.enemy.hp)
	advance(toxin.system,.5);check(toxin.enemy.hp<outside,"Poison persists briefly after leaving a pool")
	advance(toxin.system,5)
	check(toxin.system.pools.is_empty() and toxin.system.poisoned.is_empty(),"Expired pools and poison status are cleaned up")
	var blade=fixture();shoot(blade,"boneblade");advance(blade.system,.35)
	check(is_equal_approx(100000.0-float(blade.enemy.hp),18.0),"Spinning blade hits a target once on the outbound path")
	advance(blade.system,1.6)
	check(is_equal_approx(100000.0-float(blade.enemy.hp),36.0) and blade.system.shots.is_empty(),"The curved return hits once again and is caught at the origin")
	var far_blade=fixture();far_blade.enemy.position=Vector2(420,0)
	shoot(far_blade,"boneblade");advance(far_blade.system,.7)
	check(far_blade.enemy.hp<100000,"The blade reaches targets near the advertised outer targeting range before turning")
	var ranged_blade=fixture();ranged_blade.enemy.position=Vector2(620,0);ranged_blade.player.stats["3"]=.5
	shoot(ranged_blade,"boneblade");advance(ranged_blade.system,1.1)
	check(ranged_blade.enemy.hp<100000,"Range bonuses extend the blade's actual outbound trajectory")
	var wall=fixture();wall.battle.terrain=Wall.new();wall.enemy.position=Vector2(150,0)
	shoot(wall,"boneblade");advance(wall.system,1.6)
	check(wall.enemy.hp==100000,"Returning blades cannot hit through an intervening cave wall")
	var owner=fixture()
	owner.player.add_piece(db.asset("expanded_boneblade_core").id,owner.player.next_segment_cell())
	owner.player.add_piece(db.asset("expanded_boneblade_core").id,owner.player.next_segment_cell())
	shoot(owner,"boneblade","player:2")
	var uid=int(owner.system.shots[0].owner_uid);owner.player.remove_parts([1])
	check(int(owner.player.parts[1].feedback_uid)==uid and owner.system.source_anchor(owner.system.shots[0]).position==owner.player.weapon_origin(1),"A returning blade follows its organ identity after another segment is removed")
	owner.player.remove_parts([1]);check(owner.system.source_anchor(owner.system.shots[0]).is_empty(),"A destroyed firing organ cannot redirect its blade into a different segment")
	var parasite=fixture();shoot(parasite,"parasite");advance(parasite.system,.4)
	check(parasite.system.larvae.size()==2,"A parasite impact hatches two actual larval entities")
	var hatched_hp=float(parasite.enemy.hp);advance(parasite.system,1.5)
	check(parasite.enemy.hp<hatched_hp and parasite.system.larvae.any(func(larva):return larva.target==parasite.enemy.uid),"Larvae acquire a target, crawl and deal melee damage")
	advance(parasite.system,5);check(parasite.system.larvae.is_empty(),"Temporary larvae expire and release their capacity")
	var miss=fixture();miss.enemy.position=Vector2(3000,0);shoot(miss,"parasite");advance(miss.system,2)
	check(miss.system.larvae.is_empty(),"A missed egg does not hatch at arbitrary range expiry")
	var swarm=fixture()
	for organ in 5:
		swarm.player.add_piece(db.asset("expanded_parasite_core").id,swarm.player.next_segment_cell())
		for shot in 6:shoot(swarm,"parasite","player:"+str(organ+1))
	advance(swarm.system,.5)
	check(swarm.system.larvae.size()==24,"Massed brood organs obey the global larva limit")
	check(swarm.system.larvae.all(func(larva):return swarm.system.larvae.filter(func(other):return other.owner_uid==larva.owner_uid).size()<=6),"Each brood organ obeys its independent larva limit")
	var upgraded=fixture();var core=db.asset("expanded_toxin_core")
	upgraded.player.add_piece(core.id,upgraded.player.next_segment_cell());upgraded.player.levels["expanded_toxin_upgrade"]=1
	upgraded.player.parts[1].fusion_level=2
	upgraded.battle.fire(core,Vector2.ZERO,Vector2.RIGHT,true,{},upgraded.player.attack_boost(1,core))
	check(float(upgraded.system.shots[0].damage)>7.0*2.2,"Research upgrades and fusion scale actual new-weapon damage")
	var loaded=Store.new(db,store.path)
	check(["toxin","boneblade","parasite"].all(func(key):return loaded.available("expanded_"+key+"_reward")),"New weapon unlocks survive an ordinary save reload")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/mutation-weapons-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
