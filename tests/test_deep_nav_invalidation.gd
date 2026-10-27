extends SceneTree
const World=preload("res://scripts/cave_world.gd")
const Contours=preload("res://scripts/cave_contour_mesh.gd")
class FragileWorld extends World:
	func blocked(point:Vector2,radius:float=0.0)->bool:
		if point==Vector2(24,24):return radius>32.0
		if point==Vector2(72,24):return false
		return super.blocked(point,radius)
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func area(polygon:PackedVector2Array)->float:
	if polygon.size()<3:return 0.0
	# Vector2.cross returns real_t (float32 in this build). Summing its already
	# rounded world-coordinate products gave 2^-13 area to zero-width slivers.
	# Triangulate around one vertex and keep every product in scalar float64.
	var origin=polygon[0]
	var sum=0.0
	for i in range(1,polygon.size()-1):
		var ax=float(polygon[i].x)-float(origin.x);var ay=float(polygon[i].y)-float(origin.y)
		var bx=float(polygon[i+1].x)-float(origin.x);var by=float(polygon[i+1].y)-float(origin.y)
		sum+=ax*by-ay*bx
	return absf(sum)*.5
func distance_to_polygon(point:Vector2,polygon:PackedVector2Array)->float:
	# Independent scalar half-plane/segment check records actual geometric
	# escape, even when Clipper returns a degenerate boundary difference.
	var closest=INF;var positive=false;var negative=false
	for i in polygon.size():
		var a=polygon[i];var b=polygon[(i+1)%polygon.size()]
		var dx=float(b.x)-float(a.x);var dy=float(b.y)-float(a.y)
		var px=float(point.x)-float(a.x);var py=float(point.y)-float(a.y)
		var cross_value=dx*py-dy*px
		positive=positive or cross_value>0.0;negative=negative or cross_value<0.0
		var length_squared=dx*dx+dy*dy
		var t=clampf((px*dx+py*dy)/length_squared,0.0,1.0) if length_squared>0.0 else 0.0
		var ex=px-t*dx;var ey=py-t*dy
		closest=minf(closest,sqrt(ex*ex+ey*ey))
	return closest if positive and negative else 0.0
func distance_to_union(point:Vector2,polygons:Array)->float:
	var closest=INF
	for polygon in polygons:closest=minf(closest,distance_to_polygon(point,polygon))
	return closest
func overlap_union(world,point:Vector2,radius:float,pieces:Array)->bool:
	for piece in pieces:
		if world.contains(piece,point,radius):return true
	return false
func polygon_bounds(polygon:PackedVector2Array)->Rect2:
	var result=Rect2(polygon[0],Vector2.ZERO)
	for point in polygon:result=result.expand(point)
	return result
func verify_shrinking_templates()->Dictionary:
	var shapes:Array=[];var boxes:Array=[]
	# Include a negative cell exactly next to a chunk seam. Use the actual
	# jittered world mapping, then translate for stable clipping-area arithmetic.
	var world=World.new();world.reset_cave(true,20261026)
	var cell=Vector2i(-17,9)
	var corners=PackedVector2Array([world.vertex(cell),world.vertex(cell+Vector2i.RIGHT),world.vertex(cell+Vector2i.ONE),world.vertex(cell+Vector2i.DOWN)])
	for mask in 512:
		var transformed:Array=[];var bounds:Array=[]
		for polygon in Contours.fractured_template(mask,cell,20261026).pieces:
			var points=PackedVector2Array()
			for point in polygon:points.append(world.project_contour(point,corners)-corners[0])
			transformed.append(points);bounds.append(polygon_bounds(points))
		shapes.append(transformed);boxes.append(bounds)
	var coordinate_magnitude=0.0
	for corner in corners:coordinate_magnitude=maxf(coordinate_magnitude,maxf(absf(corner.x),absf(corner.y)))
	var world_ulp=pow(2.0,floor(log(coordinate_magnitude)/log(2.0))-23.0)
	# Comparing two independently rounded Vector2 boundaries allows one ULP
	# per coordinate on each boundary. Area of a thin residual is not a stable
	# pass criterion: a long zero-resolved-width edge can have measurable area.
	var resolution=2.0*sqrt(2.0)*world_ulp
	var transitions=0;var escaped=0;var worst=0.0;var max_distance=0.0;var max_input_distance=0.0;var worst_case={};var distance_case={};var input_case={}
	for mask in 512:
		for bit in 9:
			if (mask&(1<<bit))==0:continue
			var smaller=mask&~(1<<bit);transitions+=1
			for index in shapes[smaller].size():
				for point in shapes[smaller][index]:
					var input_distance=distance_to_union(point,shapes[mask])
					if input_distance>max_input_distance:
						max_input_distance=input_distance;input_case={"mask":mask,"removed_bit":bit,"piece":index,"point":point,"distance":input_distance}
				var remaining:Array=[shapes[smaller][index]]
				for before in shapes[mask].size():
					if not Rect2(boxes[mask][before]).grow(.0001).intersects(boxes[smaller][index]):continue
					var next:Array=[]
					for piece in remaining:next.append_array(Geometry2D.clip_polygons(piece,shapes[mask][before]))
					remaining=next
					if remaining.is_empty():break
				var outside=0.0
				for piece in remaining:
					outside+=area(piece)
					for point in piece:
						var distance=distance_to_union(point,shapes[mask])
						if distance>max_distance:
							max_distance=distance;distance_case={"mask":mask,"removed_bit":bit,"piece":index,"point":point,"distance":distance}
				if outside>worst:
					worst=outside;worst_case={"mask":mask,"removed_bit":bit,"piece":index,"area":outside,"remaining":remaining}
				for piece in remaining:
					for point in piece:
						if distance_to_union(point,shapes[mask])>resolution:escaped+=1
	var tangent_probes=0;var tangent_flips=0;var resolved_tangent_flips=0;var guarded_tangent_flips=0;var max_tangent_gap=0.0;var tangent_case={}
	# Probe actual contains predicates on both sides of the old boundaries,
	# including the two worst residual examples rather than trusting clipping.
	for transition in [[120,3],[11,0]]:
		var mask:int=transition[0];var smaller=mask&~(1<<int(transition[1]))
		var before_pieces:Array=[];var after_pieces:Array=[]
		for polygon in shapes[mask]:before_pieces.append(world.cave_piece(polygon))
		for polygon in shapes[smaller]:after_pieces.append(world.cave_piece(polygon))
		for piece in before_pieces:
			for i in piece.polygon.size():
				var mid=Vector2(piece.polygon[i]).lerp(piece.polygon[(i+1)%piece.polygon.size()],.5)
				for radius in [0.0,8.0,16.0,32.0,64.0,128.0]:
					for offset in [-2.0,-1.0,-.25,0.0,.25,1.0,2.0]:
						var point=mid+Vector2(piece.normals[i])*(radius+offset*resolution)
						tangent_probes+=1
						if overlap_union(world,point,radius,before_pieces) or not overlap_union(world,point,radius,after_pieces):continue
						tangent_flips+=1
						var coordinate=maxf(absf(point.x),absf(point.y))+radius+World.CELL*2.0+coordinate_magnitude
						if not overlap_union(world,point,radius+maxf(.0001,coordinate*.0000005),before_pieces):guarded_tangent_flips+=1
						var gap=distance_to_union(point,shapes[mask])-radius
						if gap>max_tangent_gap:max_tangent_gap=gap;tangent_case={"mask":mask,"removed_bit":transition[1],"radius":radius,"point":point,"gap":gap}
						if gap>resolution:resolved_tangent_flips+=1
	return {"transitions":transitions,"resolved_escaped_vertices":escaped,"float32_world_ulp":world_ulp,"boundary_resolution":resolution,"max_outside_area":worst,"max_outside_distance":max_distance,"max_input_outside_distance":max_input_distance,"worst_area_case":worst_case,"worst_distance_case":distance_case,"worst_input_distance_case":input_case,"tangent_probes":tangent_probes,"tangent_clear_to_blocked":tangent_flips,"resolved_tangent_clear_to_blocked":resolved_tangent_flips,"guarded_tangent_clear_to_blocked":guarded_tangent_flips,"max_tangent_clear_gap":max_tangent_gap,"worst_tangent_case":tangent_case}
func prepare(world,radius:int):
	var data=world.navigation(Vector2(760,0),radius)
	world.nav_budget_active=false;world.prepare_navigation(data,Vector2.ZERO,Vector2(760,0),4)
	return data
func execute():
	var monotonic=verify_shrinking_templates()
	check(monotonic.resolved_escaped_vertices==0 and monotonic.max_input_outside_distance<=monotonic.boundary_resolution,"All 2304 deletion transitions remain within float32/Clipper boundary resolution; residual areas and original-vertex distances are reported")
	check(monotonic.resolved_tangent_clear_to_blocked==0,"Fresh tangent circle predicates have no regression beyond the measured float32 boundary resolution; all sub-resolution flips remain explicit in the report")
	check(monotonic.guarded_tangent_clear_to_blocked==0,"Expanded clear certificates exclude every measured fresh tangent predicate flip")
	var old=World.new();old.reset_cave(true);old.use_local_nav_invalidation=false;old.use_material_certificates=false;old.use_clearance_cache=false
	var current=World.new();current.reset_cave(true);current.use_material_certificates=false;current.use_clearance_cache=false
	var clear_before:Dictionary={}
	for radius in [16,32,64,128]:
		var data=prepare(current,radius);prepare(old,radius)
		var open:Array=[]
		for id in data.filled:
			if not data.grid.is_point_solid(id) and current.nav_clear_certificates.get(Vector3i(id.x,id.y,radius),false):open.append(id)
		clear_before[radius]=open
	var hit=old.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
	var head:Vector2=hit.position+hit.normal*.4
	var same=true;var probes=0
	for tick in 240:
		for world in [old,current]:world.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
		var expected=old.move(head,head+Vector2.RIGHT*2.2,28)
		same=same and expected==current.move(head,head+Vector2.RIGHT*2.2,28);head=expected
		if tick%40==39:
			for radius in [16,32,64,128]:
				# Every cache entry, including retained clear circles, is checked
				# against the fresh geometric predicate, never old nav_open.
				for key:Vector3i in current.nav_open.keys():
					if key.z!=radius:continue
					var center=(Vector2(key.x,key.y)+Vector2.ONE*.5)*World.NAV_STEP
					var expected_clear=not old.blocked(center,radius)
					same=same and bool(current.nav_open[key])==expected_clear;probes+=1
				prepare(old,radius);prepare(current,radius)
	check(same and current.removed_count>0,"Cached clearance matches direct post-excavation geometry across radii, seams and repeated bites")
	var clear_retained=true
	for radius in clear_before:
		var data=current.nav_grids[radius]
		for id in clear_before[radius]:clear_retained=clear_retained and data.filled.has(id) and not data.grid.is_point_solid(id)
	check(clear_retained and current.nav_invalidation_clear_kept>0,"Previously verified open routes with a robust clearance margin remain open while rock is removed")
	check(current.nav_invalidation_cells<old.nav_invalidation_cells,"Only affected blocked footprints are reopened for clearance checks")
	var fragile=FragileWorld.new();fragile.reset_cave(true)
	var data=fragile.navigation(Vector2.ZERO,32)
	for id in [Vector2i.ZERO,Vector2i.RIGHT]:
		fragile.nav_passable(id,32);data.filled[id]=true;data.grid.set_point_solid(id,false)
	fragile.invalidate_navigation_excavation(Rect2i(-1,-1,5,4))
	check(not data.filled.has(Vector2i.ZERO) and not fragile.nav_open.has(Vector3i(0,0,32)) and data.filled.has(Vector2i.RIGHT) and not data.grid.is_point_solid(Vector2i.RIGHT),"A fragile exact-clear tangent is dirtied while an adjacent robust clear circle remains available")
	# An external invalidation without a dig context may represent additions.
	# It must retain the old conservative behavior and invalidate clear cells.
	var center=Vector2(24,24);var id=Vector2i.ZERO
	for world in [old,current]:
		for y in range(0,3):
			for x in range(0,3):
				var cell=Vector2i(x,y);world.chunk_at(world.chunk_id(cell)).solid[world.cell_index(cell)]=1
		world.geometry.clear();world.collision_rows.clear();world.sweep_neighborhoods.clear();world.sweep_neighborhood_order.clear();world.clear_points.clear();world.clear_point_count=0;world.free_regions.clear();world.blocked_free_regions.clear();world.revision+=1
		world.invalidate_navigation(center,0)
	check(not current.nav_grids[32].filled.has(id) and not current.nav_passable(id,32) and old.blocked(center,32),"Unknown/additive edits use conservative public invalidation instead of retained clear certificates")
	current.reset_cave(true,7)
	check(current.nav_grids.is_empty() and current.nav_open.is_empty() and current.nav_clear_certificates.is_empty() and not current.navigation_dirty_cells.has_area() and current.nav_invalidation_cells==0,"Seed reset clears all clearance metadata and invalidation counters")
	var passed=checks.all(func(c):return c.passed)
	var report={"passed":passed,"checks":checks,"monotonic_templates":monotonic,"fresh_geometry_probes":probes,"legacy_invalidated":old.nav_invalidation_cells}
	print(JSON.stringify(report));FileAccess.open("res://artifacts/deep-nav-invalidation-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if passed else 1)
