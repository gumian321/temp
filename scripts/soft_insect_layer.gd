extends Node2D
const Brood = preload("res://scripts/brood_theme.gd")
const Rig = preload("res://scripts/soft_insect_rig.gd")
var rigs:Dictionary={}
var battle_id=0

func clear():
	for rig in rigs.values():rig.queue_free()
	rigs.clear()

func sync(game,dt:float):
	if battle_id!=game.combat.get_instance_id():
		clear();battle_id=game.combat.get_instance_id()
	visible=game.screen in ["game","pause","result","rewards"] and not game.radar_mode
	if not visible:return
	var active:Dictionary={}
	for e in game.combat.enemies:
		if not Brood.eligible(e):continue
		var point:Vector2=game.world(e.position)
		var margin=Brood.extent(e)*game.zoom
		if not Rect2(-Vector2.ONE*margin,game.get_viewport_rect().size+Vector2.ONE*margin*2).has_point(point):continue
		active[e.uid]=true
		if not rigs.has(e.uid):
			var rig=Rig.new();add_child(rig);rig.setup(e);rigs[e.uid]=rig
		var rig=rigs[e.uid]
		rig.position=point
		rig.scale=Vector2.ONE*Brood.extent(e)*0.5*game.zoom
		rig.pose(dt)
	for uid in rigs.keys():
		if active.has(uid):continue
		var rig=rigs[uid]
		if float(rig.entity.hp)<=0 and not rig.entity.get("despawn",false):
			rig.position=game.world(rig.entity.position)
			rig.pose(dt,true)
			if rig.death_age<0.34:continue
		rig.queue_free();rigs.erase(uid)
