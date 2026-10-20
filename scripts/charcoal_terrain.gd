extends Node2D
## Paint the same world-space pits used by movement and spawn validation.
const Art = preload("res://scripts/charcoal_art.gd")
var game
var visible_chasms: Array = []
var world = preload("res://scripts/chasm_world.gd").new()

func setup(owner_game):
	game = owner_game
	z_index = -8
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func sync():
	visible = game.screen in ["game","pause","result","rewards"] and not game.radar_mode
	if not visible: return
	var view = Rect2(game.camera - game.get_viewport_rect().size / game.zoom * .5, game.get_viewport_rect().size / game.zoom)
	visible_chasms = world.nearby(view)
	queue_redraw()

func _draw():
	if game == null: return
	var source = Art.cutout("chasm")
	for item in visible_chasms:
		var extent = Vector2(780,520) * item.scale * game.zoom
		draw_set_transform(game.world(item.at), item.angle)
		draw_texture_rect(source, Rect2(-extent * .5, extent), false)
	draw_set_transform(Vector2.ZERO)
