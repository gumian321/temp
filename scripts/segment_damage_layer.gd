extends Node2D
## A single read-only overlay keeps local injury cues above combat effects.
const Feedback=preload("res://scripts/segment_feedback.gd")
var game

func _draw():
	if game==null or not game.screen in ["game","pause","result","rewards"] or game.radar_mode:return
	var radar=Rect2(game.get_viewport_rect().size-Vector2(210,235),Vector2(180,150)).grow(25)
	var viewport=game.get_viewport_rect().grow(100)
	for index in game.player.parts.size():
		var part:Dictionary=game.player.parts[index]
		if part.hp<=0:continue
		var at=game.world(Vector2(part.position)+Feedback.offset(part))
		if not viewport.has_point(at) or radar.has_point(at):continue
		var radius=maxf(21,game.player.collision_radius(index)+5)
		Feedback.paint_hit(self,at,float(part.get("body_angle",0)),float(part.get("impact_left",0)),game.zoom,radius)
		Feedback.paint_health(self,part,at,game.zoom,radius,index==0)
