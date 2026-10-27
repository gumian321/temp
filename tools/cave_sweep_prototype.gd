extends "res://scripts/cave_world.gd"
## Diagnostic prototype only: retain the exact contact solver, extend its
## conservative neighborhood to the longer per-frame moves seen at low FPS.
var extended_queries=0
func wall_hit(start:Vector2,finish:Vector2,radius:float=0.0)->Dictionary:
	var delta=finish-start;var squared=delta.length_squared()
	if not enabled or not use_sweep_neighborhoods or radius>512 or squared<=64 or squared>1024:return super.wall_hit(start,finish,radius)
	extended_queries+=1
	var distance=16.0 if squared<=256 else 32.0
	var query=Rect2(start,Vector2.ZERO).expand(finish).grow(radius+.8)
	var earliest:float=INF;var closest:ContourEdge
	for edge:ContourEdge in local_sweep_edges(start,radius,distance):
		if not edge.bounds.intersects(query):continue
		var time:float=contour_time(edge,start,delta,squared,radius)
		if time<earliest:earliest=time;closest=edge
	if closest==null:return {}
	var position=start+delta*earliest
	var contact=Geometry2D.get_closest_point_to_segment(position,closest.a,closest.b)
	return {"time":earliest,"normal":(position-contact).normalized() if radius>0 else closest.normal,"cell":closest.cell,"position":position}
