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

func clear():
	for rig in rigs.values():rig.queue_free()
	rigs.clear();hidden_rigs.clear()

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
			var rig=Rig.new();add_child(rig);rig.setup(e);rigs[e.uid]=rig
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
		rig.queue_free();rigs.erase(uid);hidden_rigs.erase(uid)
	if hidden_rigs.size()>MAX_HIDDEN_RIGS:
		# Snapshot keys only on overflow, never for the normal cache-hit path.
		for uid in hidden_rigs.keys():
			if hidden_rigs.size()<=MAX_HIDDEN_RIGS:break
			rigs[uid].queue_free();rigs.erase(uid);hidden_rigs.erase(uid)
