extends RefCounted
## Frame-local broad phase. Narrow-phase distances and source part order remain
## unchanged; distant enemy bullets no longer test every centipede segment.
const CELL=128.0
var cells:Dictionary={}
var radii=PackedFloat64Array()
var all_indices:Array=[]
var max_radius=0.0
var low=Vector2.INF
var high=-Vector2.INF

func rebuild(player):
	cells.clear();all_indices.clear();radii.resize(player.parts.size())
	max_radius=0;low=Vector2.INF;high=-Vector2.INF
	for i in player.parts.size():
		var at:Vector2=player.parts[i].position
		var radius:float=player.collision_radius(i)
		radii[i]=radius;max_radius=maxf(max_radius,radius);low=low.min(at);high=high.max(at)
		var cell=Vector2i((at/CELL).floor())
		if not cells.has(cell):cells[cell]=[]
		cells[cell].append(i);all_indices.append(i)

func candidates(start:Vector2,finish:Vector2)->Array:
	if all_indices.is_empty():return []
	var query_low=start.min(finish)-Vector2.ONE*max_radius
	var query_high=start.max(finish)+Vector2.ONE*max_radius
	if query_high.x<low.x or query_high.y<low.y or query_low.x>high.x or query_low.y>high.y:return []
	var first=Vector2i((query_low/CELL).floor());var last=Vector2i((query_high/CELL).floor())
	if (last.x-first.x+1)*(last.y-first.y+1)>all_indices.size()*2:return all_indices
	if first==last:return cells.get(first,[])
	var result:Array=[]
	for x in range(first.x,last.x+1):
		for y in range(first.y,last.y+1):result.append_array(cells.get(Vector2i(x,y),[]))
	result.sort()
	return result
