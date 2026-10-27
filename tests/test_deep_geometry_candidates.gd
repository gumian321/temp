extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Segmented=preload("res://tools/deep_segmented_geometry_world.gd")
const Capacity=preload("res://tools/deep_capacity_geometry_world.gd")
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func signature(shape:Dictionary)->Array:
	var result:Array=[shape.outline]
	for piece in shape.pieces:result.append([piece.polygon,piece.normals,piece.bounds,piece.miter])
	return result
func execute():
	var raw=World.new();raw.reset_cave(true,20261026)
	var segmented=Segmented.new();segmented.reset_cave(true,20261026)
	var capacity=Capacity.new();capacity.reset_cave(true,20261026)
	capacity.geometry_capacity=32768;capacity.collision_row_capacity=4096
	var equal=true;var comparisons=0
	for y in range(-20,21):
		for x in range(-25,26):
			var cell=Vector2i(x*3-1,y*3+1)
			var expected=signature(raw.cell_shape(cell))
			equal=equal and expected==signature(segmented.cell_shape(cell)) and expected==signature(capacity.cell_shape(cell));comparisons+=2
	check(equal,"Both capacity-only and segmented candidates preserve exact seeded polygon/normal/outline arrays")
	var outline=PackedVector2Array()
	var actual_shape=raw.cell_shape(Vector2i(40,40))
	if actual_shape.pieces.is_empty():actual_shape={"pieces":[raw.cave_piece(PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE]))],"outline":outline}
	# Exercise cache ownership directly with one immutable real geometry value.
	# This isolates bookkeeping from tens of thousands of contour allocations.
	segmented.geometry.clear();segmented.clear_geometry_slots()
	for i in 10000:segmented.store_segmented_geometry(Vector2i(100000+i,0),actual_shape)
	for i in 10000:segmented.store_segmented_geometry(Vector2i(200000+i,0),World.empty_shape)
	var retained=true
	for i in 10000:retained=retained and segmented.geometry.has(Vector2i(100000+i,0))
	check(retained and segmented.geometry.size()<=12000 and segmented.empty_slots.size()<=2048,"A 10000-polygon working set survives 10000 empty insertions within the unchanged total 12000-cell budget")
	var protected_key=Vector2i(209999,0)
	segmented.geometry.erase(protected_key);segmented.store_segmented_geometry(protected_key,actual_shape)
	for i in 2300:segmented.store_segmented_geometry(Vector2i(300000+i,0),World.empty_shape)
	check(segmented.geometry.has(protected_key) and segmented.polygon_slots.has(protected_key) and not segmented.empty_slots.has(protected_key),"Reclassified keys cannot be erased by stale empty-ring slots after a complete wrap")
	segmented.geometry.clear();segmented.cell_shape(Vector2i(5,5))
	check(segmented.empty_ring.size()+segmented.polygon_ring.size()==1,"Public geometry.clear resets slot ownership before any new entry is admitted")
	segmented.geometry.clear();segmented.clear_geometry_slots()
	for i in 12300:segmented.store_segmented_geometry(Vector2i(i,1234),actual_shape)
	var ownership=true
	for key in segmented.polygon_slots:ownership=ownership and segmented.polygon_ring[segmented.polygon_slots[key]]==key and segmented.geometry.has(key)
	check(ownership and segmented.geometry.size()==12000 and segmented.polygon_slots.size()==12000 and segmented.polygon_ring.size()==12000,"Polygon-only pressure retains the original 12000 bound with unique current reverse ownership")
	var pressure_geometry=segmented.geometry.size();var empty_evictions=segmented.segmented_empty_evictions;var polygon_evictions=segmented.segmented_polygon_evictions
	segmented.reset_cave(true,7)
	check(segmented.geometry.is_empty() and segmented.empty_slots.is_empty() and segmented.polygon_slots.is_empty() and segmented.empty_ring.is_empty() and segmented.polygon_ring.is_empty(),"Seed reset clears all segmented keys, slots and counters")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"shape_comparisons":comparisons,"pressure_geometry":pressure_geometry,"empty_evictions":empty_evictions,"polygon_evictions":polygon_evictions}
	print(JSON.stringify(report));FileAccess.open("res://artifacts/deep-geometry-candidates-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if report.passed else 1)
