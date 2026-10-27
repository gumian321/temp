extends SceneTree
const Feedback=preload("res://scripts/passive_feedback.gd")
const SourceDB=preload("res://scripts/source_db.gd")
const Player=preload("res://scripts/chain_centipede.gd")
var checks:Array=[]

class LivingTrace extends RefCounted:
	var commands:Array=[]
	var counts:Array=[0,0,0,0,0,0]
	func begin(time:float):commands.clear();commands.append(["begin",time]);counts.fill(0)
	func set_viewport(size:Vector2):commands.append(["viewport",size])
	func add(mode:int,at:Vector2,extent:Vector2,angle:float,state:Color,event:Color=Color(0,0,0,0))->bool:
		if counts[mode]>=preload("res://scripts/living_passive_layer.gd").LIMITS[mode]:return false
		counts[mode]+=1;commands.append([mode,at,extent,angle,state,event]);return true
	func finish():commands.append(["finish",counts.duplicate()])
	func hide():pass

class CanvasTrace extends RefCounted:
	var commands:Array=[]
	func world(point:Vector2)->Vector2:return point+Vector2(600,400)
	func get_viewport_rect()->Rect2:return Rect2(0,0,1440,900)
	func draw_line(a:Vector2,b:Vector2,color:Color,width:float=1,aa:bool=false):commands.append(["line",a,b,color,width,aa])
	func draw_polyline(points:PackedVector2Array,color:Color,width:float=1,aa:bool=false):commands.append(["polyline",points,color,width,aa])
	func draw_circle(at:Vector2,radius:float,color:Color,filled:bool=true,width:float=-1,aa:bool=false):commands.append(["circle",at,radius,color,filled,width,aa])
	func draw_arc(at:Vector2,radius:float,from:float,to:float,count:int,color:Color,width:float=1,aa:bool=false):commands.append(["arc",at,radius,from,to,count,color,width,aa])
	func draw_colored_polygon(points:PackedVector2Array,color:Color):commands.append(["polygon",points,color])

class CombatTrace extends RefCounted:
	var player
	var db
	var enemies:Array=[]
	var drones:Array=[]
	func _init(p):player=p;db=p.db
	func shield_range(index:int)->float:
		var core=player.effective_core(index)
		return float(core.get("ShieldRange",0))*48*(1+player.upgrade_bonus(core.id,"ShieldRangePercent"))

func check(passed:bool,label:String):
	checks.append({"passed":passed,"label":label})
	if not passed:push_error(label)
func _initialize():call_deferred("execute")
func execute():
	var db=SourceDB.new();var player=Player.new(db)
	var names=["Core_Gun_Gatling","Core_Chip_Mammoth","Core_Shield","Core_Repair","Core_Gun_Cannon","Core_Clocking","Core_FuelTank"]
	for repeat in 4:
		for name in names:player.append_segment(db.named(name).id)
	for reward in db.catalog.values():
		if not reward.get("coresList",[]).is_empty():player.levels[reward.id]=1+player.levels.size()%3
	var battle=CombatTrace.new(player)
	var snapshots=Feedback.new();var legacy=Feedback.new();snapshots.living=LivingTrace.new();legacy.living=LivingTrace.new();snapshots.use_render_snapshots=true;legacy.use_render_snapshots=false
	var comparisons=0;var states_equal=true;var commands_equal=true
	for scenario in 6:
		player.parts[scenario+1].wall=true
		player.parts[scenario+2].hp=maxf(1,player.parts[scenario+2].max_hp-25)
		player.parts[scenario+3].stun=.4 if scenario%2==0 else 0.0
		player.parts[scenario+4].cloaked=scenario%2==0
		player.parts[scenario+5].feedback_pulses={"healed":.18,"shield_break":.1,"chip_trigger":.2,"upgrade":.5}
		if scenario==1:player.set_hq_weapon(db.named("Reward_HQ_Shield").core)
		if scenario==2:player.set_hq_weapon(db.stores.PlayerDataStore.mainTurretCore)
		if scenario==3:player.parts[2].hp=0
		if scenario==4:player.move_piece_to_segment(1,5)
		if scenario==5:
			var reward_id=player.levels.keys()[0]
			db.asset(reward_id).coresList=[player.parts[0].id,player.hq_weapon,player.hq_weapon]
			player.levels[reward_id]=4
		snapshots.prepare_render_upgrades(player)
		for i in player.parts.size():
			var reference=player.passive_state(i)
			var actual=snapshots.render_snapshot(player,i,player.effective_core(i))
			for key in actual:
				if key=="upgrade_rank":continue
				states_equal=states_equal and actual[key]==reference[key];comparisons+=1
			var rank=0
			for id in reference.upgrades:rank+=int(player.levels[id])
			states_equal=states_equal and rank==actual.upgrade_rank;comparisons+=1
		var a=CanvasTrace.new();var b=CanvasTrace.new()
		legacy.clock=scenario*.7;snapshots.clock=legacy.clock
		legacy.update_transitions(player,.1);snapshots.update_transitions(player,.1)
		var before=player.parts.duplicate(true)
		legacy.paint(a,player,battle,.75);snapshots.paint(b,player,battle,.75)
		commands_equal=commands_equal and a.commands==b.commands and legacy.living.commands==snapshots.living.commands
		check(before==player.parts,"Passive presentation does not mutate player state: scenario "+str(scenario))
	check(states_equal,"Reduced draw snapshots match every displayed field and ordered upgrade union across damage, death, rearrangement, HQ swaps and live metadata edits")
	check(commands_equal,"Legacy and optimized paths submit identical overlay instances and native drawing commands in all six scenarios")
	var timings:Array=[]
	for optimized in [false,true,true,false]:
		var began=Time.get_ticks_usec()
		for repeat in 120:
			if optimized:snapshots.prepare_render_upgrades(player)
			for i in player.parts.size():
				if optimized:snapshots.render_snapshot(player,i,player.effective_core(i))
				else:player.passive_state(i)
		timings.append({"optimized":optimized,"mean_snapshot_ms":float(Time.get_ticks_usec()-began)/120000})
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"display_field_comparisons":comparisons,"parts":player.parts.size(),"levels":player.levels.size(),"snapshot_abba":timings,"scope":"Read-only displayed-state and draw-command differential. Snapshot timings include metadata preparation; not whole-game/rendered FPS."}
	FileAccess.open("res://artifacts/deep-passive-render-snapshot-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
