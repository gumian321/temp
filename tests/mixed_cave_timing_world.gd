extends "res://scripts/cave_world.gd"
## Diagnostic subclass only. Inclusive timings overlap; these are not FPS.
var samples:Dictionary={}
func mark(label:String,began:int):
	var item=samples.get(label,{"us":0,"calls":0})
	item.us+=Time.get_ticks_usec()-began;item.calls+=1;samples[label]=item
func move(start:Vector2,desired:Vector2,radius:float)->Vector2:
	var began=Time.get_ticks_usec();var result=super.move(start,desired,radius)
	mark("move",began);return result
func wall_blocked(point:Vector2,radius:float=0.0)->bool:
	var began=Time.get_ticks_usec();var result=super.wall_blocked(point,radius)
	mark("wall_blocked",began);return result
func wall_hit(start:Vector2,finish:Vector2,radius:float=0.0)->Dictionary:
	var began=Time.get_ticks_usec();var result=super.wall_hit(start,finish,radius)
	mark("wall_hit",began);return result
func direction(origin:Vector2,target:Vector2,radius:float,memory:Dictionary)->Vector2:
	var began=Time.get_ticks_usec();var result=super.direction(origin,target,radius,memory)
	mark("direction",began);return result
func prepare_placement(memory:Dictionary,requested:Vector2,radius:float)->bool:
	var began=Time.get_ticks_usec();var result=super.prepare_placement(memory,requested,radius)
	mark("prepare_placement",began);return result
