extends Node2D
## Exercises the production body renderer without opaque scenery or tower sprites
## that could conceal a missing atlas. It is only instantiated by native QA.
const CharacterArt = preload("res://scripts/character_art.gd")
var player
var center = Vector2(450, 450)
func _draw():
	if player != null: CharacterArt.draw_body(self, player, center, 1.0, 0.0)
