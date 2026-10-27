extends SceneTree
const Layer=preload("res://scripts/soft_insect_layer.gd")
const Soft=preload("res://scripts/soft_insect.gd")
var checks:Array=[]
var comparisons:Array=[]

class Battle extends RefCounted:
	var enemies:Array=[]

class Game extends Node2D:
	var combat=Battle.new()
	var screen="game"
	var radar_mode=false
	var zoom=1.0
	func world(point:Vector2)->Vector2:return point

func check(passed:bool,label:String):
	checks.append({"passed":passed,"label":label})
	if not passed:push_error(label)

func actor(uid:int,species:String)->Dictionary:
	return {"uid":uid,"kind":"AISwarmingUnit","position":Vector2(312+uid*5,230+uid*3),"angle":-.7,"hp":100.0,"max_hp":100.0,"radius":34.0+uid*2,"brood_species":species}

func board(park:bool)->Dictionary:
	var viewport=SubViewport.new();viewport.size=Vector2i(640,480);viewport.world_2d=World2D.new()
	viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var game=Game.new();viewport.add_child(game)
	game.combat.enemies=[actor(1,"moth"),actor(2,"beetle"),actor(3,"queen")]
	var layer=Layer.new();layer.use_hidden_rig_parking=park;game.add_child(layer)
	return {"viewport":viewport,"game":game,"layer":layer}

func advance(state:Dictionary,dt:float):
	for entity in state.game.combat.enemies:Soft.prepare(entity);Soft.step(entity,dt)
	state.layer.sync(state.game,dt)

func child_order(layer)->Array:
	var result:Array=[]
	for child in layer.get_children():result.append(int(child.entity.uid))
	return result

func collect_refs(node:Node,refs:Array):
	refs.append(weakref(node))
	for child in node.get_children():collect_refs(child,refs)

func owned_refs(layer)->Array:
	var refs:Array=[]
	for rig in layer.rigs.values():collect_refs(rig,refs)
	for rig in layer.rig_pool:collect_refs(rig,refs)
	return refs

func compare(a:Dictionary,b:Dictionary,label:String):
	await process_frame;await RenderingServer.frame_post_draw
	await process_frame;await RenderingServer.frame_post_draw
	var old:Image=a.viewport.get_texture().get_image();var now:Image=b.viewport.get_texture().get_image()
	var left=old.get_data();var right=now.get_data();var changed=0;var maximum=0
	check(old.get_used_rect().has_area(),label+" renders nonempty original artwork")
	for i in left.size():
		var delta=absi(int(left[i])-int(right[i]));maximum=maxi(maximum,delta)
		if delta>0:changed+=1
	comparisons.append({"label":label,"changed_channels":changed,"maximum_channel_error":maximum})
	check(changed==0,label+" retains exact overlapping pixels and painter order")

func _initialize():call_deferred("execute")
func execute():
	if DisplayServer.get_name()=="headless":push_error("Native renderer required for hidden-rig ordering pixels");quit(1);return
	var original=board(false);var parked=board(true)
	advance(original,1.0/60);advance(parked,1.0/60)
	await compare(original,parked,"initial_three_overlapping_species")
	var parked_first=parked.layer.rigs[1]
	for state in [original,parked]:state.game.combat.enemies[0].position=Vector2(3000,200);advance(state,1.0/60)
	check(parked_first.get_parent()==null and parked.layer.rigs[1]==parked_first,"hidden actor retains its exact rig outside SceneTree")
	check(child_order(original.layer)==[1,2,3] and child_order(parked.layer)==[2,3],"only hidden subtree is removed from traversal")
	await compare(original,parked,"oldest_actor_hidden")
	for state in [original,parked]:state.game.combat.enemies[0].position=actor(1,"moth").position;advance(state,1.0/60)
	check(child_order(parked.layer)==[1,2,3] and parked.layer.rigs[1]==parked_first,"oldest reentry restores stable sibling order without constructing a new rig")
	await compare(original,parked,"oldest_reentered_behind_others")
	for state in [original,parked]:
		state.game.combat.enemies[0].position=Vector2(3000,200);state.game.combat.enemies[1].position=Vector2(3000,220)
		state.game.combat.enemies.append(actor(4,"mantis"));advance(state,1.0/60)
	for state in [original,parked]:state.game.combat.enemies[1].position=actor(2,"beetle").position;advance(state,1.0/60)
	check(child_order(parked.layer)==[2,3,4],"partial reentry remains behind a newer actor")
	await compare(original,parked,"partial_reentry_with_new_actor")
	for state in [original,parked]:state.game.combat.enemies[0].position=actor(1,"moth").position;advance(state,1.0/60)
	check(child_order(parked.layer)==[1,2,3,4],"multiple reentries recover original creation order")
	await compare(original,parked,"all_reentered_overlapping")
	# An offscreen actor removed by ordinary combat retirement enters the existing
	# rig pool; clear() must own both detached cache roots and detached pool roots.
	for state in [original,parked]:
		state.game.combat.enemies[0].position=Vector2(3000,200);advance(state,1.0/60)
		state.game.combat.enemies.remove_at(0);advance(state,1.0/60)
	check(not parked.layer.rig_pool.is_empty(),"retired parked rig uses the existing pool without a parent removal error")
	var cleared_refs=owned_refs(original.layer)+owned_refs(parked.layer)
	original.layer.clear();parked.layer.clear()
	await process_frame
	check(cleared_refs.all(func(ref):return ref.get_ref()==null),"clear frees every attached, hidden and pooled node")
	check(original.layer.get_child_count()==0 and parked.layer.get_child_count()==0 and parked.layer.rigs.is_empty() and parked.layer.hidden_rigs.is_empty(),"clear removes every tracking entry and child")
	for state in [original,parked]:
		state.game.combat.enemies=[actor(10,"grub"),actor(11,"sac")];advance(state,1.0/60)
		state.game.combat.enemies[0].position=Vector2(3000,200);advance(state,1.0/60)
	var exit_refs=owned_refs(original.layer)+owned_refs(parked.layer)
	original.viewport.queue_free();parked.viewport.queue_free()
	await process_frame;await process_frame
	check(exit_refs.all(func(ref):return ref.get_ref()==null),"freeing owner without clear leaves no detached rig or child orphan")
	var passed=checks.all(func(item):return item.passed)
	var report={"suite":"hidden_rig_parking","passed":passed,"checks":checks,"pixel_comparisons":comparisons,"scope":"Original and parked production rigs with matching simulation poses, overlapping species, oldest/partial reentry, new actor, pool retirement, explicit clear and owner destruction."}
	FileAccess.open("res://artifacts/hidden-rig-parking.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	quit(0 if passed else 1)
