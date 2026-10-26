extends Node2D
const Brood = preload("res://scripts/brood_theme.gd")
const Rig = preload("res://scripts/soft_insect_rig.gd")
# Only offscreen rigs consume this reuse budget. Visible actors and their
# death feedback are never limited. Dictionary insertion order supplies LRU
# without sorting every frame: reappearance removes an entry before re-hiding.
const MAX_HIDDEN_RIGS=96
var rigs:Dictionary={}
var hidden_rigs:Dictionary={}
var battle_id=0
const MAX_POOLED_RIGS=32
var rig_pool:Array=[]
var use_rig_pool=OS.get_environment("RBPEW_LEGACY_RIG_POOL")!="1"
var rig_builds=0
var rig_reuses=0

func clear():
	for rig in rigs.values():rig.queue_free()
	rigs.clear();hidden_rigs.clear()
	for rig in rig_pool:rig.free()
	rig_pool.clear()

func acquire(actor:Dictionary):
	if use_rig_pool and not rig_pool.is_empty():
		var key=Rig.reuse_key(actor)
		for i in range(rig_pool.size()-1,-1,-1):
			var rig=rig_pool[i]
			if rig.anatomy_key==key:
				rig_pool.remove_at(i);add_child(rig);rig.reuse(actor);rig_reuses+=1
				return rig
	var rig=Rig.new();add_child(rig);rig.setup(actor);rig_builds+=1
	return rig

func retire(rig):
	if not use_rig_pool or not rig is Rig or not rig.preview_species.is_empty() or not rig.batch_appendages:rig.queue_free();return
	rig.visible=false;remove_child(rig)
	# The pool lives outside the tree; retained bones submit no frame updates.
	if rig_pool.size()>=MAX_POOLED_RIGS:rig_pool.pop_front().free()
	rig_pool.append(rig)

func _exit_tree():
	for rig in rig_pool:rig.free()
	rig_pool.clear()

func sync(game,dt:float):
	if battle_id!=game.combat.get_instance_id():
		clear();battle_id=game.combat.get_instance_id()
	visible=game.screen in ["game","pause","result","rewards"] and not game.radar_mode
	if not visible:return
	var active:Dictionary={}
	var viewport_size:Vector2=game.get_viewport_rect().size
	var crowded=game.combat.enemies.size()>24
	var focus=viewport_size*.5
	for e in game.combat.enemies:
		if not Brood.eligible(e):continue
		var point:Vector2=game.world(e.position)
		var margin=Brood.extent(e)*game.zoom
		# Keep anatomy only for actors still in this battle. Leaving the viewport
		# hides the existing rig; cached reentry avoids rebuilding anatomy.
		# Removed actors release it below; the hidden LRU also bounds long battles.
		active[e.uid]=true
		if not Rect2(-Vector2.ONE*margin,viewport_size+Vector2.ONE*margin*2).has_point(point):
			if rigs.has(e.uid):
				rigs[e.uid].visible=false
				if not hidden_rigs.has(e.uid):hidden_rigs[e.uid]=true
			continue
		if not rigs.has(e.uid):
			rigs[e.uid]=acquire(e)
		var rig=rigs[e.uid]
		rig.visible=true
		hidden_rigs.erase(e.uid)
		rig.position=point
		rig.scale=Vector2.ONE*Brood.extent(e)*0.5*game.zoom
		var state:Dictionary=e.soft_body
		var feedback=float(state.shock)>.12 or float(state.hold)>0 or state.has("push_strain") or state.has("pull_strain") or float(state.flash)>0
		var compact=crowded and margin<72 and point.distance_squared_to(focus)>170*170 and e.get("role","")!="friendly" and not feedback
		rig.pose(dt,false,compact)
	for uid in rigs.keys():
		if active.has(uid):continue
		var rig=rigs[uid]
		if rig.visible and float(rig.entity.hp)<=0 and not rig.entity.get("despawn",false):
			rig.position=game.world(rig.entity.position)
			rig.pose(dt,true)
			if rig.death_age<0.16:continue
		retire(rig);rigs.erase(uid);hidden_rigs.erase(uid)
	if hidden_rigs.size()>MAX_HIDDEN_RIGS:
		# Snapshot keys only on overflow, never for the normal cache-hit path.
		for uid in hidden_rigs.keys():
			if hidden_rigs.size()<=MAX_HIDDEN_RIGS:break
			retire(rigs[uid]);rigs.erase(uid);hidden_rigs.erase(uid)
