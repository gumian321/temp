extends SceneTree
## Real cleanup-path regression: presentation must never change combat outcomes.
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/grid_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Splatter=preload("res://scripts/enemy_death_splatter.gd")
const Brood=preload("res://scripts/brood_theme.gd")
const Motion=preload("res://scripts/viscous_projectile_motion.gd")
const Run=preload("res://scripts/run_state.gd")
const Save=preload("res://scripts/save_store.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const Wet=preload("res://scripts/viscous_projectiles.gd")
var checks:Array=[]
var db

class PaintProbe extends RefCounted:
	var commands:Array=[]
	var transform_calls=0
	var at=Vector2.ZERO
	var heading=0.0
	func world(point):return point
	func get_viewport_rect():return Rect2(0,0,1440,900)
	func draw_set_transform(point,angle=0.0):
		at=point;heading=angle;transform_calls+=1
	func draw_texture_rect(texture,rect,_tile,color):
		commands.append({"texture":texture,"at":at,"heading":heading,"rect":rect,"color":color})
	func draw_colored_polygon(points,color):
		commands.append({"texture":null,"at":at,"heading":heading,"points":points,"color":color})

func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)

func _initialize():call_deferred("execute")

func fixture():
	var body=Body.new(db)
	for p in body.parts:p.cooldown=1000.0
	var battle=Battle.new(db,body)
	battle.drones.clear()
	return battle

func actor(battle,at:Vector2=Vector2(500,0),kind:String="AISwarmingUnit")->Dictionary:
	var e=battle.spawn(db.pool["250"],at)
	e.hp=20.0;e.max_hp=20.0;e.radius=22.0;e.guns=[];e.components=[]
	e.kind=kind;e.unit={"scrapsCount":0,"containerRarity":2,"packsDropCount":0,"stationRewardPacksList":[]}
	e.movement={"enginePower":0.0,"rotEngineModifier":0.0};e.stop_distance=0.0
	return e

func shot(at:Vector2,damage:float=25.0)->Dictionary:
	var b={"position":at,"previous":at,"origin":at,"velocity":Vector2(600,0),"direction":Vector2.RIGHT,
		"age":0.0,"life":2.0,"radius":4.0,"friendly":true,"fx_family":"cannon",
		"data":{"class":"BasicProjectile"},"damage":damage,"shield_damage":damage,"hit":[],"pierce":1,"chips":{}}
	Motion.initialize(b)
	return b

func tick(battle,dt:float=1.0/60.0):battle.step(dt,Vector2(1000,0),false,false)

func scrap_value(battle)->int:
	var total=0
	for drop in battle.loot:total+=int(drop.get("value",0))
	return total

func check_renderer_budget():
	var renderer=FX.new()
	var render_battle={"death_splatters":[],"effects":[],"special":{"black_holes":[],"mines":[]}}
	var visible_positions:Array=[]
	for i in Splatter.MAX_DETAILED+8:
		# Interleave invisible records throughout the timeline, including the end.
		# They may neither spend detail slots nor change the visible paint order.
		var point=Vector2(400+i*2,300+i)
		visible_positions.append(point)
		var burst=Splatter.make_effect({"kind":"AISwarmingUnit","position":point,"uid":i,"radius":18.0})
		burst.life=burst.fx_duration-0.09;render_battle.death_splatters.append(burst)
		var hidden=Splatter.make_effect({"kind":"AISwarmingUnit","position":Vector2(20000+i,20000),"uid":1000+i,"radius":18.0})
		hidden.life=hidden.fx_duration-0.09;render_battle.death_splatters.append(hidden)
	var snapshot=render_battle.duplicate(true)
	var probe=PaintProbe.new();renderer.paint(probe,render_battle,0.09,1.0)
	var puddles:Array=[];var counts:Array=[];var current=-1
	for command in probe.commands:
		if command.texture==Wet.texture("mucus_splat"):
			puddles.append(command.at);counts.append(0);current+=1
		if current>=0:counts[current]+=1
	check(puddles==visible_positions,"Renderer paints every visible death exactly once, oldest to newest")
	check(counts.size()==visible_positions.size() and counts.slice(0,8).all(func(count):return count==1),"Older deaths retain their mandatory ground stain when detail is exhausted")
	check(counts.filter(func(count):return count>1).size()==Splatter.MAX_DETAILED and counts.slice(8).all(func(count):return count>1),"Only the newest 32 visible deaths receive detailed jets; offscreen deaths consume no slots")
	var detail_probe=PaintProbe.new()
	Splatter.paint(detail_probe,render_battle.death_splatters[0],1.0,true)
	check(probe.commands.size()==visible_positions.size()+Splatter.MAX_DETAILED*(detail_probe.commands.size()-1),"Renderer command count is bounded by one stain per corpse plus the fixed detail budget")
	check(counts[-1]==detail_probe.commands.size() and probe.commands[-1].texture==Wet.texture("goo_bead"),"Newest corpse jets and beads remain above all older stains")
	check(probe.commands.all(func(command):return command.texture!=Wet.texture("egg") and command.texture!=Wet.texture("egg_burst")),"Death renderer uses wet jets and beads without egg-shell or flower-burst textures")
	check(render_battle==snapshot and probe.at==Vector2.ZERO and probe.heading==0.0,"Rendering leaves burst state unchanged and restores the canvas transform")
	var hidden_battle={"death_splatters":render_battle.death_splatters.filter(func(burst):return burst.position.x>10000),"effects":[],"special":{"black_holes":[],"mines":[]}}
	probe=PaintProbe.new();renderer.paint(probe,hidden_battle,0.09,1.0)
	check(probe.commands.is_empty() and probe.transform_calls==0,"Entirely offscreen death batches issue no draw or transform commands")
	# Dense overflow and chronological ordering are presentation-only; no native
	# renderer or frame benchmark is needed for these command-level assertions.

func execute():
	db=DB.new()
	# Multiple hits in one tick still create one corpse, one reward, one burst.
	var battle=fixture();var e=actor(battle)
	e.unit.scrapsCount=7
	battle.hit_enemy(e,shot(e.position-Vector2(30,0),1.0));tick(battle)
	check(battle.death_splatters.is_empty() and battle.kills==0,"Nonlethal hull impact never creates a death burst")
	battle.hit_enemy(e,shot(e.position-Vector2(30,0)))
	battle.hit_enemy(e,shot(e.position-Vector2(30,0)))
	check(battle.death_splatters.is_empty(),"Lethal hit waits for the centralized one-shot cleanup")
	tick(battle)
	check(battle.death_splatters.size()==1 and battle.enemies.is_empty(),"Repeated lethal hits resolve to one burst and remove the corpse")
	check(battle.kills==1 and battle.destruction==20.0 and battle.destroyed.size()==1 and battle.statistics.get("stat_ShipsDestroyed",0)==1,"Death preserves kill, destruction, objective and ship-stat accounting exactly once")
	check(scrap_value(battle)==7,"Organic death retains the source scrap reward value")
	check(not battle.effects.any(func(fx):return fx.kind=="explosion"),"Organic death replaces the generic explosion rather than layering it over the slime")
	var burst_position:Vector2=battle.death_splatters[0].position
	e.position+=Vector2(100,100);tick(battle)
	check(battle.death_splatters.size()==1 and battle.death_splatters[0].position==burst_position,"Death burst is an independent world-space snapshot")
	check(battle.kills==1 and battle.destroyed.size()==1 and scrap_value(battle)==7,"Later ticks cannot award the same corpse twice")
	# Swept projectile collision is tested at coarse, normal and fine updates.
	for dt in [0.1,1.0/60.0,1.0/600.0]:
		battle=fixture();e=actor(battle,Vector2(100,0))
		battle.bullets.append(shot(Vector2.ZERO))
		for frame in int(ceil(0.3/dt)):tick(battle,dt)
		check(battle.kills==1 and battle.hit_count==1 and battle.bullets.is_empty() and battle.death_splatters.size()==1,"Swept lethal projectile creates exactly one death at dt="+str(dt))
	# Splash damage can kill several actors without a direct hit on each.
	battle=fixture();e=actor(battle)
	var neighbor=actor(battle,Vector2(540,0))
	var b=shot(e.position-Vector2(30,0));b.data.projectileEffectArea=2.0
	battle.hit_enemy(e,b);tick(battle)
	check(battle.kills==2 and battle.death_splatters.size()==2 and e.hp<=0 and neighbor.hp<=0,"Area-damage deaths each enter the centralized burst path")
	battle=fixture();e=actor(battle);neighbor=actor(battle,Vector2(540,0))
	b=shot(e.position-Vector2(30,0));b.data.projectilePrefab=45;b.chain_remaining=1
	battle.hit_enemy(e,b);tick(battle)
	check(battle.kills==2 and battle.hit_count==2 and battle.death_splatters.size()==2,"Instant chain jumps produce one burst per distinct killed target")
	# Black holes bypass hit_enemy, while mines and continuous fire reuse it.
	battle=fixture();e=actor(battle)
	battle.special.black_holes.append({"position":e.position,"life":1.0,"radius":80.0,"damage":3000.0,"shield_damage":0.0,"friendly":true,"force":0.0})
	tick(battle)
	check(battle.kills==1 and battle.hit_count==0 and battle.death_splatters.size()==1,"Black-hole tick damage produces a burst without direct-hit callbacks")
	battle=fixture();e=actor(battle)
	battle.special.mines.append({"owner":0,"anchored":false,"position":e.position,"life":1.0,"data":{"mineDamage":{"hullDamage":25.0,"shieldDamage":25.0}},"chips":{}})
	tick(battle)
	check(battle.kills==1 and battle.special.mines.is_empty() and battle.death_splatters.size()==1,"Mine-triggered death produces one burst and consumes the mine")
	battle=fixture();e=actor(battle,Vector2(60,0))
	battle.special.continuous(db.named("Core_Gun_Flame Thrower"),Vector2.ZERO,Vector2.RIGHT,true,{},100.0,0.1)
	tick(battle)
	check(battle.kills==1 and battle.death_splatters.size()==1,"Continuous flame death reaches the same one-shot cleanup")
	battle=fixture();e=actor(battle,Vector2(400,0))
	e.position=battle.player.parts[0].position
	e.components=[{"class":"KamikazeTrigger","explosionArea":1.0,"explosionDamage":{"hullDamage":0.0,"shieldDamage":0.0}}]
	tick(battle)
	check(battle.kills==1 and battle.death_splatters.size()==1,"Kamikaze self-destruction creates a death burst")
	# Multipart bosses: part death and root reward are distinct existing events.
	battle=fixture()
	var boss=actor(battle,Vector2(500,0),"AIBossUnit")
	boss.damageable=false;boss.unit={"bossRating":4321,"aIThreatLevel":4,"rewardPacksList":["boss-pack-a","boss-pack-b"]}
	var part_a=actor(battle,Vector2(500,0),"AIBossPartController")
	var part_b=actor(battle,Vector2(600,0),"AIBossPartController")
	boss.parts=[part_a.uid,part_b.uid]
	part_a.parent=boss.uid;part_b.parent=boss.uid
	part_a.offset=Vector2.ZERO;part_b.offset=Vector2(100,0)
	part_a.unit.scrapsCount=2;part_b.unit.scrapsCount=3
	part_a.hp=0;tick(battle)
	check(battle.kills==1 and battle.boss_kills==0 and battle.death_splatters.size()==1 and boss.hp==20,"Destroying one boss part preserves the root and creates only the part burst")
	battle.bullets.append(shot(part_b.position-Vector2(30,0)));tick(battle)
	check(battle.kills==2 and battle.boss_kills==0 and battle.death_splatters.size()==2 and not battle.entity(boss.uid).is_empty(),"Final part killed during projectile phase preserves existing next-tick root resolution")
	tick(battle)
	check(battle.kills==3 and battle.boss_kills==1 and battle.boss_score==4321 and battle.death_splatters.size()==3 and battle.enemies.is_empty(),"Boss root resolves once after its last part without losing per-part deaths")
	check(battle.destruction==40.0 and scrap_value(battle)==5 and battle.loot.filter(func(drop):return drop.get("pack",false)).size()==2,"Boss part destruction, scrap totals and root reward packs remain unchanged")
	check(battle.statistics.get("stat_BossesKilled",0)==1 and battle.statistics.get("stat_MiniBossKilled",0)==1,"Boss statistics still credit the original threat category once")
	check(battle.death_splatters.filter(func(fx):return fx.boss).size()==1,"Only the boss root uses the larger boss splatter")
	battle=fixture();boss=actor(battle,Vector2(500,0),"AIBossUnit")
	boss.damageable=false;boss.components=[{"class":"AIWarpManager","activateWarping":true,"PartsCountWarp":[1],"warpRadius":10.0}]
	part_a=actor(battle,Vector2(500,0),"AIBossPartController");part_b=actor(battle,Vector2(600,0),"AIBossPartController")
	boss.parts=[part_a.uid,part_b.uid];part_a.parent=boss.uid;part_b.parent=boss.uid
	part_a.hp=0;tick(battle)
	check(boss.warp==0.5 and part_b.warp==0.5 and boss.position.distance_to(battle.player.head)>479.9 and battle.boss_kills==0,"Boss part-loss warp and surviving-part state remain unchanged")
	check(battle.death_splatters.size()==1 and battle.death_splatters[0].position==Vector2(500,0),"Part death splatter stays at the corpse while the surviving boss warps away")
	# All organic runtime kinds use the existing Brood eligibility contract.
	for kind in ["AISwarmingUnit","AIFollowingUnit","AIPatrolUnit","AIStation","AIStationPartController","AIGuardUnitController","AIBossPartController","SpawnerStation","MineController","TraderUnit"]:
		battle=fixture();e=actor(battle,Vector2(500,0),kind);e.hp=0;tick(battle)
		check(Brood.eligible(e) and battle.death_splatters.size()==1,"Organic eligibility creates a burst: "+kind)
	for kind in ["Asteroid","ContainerObject"]:
		battle=fixture();e=actor(battle,Vector2(500,0),kind);e.hp=0;tick(battle)
		check(battle.death_splatters.is_empty() and battle.kills==1 and battle.effects.any(func(fx):return fx.kind=="explosion"),"Nonorganic destruction retains the original explosion: "+kind)
		if kind=="ContainerObject":check(battle.loot.filter(func(drop):return drop.get("pack",false)).size()==1,"Container death retains its reward pack")
	# Range, patrol and map unload are removal, never cosmetic death events.
	battle=fixture();e=actor(battle,Vector2(10000,0));e.unit.isDisableIfFar=true;tick(battle)
	check(battle.enemies.is_empty() and battle.kills==0 and battle.death_splatters.is_empty() and battle.loot.is_empty(),"Distance despawn has no splatter, kill or loot")
	battle=fixture();e=actor(battle,Vector2(10000,0))
	battle.patrols[e.uid]={"members":[e.uid],"position":e.position};tick(battle)
	check(battle.enemies.is_empty() and battle.patrols.is_empty() and battle.kills==0 and battle.death_splatters.is_empty(),"Patrol group despawn has no splatter or kill")
	battle=fixture();e=actor(battle);e.hp=0;e.despawn=true;tick(battle)
	check(battle.death_splatters.is_empty() and battle.kills==1,"A despawn-flagged corpse suppresses presentation without rewriting existing reward semantics")
	battle=fixture()
	var save=Save.new(db);save.path="user://enemy-death-splatter-map-test.json";save.fresh()
	var run=Run.new(db,save,battle.player,battle,db.kind("Mission")[0],0)
	run.map_director.spawn_node(Vector2(123,456),103)
	var old_uids:Array=[]
	for node in run.map_director.nodes.values():old_uids.append_array(node.members)
	battle.player.head=Vector2(50000,50000);run.map_director.update_grid()
	check(not old_uids.is_empty() and old_uids.all(func(uid):return battle.entity(uid).is_empty()) and battle.kills==0 and battle.death_splatters.is_empty(),"Map cell unload does not manufacture death bursts or rewards")
	# Cosmetics must consume neither combat nor loot RNG.
	battle=fixture();e=actor(battle);e.hp=0
	var combat_rng=battle.rng.state;var loot_rng=battle.loot_rng.state
	tick(battle)
	check(battle.rng.state==combat_rng and battle.loot_rng.state==loot_rng,"Zero-loot death presentation consumes neither gameplay random stream")
	battle=fixture();e=actor(battle);e.hp=0;e.unit.scrapsCount=28
	var reference=fixture();actor(reference)
	reference.step_scraps(1.0/60.0);reference.spawn_scraps(e.position,28)
	tick(battle)
	check(battle.loot==reference.loot and battle.rng.state==reference.rng.state and battle.loot_rng.state==reference.loot_rng.state,"Seeded organic death exactly preserves the original scrap payload, scatter and both RNG states")
	# Fatal direction is cosmetic metadata, including damage without projectiles.
	battle=fixture();e=actor(battle)
	b=shot(e.position-Vector2(30,0),1.0);battle.hit_enemy(e,b)
	b=shot(e.position-Vector2(0,30));b.velocity=Vector2.DOWN*600;battle.hit_enemy(e,b)
	tick(battle)
	check(battle.death_splatters[0].direction.is_equal_approx(Vector2.DOWN),"Fatal shot direction updates even while the prior hit's visual cooldown is active")
	battle=fixture();e=actor(battle);e.last_death_direction=Vector2.UP
	b=shot(e.position);b.velocity=Vector2.ZERO;battle.hit_enemy(e,b);tick(battle)
	check(battle.death_splatters[0].direction.is_equal_approx(Vector2.UP),"Zero-speed impact cannot erase the last meaningful death direction")
	battle=fixture();e=actor(battle)
	battle.special.mines.append({"owner":0,"anchored":false,"position":e.position-Vector2(0,10),"life":1.0,"data":{"mineDamage":{"hullDamage":25.0,"shieldDamage":25.0}},"chips":{}})
	tick(battle)
	check(battle.death_splatters[0].direction.is_equal_approx(Vector2.DOWN),"Mine death sprays away from the mine rather than using its placeholder rightward velocity")
	battle=fixture();e=actor(battle)
	battle.special.black_holes.append({"position":e.position-Vector2(0,40),"life":1.0,"radius":80.0,"damage":3000.0,"shield_damage":0.0,"friendly":true,"force":60.0})
	tick(battle)
	check(battle.death_splatters[0].direction.is_equal_approx(Vector2.UP) and e.position==Vector2(500,-1),"Black-hole death points toward the hole while preserving the original pull displacement")
	for stored_direction in [Vector2.ZERO,Vector2(0.001,0)]:
		e={"position":Vector2(3,4),"kind":"AISwarmingUnit","angle":PI/2,"last_death_direction":stored_direction}
		var snapshot=e.duplicate(true);var fx=Splatter.make_effect(e)
		check(fx.direction.is_equal_approx(Vector2.DOWN) and is_equal_approx(fx.direction.length(),1.0) and e==snapshot,"Degenerate stored direction falls back to actor facing without mutating it: "+str(stored_direction))
	# Dense simultaneous kills retain accounting while presentation stays bounded.
	battle=fixture()
	var dense_count=Splatter.MAX_BURSTS+17
	for i in dense_count:
		e=actor(battle,Vector2(1000+i*3,0));e.hp=0
	tick(battle)
	check(battle.kills==dense_count and battle.destroyed.size()==dense_count and battle.destruction==dense_count*20.0,"Overflowing visual budget cannot suppress kills, destruction or objective events")
	check(battle.death_splatters.size()==Splatter.MAX_BURSTS,"Simultaneous death bursts obey the fixed presentation cap")
	check(battle.death_splatters[-1].position==e.position,"Presentation overflow keeps the newest death visible")
	check(battle.death_splatters.all(func(fx):return fx.life>0 and fx.life<=fx.fx_duration and not fx.has("follow") and not fx.has("target")),"Death snapshots have finite lifetime and retain no live actor references")
	tick(battle,2.1)
	check(battle.death_splatters.is_empty(),"All capped death bursts expire under a large update")
	e=actor(battle);e.hp=0;tick(battle)
	check(battle.death_splatters.size()==1 and battle.kills==dense_count+1,"Expired presentation capacity is reusable by subsequent deaths")
	check_renderer_budget()
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"max_bursts":Splatter.MAX_BURSTS,"max_detailed":Splatter.MAX_DETAILED}
	FileAccess.open("res://artifacts/enemy-death-splatter-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
