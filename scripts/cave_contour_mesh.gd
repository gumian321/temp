extends RefCounted
## Positive quadratic filtering turns the excavation mask into a continuous
## material field. Removing rock can only shrink it. The same cached convex
## pieces and contour segments feed drawing and swept circle collisions.
const SUBDIVISIONS = 4
const ISO = 0.5
static var templates: Dictionary = {}
static var samples: Dictionary = {}
static var fractures: Dictionary = {}
static var extrema:Dictionary={}
static var cell_biases:Dictionary={}
const FRACTURED_TEMPLATE_LIMIT=8192
static var use_fractured_templates=OS.get_environment("RBPEW_LEGACY_FRACTURED_TEMPLATES")!="1"
static var fractured_templates:Dictionary={}
static var fractured_template_ring:Array[Vector4i]=[]
static var fractured_template_cursor=0
static var fractured_template_hits=0
static var fractured_template_misses=0
static var fractured_template_builds=0
static var fractured_template_build_us=0
static var fractured_template_evicts=0
static var fractured_template_seed_fallbacks=0

static func clear_fractured_cache(reset_stats:bool=true):
	fractured_templates.clear();fractured_template_ring.clear();fractured_template_cursor=0
	if reset_stats:
		fractured_template_hits=0;fractured_template_misses=0;fractured_template_builds=0
		fractured_template_build_us=0;fractured_template_evicts=0;fractured_template_seed_fallbacks=0

static func cache_stats()->Dictionary:
	return {"enabled":use_fractured_templates,"hits":fractured_template_hits,"misses":fractured_template_misses,"builds":fractured_template_builds,"build_us":fractured_template_build_us,"evicts":fractured_template_evicts,"entries":fractured_templates.size(),"capacity":FRACTURED_TEMPLATE_LIMIT,"seed_fallbacks":fractured_template_seed_fallbacks}

static func weights(at: float) -> Vector3:
	var t = at - 0.5
	return Vector3(0.5 * (0.5 - t) * (0.5 - t), 0.75 - t * t, 0.5 * (0.5 + t) * (0.5 + t))

static func density(mask: int, at: Vector2) -> float:
	var wx = weights(at.x); var wy = weights(at.y)
	var result = 0.0
	for y in 3:
		for x in 3:
			if mask & (1 << (y * 3 + x)): result += wx[x] * wy[y]
	return result

static func append_piece(pieces: Array, outline: PackedVector2Array, raw: Array, cuts: Array):
	var polygon = PackedVector2Array(); var marks: Array = []
	for i in raw.size():
		if polygon.is_empty() or polygon[-1].distance_squared_to(raw[i]) > 0.0000000001:
			polygon.append(raw[i]); marks.append(cuts[i])
		else: marks[-1] = marks[-1] or cuts[i]
	if polygon.size() > 1 and polygon[0].distance_squared_to(polygon[-1]) < 0.0000000001:
		marks[0] = marks[0] or marks[-1]; polygon.resize(polygon.size() - 1); marks.pop_back()
	if polygon.size() < 3: return
	var area = 0.0
	for i in polygon.size(): area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	if area < 0.00000001: return
	pieces.append(polygon)
	for i in polygon.size():
		var next = (i + 1) % polygon.size()
		if marks[i] and marks[next]: outline.append(polygon[i]); outline.append(polygon[next])

static func density_samples(mask: int) -> PackedFloat32Array:
	if samples.has(mask): return samples[mask]
	var nodes = PackedFloat32Array()
	for y in range(SUBDIVISIONS + 1):
		for x in range(SUBDIVISIONS + 1): nodes.append(density(mask, Vector2(x, y) / SUBDIVISIONS))
	samples[mask] = nodes
	var low:float=1.0;var high:float=0.0
	for value:float in nodes:low=minf(low,value);high=maxf(high,value)
	extrema[mask]=Vector2(low,high)
	return nodes

static func grain(at: Vector2i, seed_value: int, salt: int) -> float:
	var n = absi((at.x * 73856093) ^ (at.y * 19349663) ^ (seed_value * 83492791) ^ salt)
	return float(n % 65521) / 32760.0 - 1.0

static func fracture_bias(node: Vector2i, seed_value: int) -> float:
	var key = Vector3i(node.x, node.y, seed_value)
	if fractures.has(key): return fractures[key]
	var sample_at = Vector2(node) / 3.0
	var low = Vector2i(sample_at.floor()); var fraction = sample_at - Vector2(low)
	# Faceted variation over 18px, smaller grain over 6px, and occasional chips.
	# This field is fixed in world space, so excavation never re-rolls an edge.
	var upper = lerpf(grain(low, seed_value, 3137), grain(low + Vector2i.RIGHT, seed_value, 3137), fraction.x)
	var lower = lerpf(grain(low + Vector2i.DOWN, seed_value, 3137), grain(low + Vector2i.ONE, seed_value, 3137), fraction.x)
	var bias = lerpf(upper, lower, fraction.y) * 0.065 + grain(node, seed_value, 9173) * 0.024
	if grain(node, seed_value, 17669) > 0.90: bias -= 0.04
	# A lone material sample has density 0.5625 at its center, and a removed
	# sample at most 0.4375. Keep both centers on their original side of ISO.
	bias = clampf(bias, -0.055, 0.055)
	if fractures.size() >= 49152:
		var oldest = fractures.keys()
		for i in 512: fractures.erase(oldest[i])
	fractures[key] = bias
	return bias

static func fractured_template(mask: int, cell: Vector2i, seed_value: int) -> Dictionary:
	if not use_fractured_templates:return fractured_template_legacy(mask,cell,seed_value)
	if mask in [0, 511]: return template(mask)
	# Vector4i stores 32-bit components. Preserve the existing full-int seed
	# path for unusual seeds rather than adding aliases to the final-result
	# cache. The older bias-cache seed truncation remains outside this change.
	if seed_value< -2147483648 or seed_value>2147483647 or mask<0 or mask>511:
		fractured_template_seed_fallbacks+=1
		return fractured_template_legacy(mask,cell,seed_value)
	var source_nodes=density_samples(mask)
	var limits:Vector2=extrema[mask]
	# Do not allocate/copy 25 samples for an inexpensive constant result.
	if limits.x>=ISO+.055:return template(511)
	if limits.y<ISO-.055:return template(0)
	var result_key=Vector4i(cell.x,cell.y,seed_value,mask)
	if fractured_templates.has(result_key):fractured_template_hits+=1;return fractured_templates[result_key]
	fractured_template_misses+=1
	var nodes=source_nodes.duplicate()
	var began=Time.get_ticks_usec()
	var key=Vector3i(cell.x,cell.y,seed_value)
	if not cell_biases.has(key):
		var bias=PackedFloat64Array()
		for y in range(SUBDIVISIONS+1):
			for x in range(SUBDIVISIONS+1):bias.append(fracture_bias(cell*SUBDIVISIONS+Vector2i(x,y),seed_value))
		if cell_biases.size()>=2048:
			var oldest=cell_biases.keys()
			for i in 64:cell_biases.erase(oldest[i])
		cell_biases[key]=bias
	var bias:PackedFloat64Array=cell_biases[key]
	for i in nodes.size():nodes[i]+=bias[i]
	# Results use the same immutable shared-return contract as template(mask).
	# Production callers only read local points and create new world polygons.
	var result=build_template(mask,nodes,true)
	fractured_template_build_us+=Time.get_ticks_usec()-began;fractured_template_builds+=1
	if fractured_template_ring.size()==FRACTURED_TEMPLATE_LIMIT:
		fractured_templates.erase(fractured_template_ring[fractured_template_cursor])
		fractured_template_ring[fractured_template_cursor]=result_key
		fractured_template_cursor=(fractured_template_cursor+1)%FRACTURED_TEMPLATE_LIMIT
		fractured_template_evicts+=1
	else:fractured_template_ring.append(result_key)
	fractured_templates[result_key]=result
	return result

static func fractured_template_legacy(mask:int,cell:Vector2i,seed_value:int)->Dictionary:
	if mask in [0,511]:return template(mask)
	var nodes = density_samples(mask).duplicate()
	# The fixed fracture bias is clamped to +/- .055. Most neighbors of a bite
	# remain entirely full/empty even at that limit; keep their exact quad/empty
	# result without rebuilding a 4x4 marching template.
	var limits:Vector2=extrema[mask]
	if limits.x>=ISO+.055:return template(511)
	if limits.y<ISO-.055:return template(0)
	fractured_template_misses+=1
	var began=Time.get_ticks_usec()
	var key=Vector3i(cell.x,cell.y,seed_value)
	if not cell_biases.has(key):
		var bias=PackedFloat64Array()
		for y in range(SUBDIVISIONS+1):
			for x in range(SUBDIVISIONS+1):bias.append(fracture_bias(cell*SUBDIVISIONS+Vector2i(x,y),seed_value))
		if cell_biases.size()>=2048:
			var oldest=cell_biases.keys()
			for i in 64:cell_biases.erase(oldest[i])
		cell_biases[key]=bias
	var bias:PackedFloat64Array=cell_biases[key]
	for i in nodes.size():nodes[i]+=bias[i]
	var result=build_template(mask,nodes,true)
	fractured_template_build_us+=Time.get_ticks_usec()-began;fractured_template_builds+=1
	return result

static func template(mask: int) -> Dictionary:
	if templates.has(mask): return templates[mask]
	var result = build_template(mask, density_samples(mask))
	templates[mask] = result
	return result

static func build_template(mask: int, nodes: PackedFloat32Array, fractured: bool = false) -> Dictionary:
	var pieces: Array = []; var outline = PackedVector2Array()
	if mask == 511:
		pieces.append(PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]))
	elif mask != 0:
		var lowest:float = 1.0; var highest:float = 0.0
		for value:float in nodes: lowest = minf(lowest, value); highest = maxf(highest, value)
		if lowest >= ISO:
			pieces.append(PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]))
			var border: PackedVector2Array = pieces[0]
			for i in 4:
				var a = border[i]; var b = border[(i + 1) % 4]
				var normal = Vector2((b - a).y, -(b - a).x).normalized()
				var middle = a.lerp(b, 0.5)
				if not fractured and absf(density(mask, middle) - ISO) < 0.000001 and density(mask, middle + normal * 0.0001) < ISO:
					outline.append(a); outline.append(b)
		elif highest >= ISO:
			for y in SUBDIVISIONS:
				for x in SUBDIVISIONS:
					var low:Vector2 = Vector2(x, y) / SUBDIVISIONS
					var size:float = 1.0 / SUBDIVISIONS
					var points:Array[Vector2] = [low, low + Vector2(size, 0), low + Vector2.ONE * size, low + Vector2(0, size)]
					var start:int = y * (SUBDIVISIONS + 1) + x
					var values = [nodes[start], nodes[start + 1], nodes[start + SUBDIVISIONS + 2], nodes[start + SUBDIVISIONS + 1]]
					var code:int = 0
					for i in 4:
						if values[i] >= ISO: code |= 1 << i
					if code == 0: continue
					# Interior sub-quads have no cut marks or boundary edges. Keep
					# the exact same four vertices without polygon cleanup/area tests.
					if code==15 and minf(minf(values[0],values[1]),minf(values[2],values[3]))>ISO+.000001:
						pieces.append(PackedVector2Array(points));continue
					var crossings: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
					for i in 4:
						var next = (i + 1) % 4
						if (values[i] >= ISO) != (values[next] >= ISO):
							crossings[i] = points[i].lerp(points[next], (ISO - values[i]) / (values[next] - values[i]))
					var center_value = (values[0] + values[1] + values[2] + values[3]) * 0.25 if fractured else density(mask, low + Vector2.ONE * size * 0.5)
					if code in [5, 10] and center_value < ISO:
						for i in 4:
							if code & (1 << i): append_piece(pieces, outline, [crossings[(i + 3) % 4], points[i], crossings[i]], [true, false, true])
					else:
						var raw: Array = []; var cuts: Array = []
						for i in 4:
							if code & (1 << i): raw.append(points[i]); cuts.append(absf(values[i] - ISO) < 0.000001)
							if (values[i] >= ISO) != (values[(i + 1) % 4] >= ISO): raw.append(crossings[i]); cuts.append(true)
						append_piece(pieces, outline, raw, cuts)
	return {"pieces": pieces, "outline": outline}
