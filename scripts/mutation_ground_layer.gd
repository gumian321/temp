extends Node2D
## Persistent poison sits above terrain and below living silhouettes.
var game_ref:WeakRef
func setup(game):
	game_ref=weakref(game);z_index=-2
func world(at:Vector2)->Vector2:return game_ref.get_ref().world(at)
func _draw():
	var game=game_ref.get_ref() if game_ref!=null else null
	if game==null or game.combat==null or game.radar_mode or game.screen not in ["game","pause","rewards","result"]:return
	game.combat.mutation_weapons.paint_ground(self,game.test_time,game.zoom)
