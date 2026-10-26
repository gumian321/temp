extends SceneTree
const Rig=preload("res://scripts/soft_insect_rig.gd")
const Layer=preload("res://scripts/soft_insect_layer.gd")
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
var checks=[]
func _initialize():call_deferred("execute")
func check(value:bool,message:String):
	checks.append({"name":message,"passed":value})
	if not value:push_error(message)
func actor(i:int,old:bool=false)->Dictionary:
	var entity={"uid":i+(10 if old else 100),"kind":"AISwarmingUnit","brood_species":Brood.SPECIES[i%6],"position":Vector2.ZERO,"angle":-.7,"hp":100.0,"max_hp":100.0,"radius":35.0,"role":"friendly" if old else ""}
	if i>=6:entity.encounter_type=["charger","broodmother","treasure"][i-6]
	Soft.prepare(entity);return entity
func picture(cases:Array,pooled:bool)->Image:
	for item in cases:item.reference.visible=not pooled;item.reused.visible=pooled
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func difference(a:Image,b:Image)->Dictionary:
	var left=a.get_data();var right=b.get_data();var total=0;var over=0
	for i in left.size():
		var error=absi(int(left[i])-int(right[i]));total+=error
		if error>16:over+=1
	return {"mean_channel_error_255":float(total)/left.size(),"channels_over_16_fraction":float(over)/left.size()}
func summary(values:Array)->Dictionary:
	values.sort();var total=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"p95":values[int(values.size()*.95)],"max":values[-1]}
func execute():
	if DisplayServer.get_name()=="headless":push_error("Rig pool check requires native rendering");quit(1);return
	root.size=Vector2i(1440,900)
	var orphans=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var layer=Layer.new();root.add_child(layer);var cases=[]
	for i in 9:
		var old=actor(i,true);var rig=layer.acquire(old)
		for frame in 24:
			old.position+=Vector2(1,2);Soft.step(old,1.0/60)
			rig.pose(1.0/60,false,i%2==0)
		Soft.impact(old,old.position+Vector2(8,0),Vector2.LEFT,40)
		if i%2==1:rig.pose(.15,true)
		var identity=rig.get_instance_id();layer.retire(rig)
		var entity=actor(i);var original=entity.duplicate(true)
		var reused=layer.acquire(entity)
		check(reused.get_instance_id()==identity,"Same anatomy/art pool reuses every original node for case "+str(i))
		check(entity==original,"Rebinding never changes the new actor's simulation for case "+str(i))
		var reference=Rig.new();layer.add_child(reference);reference.setup(entity.duplicate(true))
		var at=Vector2(235+i%3*470,145+i/3*285)
		reference.position=at;reused.position=at
		reference.scale=Vector2.ONE*100;reused.scale=reference.scale
		cases.append({"reference":reference,"reused":reused,"origin":at})
	var comparisons=[]
	for frame in 50:
		for item in cases:
			for rig in [item.reference,item.reused]:
				rig.entity.position+=Vector2.from_angle(frame*.1)*1.2;rig.entity.angle+=.01
				Soft.step(rig.entity,1.0/60)
				if frame==15:Soft.impact(rig.entity,rig.entity.position+Vector2(10,4),Vector2(1,.2),30)
				rig.pose(1.0/60,frame>=40,frame>=22 and frame<36)
		if frame in [0,12,18,37,45,49]:
			var reference=await picture(cases,false);var actual=await picture(cases,true)
			var delta=difference(reference,actual);delta.frame=frame;comparisons.append(delta)
			check(delta.mean_channel_error_255<.02 and delta.channels_over_16_fraction<.0001,"Reused and new rigs preserve full pixels through movement, impact, compact wake and death at frame "+str(frame))
			if frame==18:reference.save_png("res://artifacts/rig-pool-new-20261026.png");actual.save_png("res://artifacts/rig-pool-reused-20261026.png")
	# Warm caches for this timing: compare construction with reuse of full rigs,
	# not initial art decoding or gameplay FPS.
	var fresh=[];var reuse=[]
	for i in 36:
		var e=actor(i%9);var began=Time.get_ticks_usec()
		var rig=Rig.new();layer.add_child(rig);rig.setup(e);fresh.append((Time.get_ticks_usec()-began)/1000.0)
		layer.retire(rig)
		began=Time.get_ticks_usec();var recycled=layer.acquire(actor(i%9));reuse.append((Time.get_ticks_usec()-began)/1000.0)
		recycled.queue_free()
	var parked=[]
	for i in 36:
		var rig=Rig.new();layer.add_child(rig);rig.setup(actor(i%9));parked.append(rig)
	for rig in parked:layer.retire(rig)
	check(layer.rig_pool.size()<=Layer.MAX_POOLED_RIGS,"Complete-rig reuse pool is bounded at 32")
	check(layer.rig_pool.all(func(r):return not r.is_inside_tree()),"Pooled complete rigs submit no hidden scene-tree updates")
	layer.queue_free();await process_frame;await process_frame
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==orphans,"Disposing a pooled layer releases all detached anatomy and rigs")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"comparisons":comparisons,"setup_ms":summary(fresh),"reuse_ms":summary(reuse),"timing_scope":"Warm artwork caches; full rig construction/rebinding only, not game FPS."}
	FileAccess.open("res://artifacts/insect-rig-pool-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	quit(0 if report.passed else 1)
