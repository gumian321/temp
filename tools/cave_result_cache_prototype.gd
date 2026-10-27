extends "res://scripts/cave_world.gd"
const CACHE_LIMIT=1024
var hit_cache:Dictionary={}
var hit_ring:Array=[]
var hit_cursor=0
var hit_revision=-1
var cache_hits=0
var cache_misses=0
func reset_cave(active:bool,world_seed:int=20261020):
	super.reset_cave(active,world_seed)
	hit_cache.clear();hit_ring.clear();hit_cursor=0;hit_revision=-1;cache_hits=0;cache_misses=0
func wall_hit(start:Vector2,finish:Vector2,radius:float=0.0)->Dictionary:
	if not enabled or radius<64 or radius>512 or start.distance_squared_to(finish)>256:return super.wall_hit(start,finish,radius)
	if hit_revision!=revision:
		hit_cache.clear();hit_ring.clear();hit_cursor=0;hit_revision=revision
	var key=Vector4(start.x,start.y,finish.x,finish.y)
	if hit_cache.has(radius) and hit_cache[radius].has(key):cache_hits+=1;return hit_cache[radius][key].duplicate()
	cache_misses+=1
	var result=super.wall_hit(start,finish,radius)
	if hit_ring.size()==CACHE_LIMIT:
		var old:Array=hit_ring[hit_cursor];hit_cache[old[0]].erase(old[1])
		if hit_cache[old[0]].is_empty():hit_cache.erase(old[0])
		hit_ring[hit_cursor]=[radius,key];hit_cursor=(hit_cursor+1)%CACHE_LIMIT
	else:hit_ring.append([radius,key])
	if not hit_cache.has(radius):hit_cache[radius]={}
	hit_cache[radius][key]=result.duplicate()
	return result
