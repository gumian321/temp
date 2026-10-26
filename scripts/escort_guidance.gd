extends RefCounted
const Pointer=preload("res://scripts/boss_direction.gd")
const ALLY=Color("83d9c1")
const INK=Color("eee9d9")

static func caption(game,at:Vector2,value:String,width:float=220):
	game.draw_string(game.UI.font(),at+Vector2(1,1),value,HORIZONTAL_ALIGNMENT_CENTER,width,14,Color("101414"))
	game.draw_string(game.UI.font(),at,value,HORIZONTAL_ALIGNMENT_CENTER,width,14,INK)

static func pointer(game,target:Vector2,value:String):
	var pose=Pointer.layout(game.get_viewport_rect().size,game.world(target))
	if pose.is_empty():return
	var direction:Vector2=pose.direction;var side=direction.orthogonal();var at:Vector2=pose.point
	var shape=PackedVector2Array([at+direction*13,at-direction*11+side*8,at-direction*6,at-direction*11-side*8,at+direction*13])
	game.draw_colored_polygon(shape,Color("11221e"));game.draw_polyline(shape,ALLY,2,true)
	caption(game,pose.label-Vector2(12,0),value,120)

static func paint(game):
	if game.run==null or game.run.mode.get("class")!="GAModeManager":return
	var director=game.run.director
	var ships=director.living_objectives()
	var view=game.get_viewport_rect().grow(40)
	for ship in ships:
		var at:Vector2=game.world(ship.position)
		if not view.has_point(at):continue
		var radius=maxf(17,float(ship.radius)*game.zoom+7)
		game.draw_arc(at,radius,PI*.12,PI*.88,12,ALLY,1.8,true)
		game.draw_arc(at,radius,PI*1.12,PI*1.88,12,ALLY,1.8,true)
		game.draw_line(at+Vector2(-radius,0),at+Vector2(-radius-5,0),ALLY,2,true)
		game.draw_line(at+Vector2(radius,0),at+Vector2(radius+5,0),ALLY,2,true)
	if not ships.is_empty():
		var at:Vector2=game.world(ships[0].position)
		if view.has_point(at):caption(game,at+Vector2(-110,-34),game.db.ui("BROOD  %d / %d","迁徙虫群  %d / %d")%[ships.size(),director.initial_objectives])
		pointer(game,ships[0].position,game.db.ui("BROOD %dm","迁徙虫群 %d米")%roundi(Vector2(ships[0].position).distance_to(game.player.head)/48))
	var goal:Vector2=game.world(director.fleet_goal)
	if view.has_point(goal):
		var radius=maxf(18,float(director.fleet_data.disFromTargetToWin)*48*game.zoom)
		game.draw_circle(goal,radius,Color(ALLY,.12));game.draw_arc(goal,radius,0,TAU,32,ALLY,2,true)
		game.draw_line(goal-Vector2(8,0),goal+Vector2(8,0),ALLY,2,true);game.draw_line(goal-Vector2(0,8),goal+Vector2(0,8),ALLY,2,true)
		caption(game,goal+Vector2(-110,-radius-12),game.db.ui("SAFE ZONE","安全区 · 护送迁徙虫群抵达"))
	else:pointer(game,director.fleet_goal,game.db.ui("SAFE %dm","终点 %d米")%roundi(game.player.head.distance_to(director.fleet_goal)/48))
