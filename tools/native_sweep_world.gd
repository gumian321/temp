extends "res://scripts/cave_world.gd"
## Opt-in diagnostic prototype. The ordinary game never loads this script/DLL.
var native_kernel:RefCounted
var native_packed=PackedFloat64Array()
var native_queries=0
var native_packs=0
var native_edge_values=0
func _init():
	# A production descriptor can register this exact class before a diagnostic
	# world is constructed. Reuse it rather than loading a second DLL copy.
	if ClassDB.class_exists(&"CaveSweepKernel"):
		native_kernel=ClassDB.instantiate(&"CaveSweepKernel");return
	var status=GDExtensionManager.load_extension("res://native/cave_sweep/test_project/cave_sweep.gdextension")
	if status in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED] and ClassDB.class_exists(&"CaveSweepKernel"):
		native_kernel=ClassDB.instantiate(&"CaveSweepKernel")
	else:push_error("Native sweep prototype unavailable: %s"%status)
func pack_native(edges:Array)->PackedFloat64Array:
	var packed=PackedFloat64Array();packed.resize(edges.size()*13)
	for i in edges.size():
		var edge:ContourEdge=edges[i];var base=i*13
		packed[base]=edge.a.x;packed[base+1]=edge.a.y;packed[base+2]=edge.b.x;packed[base+3]=edge.b.y
		packed[base+4]=edge.delta.x;packed[base+5]=edge.delta.y;packed[base+6]=edge.normal.x;packed[base+7]=edge.normal.y;packed[base+8]=edge.length_squared
		packed[base+9]=edge.bounds.position.x;packed[base+10]=edge.bounds.position.y;packed[base+11]=edge.bounds.size.x;packed[base+12]=edge.bounds.size.y
	native_packs+=1;native_edge_values+=packed.size()
	return packed
func local_sweep_edges(start:Vector2,radius:float,distance:float)->Array:
	var edges=super.local_sweep_edges(start,radius,distance)
	var tile=Vector3i(floori(start.x/SWEEP_NEIGHBORHOOD_STEP),floori(start.y/SWEEP_NEIGHBORHOOD_STEP),int(distance))
	if use_extended_sweeps and radius>=64 and distance>LOCAL_SWEEP_DISTANCE:tile.z=0
	var entry:Dictionary=sweep_neighborhoods[radius][tile]
	if not entry.has("native_packed"):entry.native_packed=pack_native(edges)
	native_packed=entry.native_packed
	return edges
func local_wall_hit(start:Vector2,finish:Vector2,radius:float,delta:Vector2,squared:float)->Dictionary:
	if native_kernel==null:return super.local_wall_hit(start,finish,radius,delta,squared)
	var distance=1.0 if squared<=1 else (2.0 if squared<=4 else (4.0 if squared<=16 else LOCAL_SWEEP_DISTANCE))
	if squared>64:distance=16.0 if squared<=256 else EXTENDED_SWEEP_DISTANCE
	var edges=local_sweep_edges(start,radius,distance)
	if edges.is_empty():return {}
	var query=Rect2(start,Vector2.ZERO).expand(finish).grow(radius+.8)
	var result:PackedFloat64Array=native_kernel.call(&"scan",native_packed,PackedFloat64Array([start.x,start.y,delta.x,delta.y,radius,query.position.x,query.position.y,query.size.x,query.size.y]))
	native_queries+=1
	var index=int(result[0])
	if index<0:return {}
	var closest:ContourEdge=edges[index];var earliest:float=result[1]
	var position:Vector2=start+delta*earliest
	var contact:Vector2=Geometry2D.get_closest_point_to_segment(position,closest.a,closest.b)
	var normal:Vector2=(position-contact).normalized() if radius>0 else closest.normal
	return {"time":earliest,"normal":normal,"cell":closest.cell,"position":position}
func native_stats()->Dictionary:
	return {"loaded":native_kernel!=null,"queries":native_queries,"packed_neighborhoods":native_packs,"packed_values":native_edge_values,"scope":"Isolated local-sweep native math prototype, ordinary game unchanged"}
