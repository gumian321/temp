extends SceneTree
const Rig=preload("res://scripts/soft_insect_rig.gd")
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
var checks:Array=[]
func check(value:bool,message:String):
	checks.append({"passed":value,"name":message})
	if not value:push_error(message)
func _initialize():call_deferred("execute")
func image_of(rigs:Array,other:Array)->Image:
	for rig in rigs:rig.show()
	for rig in other:rig.hide()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func execute():
	var initial_orphans=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	root.size=Vector2i(1440,900)
	var current:Array=[];var previous:Array=[];var errors:Array=[]
	for optimized in [false,true]:
		var group:Array=[]
		for i in 6:
			var entity={"uid":i+1,"kind":"AISwarmingUnit","position":Vector2(220+i%3*440,240+i/3*400),"angle":0.0,"hp":100.0,"max_hp":100.0,"radius":18.0,"brood_species":Brood.SPECIES[i]}
			Soft.prepare(entity)
			var rig=Rig.new();rig.use_compact_tree_cache=optimized;root.add_child(rig);rig.setup(entity)
			rig.position=entity.position;rig.scale=Vector2.ONE*125;group.append(rig)
		if optimized:current=group
		else:previous=group
	var bones_survive=true
	for frame in 100:
		var compact=frame>=4 and frame<35 or frame>=42 and frame<70
		for group in [previous,current]:
			for rig in group:
				rig.entity.angle+=.005;rig.entity.position+=Vector2(.2,.1);Soft.step(rig.entity,1.0/60)
				rig.pose(1.0/60,false,compact)
				bones_survive=bones_survive and rig.bones.size()==15 and is_instance_valid(rig.bones[0])
		if frame==20:
			check(current.all(func(rig):return not rig.mesh.is_inside_tree() and not rig.limb_skeleton.is_inside_tree()),"Distant insects park hidden anatomy outside the active tree")
			check(previous.all(func(rig):return rig.mesh.is_inside_tree()),"Reference retains the original active hidden skeletons")
		if frame in [3,35,70,99] and DisplayServer.get_name()!="headless":
			var reference=await image_of(previous,current);var actual=await image_of(current,previous)
			var a=reference.get_data();var b=actual.get_data();var sum=0;var changed=0
			for i in a.size():
				var delta=absi(int(a[i])-int(b[i]));sum+=delta
				if delta>16:changed+=1
			var mean=float(sum)/a.size();var fraction=float(changed)/a.size();errors.append({"frame":frame,"mean_channel_error_255":mean,"channels_over_16_fraction":fraction})
			check(mean<.01 and fraction<.0005,"Six species restore identical full-detail bodies, feet and wings after wake at frame "+str(frame))
			if frame==70:actual.save_png("res://artifacts/rig-wake-dense60.png")
	check(bones_survive,"Repeated compact/full switches preserve all original bones")
	for rig in current:
		rig.pose(1.0/60,false,true);rig.pose(.01,true,true)
	check(current.all(func(rig):return rig.mesh.is_inside_tree() and not rig.compact_pose),"Death wakes full anatomy immediately")
	for rig in current:rig.pose(.25,false,true);rig.queue_free()
	for rig in previous:rig.queue_free()
	await process_frame;await process_frame
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)<=initial_orphans,"Deleting a parked rig frees every detached node")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"comparisons":errors}
	FileAccess.open("res://artifacts/rig-cache-wake-dense60.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
