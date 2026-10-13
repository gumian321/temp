extends Node2D
## Original world illustrations stay ink-colored beneath equipment and the HUD.
var illustrations: Array = []

func begin_frame():
	illustrations.clear()
	queue_redraw()

func paint(texture: Texture2D, at: Vector2, extent: Vector2, angle: float, tint: Color):
	illustrations.append({"texture": texture, "at": at, "extent": extent, "angle": angle, "tint": tint})

func _draw():
	for item in illustrations:
		draw_set_transform(item.at, item.angle)
		draw_texture_rect(item.texture, Rect2(-item.extent * 0.5, item.extent), false, item.tint)
	draw_set_transform(Vector2.ZERO)
