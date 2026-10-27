extends RefCounted
## Optional exact native scan. An empty result requests the GDScript fallback;
## [-1, INF] is a successful scan with no contact.
const RELATIVE_DESCRIPTOR="native_runtime/cave_sweep/cave_sweep.gdextension"
const PACK_KEY=&"_cave_native_pack"
var _kernel:RefCounted
var _attempted=false
var _queries=0
var _packs=0
var _packed_values=0
var _rejected=0
var _overlap_queries=0
var _has_overlap=false
var _scan_payload=PackedFloat64Array()
var _overlap_payload=PackedFloat64Array()

func _init():
	_scan_payload.resize(9)
	_overlap_payload.resize(3)

func ready()->bool:
	if _attempted:return _kernel!=null
	_attempted=true
	var version=Engine.get_version_info()
	if OS.get_name()!="Windows" or Engine.get_architecture_name()!="x86_64" or int(version.major)!=4 or int(version.minor)!=6 or int(version.patch)!=3:return false
	# A float32 Vector2 rounds this increment away. Double-precision builds
	# use different arithmetic and must retain the original GDScript solver.
	if Vector2(16777216.0,0).x+1.0==Vector2(16777217.0,0).x:return false
	if not ClassDB.class_exists(&"CaveSweepKernel"):
		var descriptor=ProjectSettings.globalize_path("res://"+RELATIVE_DESCRIPTOR) if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join(RELATIVE_DESCRIPTOR)
		if not FileAccess.file_exists(descriptor):return false
		var status=GDExtensionManager.load_extension(descriptor)
		if status not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:return false
	if not ClassDB.class_exists(&"CaveSweepKernel"):return false
	_kernel=ClassDB.instantiate(&"CaveSweepKernel")
	if _kernel!=null and not _kernel.has_method(&"scan"):_kernel=null
	_has_overlap=_kernel!=null and _kernel.has_method(&"overlap")
	return _kernel!=null

func _finite_vector(value:Vector2)->bool:
	return is_finite(value.x) and is_finite(value.y)

func _pack(edges:Array,entry:Dictionary)->PackedFloat64Array:
	var packed:PackedFloat64Array
	if entry.has(PACK_KEY):
		packed=entry[PACK_KEY]
		if packed.size()!=edges.size()*13:_rejected+=1;return PackedFloat64Array()
	else:
		packed=PackedFloat64Array();packed.resize(edges.size()*13)
		for i in edges.size():
			var edge=edges[i]
			if not _finite_vector(edge.a) or not _finite_vector(edge.b) or not _finite_vector(edge.delta) or not _finite_vector(edge.normal) or not is_finite(edge.length_squared) or edge.length_squared<=0 or not _finite_vector(edge.bounds.position) or not _finite_vector(edge.bounds.size) or not _finite_vector(edge.bounds.end) or edge.bounds.size.x<0 or edge.bounds.size.y<0:
				_rejected+=1;return PackedFloat64Array()
			var base=i*13
			packed[base]=edge.a.x;packed[base+1]=edge.a.y;packed[base+2]=edge.b.x;packed[base+3]=edge.b.y
			packed[base+4]=edge.delta.x;packed[base+5]=edge.delta.y;packed[base+6]=edge.normal.x;packed[base+7]=edge.normal.y;packed[base+8]=edge.length_squared
			packed[base+9]=edge.bounds.position.x;packed[base+10]=edge.bounds.position.y;packed[base+11]=edge.bounds.size.x;packed[base+12]=edge.bounds.size.y
		entry[PACK_KEY]=packed
		_packs+=1;_packed_values+=packed.size()
	return packed

func scan(edges:Array,entry:Dictionary,start:Vector2,delta:Vector2,radius:float,query:Rect2)->PackedFloat64Array:
	if not ready():return PackedFloat64Array()
	if not _finite_vector(start) or not _finite_vector(delta) or not _finite_vector(start+delta) or not is_finite(delta.length_squared()) or not is_finite(radius) or radius<0 or radius>3.4028234663852886e38 or not _finite_vector(query.position) or not _finite_vector(query.size) or not _finite_vector(query.end) or query.size.x<0 or query.size.y<0:
		_rejected+=1;return PackedFloat64Array()
	var packed=_pack(edges,entry)
	if packed.size()!=edges.size()*13:return PackedFloat64Array()
	_scan_payload[0]=start.x;_scan_payload[1]=start.y;_scan_payload[2]=delta.x;_scan_payload[3]=delta.y;_scan_payload[4]=radius
	_scan_payload[5]=query.position.x;_scan_payload[6]=query.position.y;_scan_payload[7]=query.size.x;_scan_payload[8]=query.size.y
	var result:PackedFloat64Array=_kernel.call(&"scan",packed,_scan_payload)
	_queries+=1
	if result.size()!=2 or not is_finite(result[0]) or result[0]!=floor(result[0]) or result[0]< -1 or result[0]>=edges.size() or (result[0]>=0 and (not is_finite(result[1]) or result[1]<0 or result[1]>1)):
		_rejected+=1;return PackedFloat64Array()
	return result

func overlap(edges:Array,entry:Dictionary,point:Vector2,radius:float)->int:
	if not ready() or not _has_overlap:return -2
	if not _finite_vector(point) or not is_finite(radius) or radius<0 or radius>3.4028234663852886e38:
		_rejected+=1;return -2
	var packed=_pack(edges,entry)
	if packed.size()!=edges.size()*13:return -2
	_overlap_payload[0]=point.x;_overlap_payload[1]=point.y;_overlap_payload[2]=radius
	var result=_kernel.call(&"overlap",packed,_overlap_payload)
	_overlap_queries+=1
	if not result is int or result< -1 or result>=edges.size():
		_rejected+=1;return -2
	return result

func stats()->Dictionary:
	return {"attempted":_attempted,"loaded":_kernel!=null,"queries":_queries,"scanQueries":_queries,"overlapQueries":_overlap_queries,"packs":_packs,"payloadBuilds":_packs,"packed_values":_packed_values,"rejected":_rejected}
