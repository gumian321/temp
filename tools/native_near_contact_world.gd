extends "res://tools/native_sweep_world.gd"
## Source-only backup prototype. No production resource or DLL is modified.
var native_near_contact_queries=0

func near_contact_hit(start:Vector2,finish:Vector2,radius:float,delta:Vector2,squared:float)->Dictionary:
	# The inherited implementation owns counters when no extension is loaded.
	if native_kernel==null:return super.near_contact_hit(start,finish,radius,delta,squared)
	near_contact_probes+=1
	var edges=local_sweep_edges(start,radius,32.0)
	if edges.is_empty():near_contact_fallbacks+=1;return {}
	var query=Rect2(start,Vector2.ZERO).expand(finish).grow(radius+.8)
	# Keep the original full displacement: short reparameterized sweeps change
	# Godot's float32 segment/circle quadratic and exact corner decisions.
	var result:PackedFloat64Array=native_kernel.call(&"scan",native_packed,PackedFloat64Array([start.x,start.y,delta.x,delta.y,radius,query.position.x,query.position.y,query.size.x,query.size.y]))
	native_queries+=1;native_near_contact_queries+=1
	var index=int(result[0]);var earliest:float=result[1]
	if index>=0 and earliest>=0 and earliest*sqrt(squared)<24.0:
		near_contact_hits+=1
		var closest:ContourEdge=edges[index]
		var position=start+delta*earliest
		var contact=Geometry2D.get_closest_point_to_segment(position,closest.a,closest.b)
		var normal=(position-contact).normalized() if radius>0 else closest.normal
		return {"time":earliest,"normal":normal,"cell":closest.cell,"position":position}
	near_contact_fallbacks+=1
	return {}

func native_stats()->Dictionary:
	var result=super.native_stats()
	result.near_contact_queries=native_near_contact_queries
	result.scope="Isolated native local and near-contact sweep prototype; ordinary game unchanged"
	return result
