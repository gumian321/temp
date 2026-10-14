extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const LegacyBody=preload("res://scripts/centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Feedback=preload("res://scripts/segment_feedback.gd")
var checks:Array=[]
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func _initialize():call_deferred("execute")
func execute():
	var db=DB.new()
	var body=Body.new(db)
	for name in ["Core_Gun_Gatling","Core_Gun_Cannon","Core_Gun_Shotgun"]:body.append_segment(db.named(name).id)
	var battle=Battle.new(db,body)
	var index=body.part_at(2)
	var original:Dictionary=body.parts[index]
	var follower:Dictionary=body.parts[body.part_at(3)]
	var follower_hp=float(follower.hp)
	battle.hurt_player(index,1,1)
	check(original.impact_left==Feedback.HIT_TIME and battle.effects.all(func(e):return e.kind!="segment_break"),"Nonlethal hits show a timed shell response without destruction")
	var point:Vector2=body.segment_pose(2).point
	battle.hurt_player(index,100000,100000)
	var broken=battle.effects.filter(func(e):return e.kind=="segment_break")
	check(broken.size()==1,"Lethal damage immediately creates exactly one break animation")
	var visual:Dictionary=broken[0]
	check(visual.position==point and visual.id==original.id and visual.segment==2,"Debris captures the destroyed segment's exact original pose and equipment")
	check(not visual.has("owner") and not visual.has("part"),"Visual snapshot holds no mutable gameplay owner or part reference")
	battle.hurt_player(index,100000,100000);battle.segment_destroyed(index)
	check(battle.effects.filter(func(e):return e.kind=="segment_break").size()==1,"Repeated lethal hits and cleanup cannot duplicate feedback")
	battle.step(.01,body.head+Vector2.RIGHT*500,false)
	check(body.segment_count()==2 and follower.segment==2 and follower.hp==follower_hp,"Death compacts the living chain without damage to followers")
	check(visual.position==point and visual.life>0.8,"Detached animation survives gameplay removal at its original world position")
	check(battle.audio_events.any(func(e):return e.get("feedback","")=="segment_break"),"Destruction emits a dedicated audible cue")
	var first=Feedback.debris_position(visual,0)
	visual.life=0.4
	check(Feedback.debris_position(visual,0).distance_to(first)>10,"Debris travels visibly outward over its lifetime")
	battle.step(1.1,Vector2.RIGHT*500,false)
	check(battle.effects.all(func(e):return e.kind!="segment_break"),"Expired debris is removed and cannot accumulate")
	# Direct HP mutations follow the same once-only path through special cleanup.
	body.parts[1].hp=0;battle.step(.01,Vector2.RIGHT*500,false)
	check(battle.effects.filter(func(e):return e.kind=="segment_break").size()==1,"Direct damage and scripted deaths also receive feedback")
	# A simultaneous mass loss stays within the rendering/audio budgets.
	body=Body.new(db);battle=Battle.new(db,body)
	for i in range(60):body.append_segment(db.named("Core_Gun_Gatling").id)
	for i in range(1,body.parts.size()):battle.hurt_player(i,100000,100000)
	check(battle.effects.filter(func(e):return e.kind=="segment_break").size()==Feedback.MAX_DEBRIS,"Mass destruction is bounded to 24 detached visual snapshots")
	check(battle.audio_events.filter(func(e):return e.get("feedback","")=="segment_break").size()==1,"Simultaneous segment loss does not stack dozens of explosion sounds")
	battle.step(.01,Vector2.RIGHT*500,false)
	check(body.parts.size()==1 and body.parts[0].hp>0,"Mass destruction still removes all 60 body parts without harming the head")
	# Shared battle/specials also serve the legacy body, which has no module_size API.
	var legacy=LegacyBody.new(db)
	legacy.append_segment(db.named("Core_Gun_Gatling").id)
	legacy.append_segment(db.named("Core_Gun_Cannon").id)
	var legacy_battle=Battle.new(db,legacy)
	legacy_battle.hurt_player(1,100000,100000)
	var legacy_effects=legacy_battle.effects.filter(func(e):return e.kind=="segment_break")
	check(legacy_effects.size()==1 and legacy_effects[0].module_size==56.0 and legacy_effects[0].has("life"),"Legacy body without module_size produces a complete safe destruction snapshot")
	legacy_battle.step(.01,Vector2.RIGHT*500,false)
	check(legacy.parts.size()==2,"Legacy combat cleanup still removes only the destroyed body part")
	legacy.parts[1].hp=0
	legacy_battle.special.step(.01)
	check(legacy_battle.effects.filter(func(e):return e.kind=="segment_break").size()==2,"Legacy direct HP death also receives a safe once-only snapshot")
	legacy_battle.step(1.1,Vector2.RIGHT*500,false)
	check(legacy.parts.size()==1 and legacy_battle.effects.all(func(e):return e.kind!="segment_break"),"Legacy effects expire and cleanup completes without malformed dictionaries")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/segment-feedback-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
