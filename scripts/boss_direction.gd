extends RefCounted
## Screen-edge bone pointer. Sized in screen pixels, independent of world zoom.
static func layout(view:Vector2,target:Vector2)->Dictionary:
	var center=view*.5
	var safe=Rect2(Vector2(60,116),Vector2(maxf(1,view.x-120),maxf(1,view.y-230)))
	if safe.has_point(target):return {}
	var direction=center.direction_to(target)
	if direction.is_zero_approx():return {}
	var limits=Vector2((safe.end.x-center.x) if direction.x>=0 else (center.x-safe.position.x),(safe.end.y-center.y) if direction.y>=0 else (center.y-safe.position.y))
	var distance=minf(limits.x/maxf(.001,absf(direction.x)),limits.y/maxf(.001,absf(direction.y)))
	var point=center+direction*distance
	var radar=Rect2(view-Vector2(260,280),Vector2(260,280))
	if radar.has_point(point) and direction.y>0:
		point=center+direction*((view.y-292-center.y)/direction.y)
	return {"point":point,"direction":direction,"label":(point-direction*40-Vector2(48,-28)).clamp(Vector2(8,104),view-Vector2(104,94))}

static func paint(game):
	var targets=game.combat.enemies.filter(func(e):return e.hp>0 and int(e.get("parent",0))==0 and (e.kind=="AIBossUnit" or e.get("objective",false)))
	targets.sort_custom(func(a,b):return a.kind=="AIBossUnit" if (a.kind=="AIBossUnit")!=(b.kind=="AIBossUnit") else a.position.distance_squared_to(game.player.head)<b.position.distance_squared_to(game.player.head))
	var drawn:Array=[]
	for e in targets:
		var pose=layout(game.get_viewport_rect().size,game.world(e.position))
		if pose.is_empty() or drawn.any(func(p):return p.distance_to(pose.point)<80):continue
		drawn.append(pose.point)
		if drawn.size()>4:break
		var direction:Vector2=pose.direction
		var side=direction.orthogonal()
		var tip:Vector2=pose.point+direction*12
		var base:Vector2=pose.point-direction*14
		var outline=PackedVector2Array([tip,base+side*9,base+direction*6,base-side*9,tip])
		game.draw_colored_polygon(outline,Color("121212"))
		game.draw_polyline(outline,Color("d7d3c3"),1.4,true)
		game.draw_line(base+direction*8,tip-direction*3,Color("ff387c"),2.0,true)
		var gem=base-direction*12
		game.draw_colored_polygon(PackedVector2Array([gem+direction*6,gem+side*4,gem-direction*6,gem-side*4]),Color("ff387c"))
		var label=("首领" if e.kind=="AIBossUnit" else "目标")+"  %dm"%roundi(Vector2(e.position).distance_to(game.player.head)/48)
		game.draw_string(game.UI.font(),pose.label+Vector2(1,1),label,HORIZONTAL_ALIGNMENT_CENTER,96,14,Color("111111"))
		game.draw_string(game.UI.font(),pose.label,label,HORIZONTAL_ALIGNMENT_CENTER,96,14,Color("eee9d9"))
