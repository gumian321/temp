extends "res://scripts/cave_world.gd"
var kernel_us:Dictionary={}
var kernel_calls:Dictionary={}
func record_kernel(key:String,began:int):
	kernel_us[key]=int(kernel_us.get(key,0))+Time.get_ticks_usec()-began
	kernel_calls[key]=int(kernel_calls.get(key,0))+1
func wall_blocked(point:Vector2,radius:float=0.0)->bool:
	var began=Time.get_ticks_usec();var result=super.wall_blocked(point,radius);record_kernel("wall_blocked",began);return result
func wall_hit(start:Vector2,finish:Vector2,radius:float=0.0)->Dictionary:
	var began=Time.get_ticks_usec();var result=super.wall_hit(start,finish,radius);record_kernel("wall_hit",began);return result
func separate_lip(point:Vector2,radius:float)->Vector2:
	var began=Time.get_ticks_usec();var result=super.separate_lip(point,radius);record_kernel("separate_lip",began);return result
func safe_among(point:Vector2,radius:float,pits:Array)->Vector2:
	var began=Time.get_ticks_usec();var result=super.safe_among(point,radius,pits);record_kernel("safe_among",began);return result
func nearby(area:Rect2)->Array:
	var began=Time.get_ticks_usec();var result=super.nearby(area);record_kernel("legacy_nearby",began);return result
func local_sweep_edges(start:Vector2,radius:float,distance:float)->Array:
	var began=Time.get_ticks_usec();var result=super.local_sweep_edges(start,radius,distance);record_kernel("local_sweep_edges",began);return result
func cell_shape(cell:Vector2i)->Dictionary:
	var began=Time.get_ticks_usec();var result=super.cell_shape(cell);record_kernel("cell_shape",began);return result
func collision_row(y:int,left:int,right:int)->Array:
	var began=Time.get_ticks_usec();var result=super.collision_row(y,left,right);record_kernel("collision_row",began);return result
func contour_time(edge:ContourEdge,start:Vector2,delta:Vector2,squared:float,radius:float)->float:
	var began=Time.get_ticks_usec();var result=super.contour_time(edge,start,delta,squared,radius);record_kernel("contour_time",began);return result
func move_contour(start:Vector2,desired:Vector2,radius:float)->Vector2:
	var began=Time.get_ticks_usec();var result=super.move_contour(start,desired,radius);record_kernel("move_contour",began);return result
func prepare_navigation(data:Dictionary,origin:Vector2,target:Vector2,margin:int)->bool:
	var began=Time.get_ticks_usec();var result=super.prepare_navigation(data,origin,target,margin);record_kernel("prepare_navigation",began);return result
