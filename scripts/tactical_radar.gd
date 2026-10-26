extends Node2D
## A HUD canvas, above every world effect and below menus. The map retains the
## generated creature sprites rather than replacing them with schematic dots.
const Art=preload("res://scripts/charcoal_art.gd")
const UI=preload("res://scripts/game_ui.gd")
var game

static func bounds(viewport_size:Vector2)->Rect2:
	var compact=viewport_size.x<1000 or viewport_size.y<700
	var extent=Vector2(144,120) if compact else Vector2(180,150)
	return Rect2(Vector2(viewport_size.x-extent.x-30,viewport_size.y-extent.y-85),extent)

func _draw():
	if game==null or game.run==null or game.screen not in ["game","pause","rewards","result"] or game.radar_mode:return
	var rect=bounds(get_viewport_rect().size)
	# The generated frame has translucent paper edges; the actual map must stay
	# opaque even under large flashes or bright continuous attacks.
	draw_rect(rect.grow(-12),Color("080808"))
	draw_style_box(Art.panel_skin(),rect)
	draw_rect(rect.grow(-12),Color(UI.MUTED,.12),false,1.0)
	var map_scale=rect.size.x/180.0
	for enemy in game.combat.enemies:
		var offset=(Vector2(enemy.position)-game.player.head)*.012
		if offset.length_squared()<70*70:
			game.draw_map_icon(enemy,rect.get_center()+offset*map_scale,(8 if enemy.kind!="AIBossUnit" else 13)*map_scale,true,self)
	draw_circle(rect.get_center(),4,UI.TEAL)
