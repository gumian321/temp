extends RefCounted
## Cosmetic world-space history. No particles, per-shot nodes, RNG or collision writes.
const Feedback = preload("res://scripts/weapon_feedback.gd")
const AttackShaders = preload("res://scripts/attack_shader_layer.gd")
const Viscous = preload("res://scripts/viscous_projectiles.gd")
const MAX_POINTS = 14
const MAX_TRACKED = 640
const MAX_REMNANTS = 64
const MAX_SEGMENTS = 7
const SAMPLE_INTERVAL = 1.0 / 60.0
const RETENTION = 0.20
const FADE_TIME = 0.16
const MAX_DISTANCE = 112.0
const PALETTES = {
	"mucus":Color("b9cd48"), "egg":Color("edb83b"),
	"larva":Color("e5bf81"), "tongue":Color("ecae98"),
	"repair_drone":Color("52dfb0"), "scrap_drone":Color("f7c56b"),
	"emp":Color("46ded5"), "blackhole":Color("ac81f5")}
static var strip_indices: Dictionary = {}
static var strip_uvs: Dictionary = {}
static var mesh_cache: Dictionary = {}
static var next_visual_id = 0
const MESH_INTERVAL = 1.0 / 30.0

static func make_state(shot: Dictionary, dt: float) -> Dictionary:
	next_visual_id += 1
	var points = PackedVector2Array(); points.resize(MAX_POINTS)
	var times = PackedFloat32Array(); times.resize(MAX_POINTS)
	points[0] = shot.get("previous", shot.position)
	var now = float(shot.get("age", dt))
	times[0] = maxf(0.0, now - dt)
	var key = str(shot.get("fx_family", "gatling"))
	var hostile = not bool(shot.get("friendly", true))
	var length = clampf(float(Feedback.profile(key).trail), 20.0, MAX_DISTANCE)
	if hostile: length = MAX_DISTANCE
	return {"visual_id":next_visual_id, "points":points, "times":times, "cursor":1, "count":1,
		"clock":now, "sample_time":times[0], "position":points[0], "head_time":now,
		"fx_family":key, "organic_family":Viscous.family(shot,key),
		"friendly":not hostile, "radius":float(shot.get("radius", 4.0)),
		"phase":float(shot.get("organic_phase", 0.0)), "max_distance":length, "life":FADE_TIME}

static func advance(shots: Array, remnants: Array, dt: float):
	if dt <= 0.0: return
	for i in range(remnants.size() - 1, -1, -1):
		var old: Dictionary = remnants[i]
		old.clock += dt; old.life -= dt
		if old.life <= 0.0: remnants.remove_at(i)
	var hostile_count=0
	for shot in shots:
		if not bool(shot.get("friendly",true)):hostile_count+=1
	var friendly_slots=maxi(0,MAX_TRACKED-hostile_count)
	var tracked = 0;var tracked_friendly=0
	for shot in shots:
		var friendly=bool(shot.get("friendly",true))
		if tracked >= MAX_TRACKED or (friendly and tracked_friendly>=friendly_slots):
			shot.erase("projectile_trail")
			continue
		tracked += 1
		if friendly:tracked_friendly+=1
		if not shot.has("projectile_trail"): shot.projectile_trail = make_state(shot, dt)
		var state: Dictionary = shot.projectile_trail
		state.clock = float(shot.get("age", float(state.clock) + dt))
		var next: Vector2 = shot.get("trail_contact", shot.position) if float(shot.get("life", 1.0)) <= 0 else shot.position
		record(state,next,float(state.clock))
		if float(shot.get("life", 1.0)) <= 0:
			# Only the compact visual state survives; never retain the shot/target.
			if remnants.size() >= MAX_REMNANTS: remnants.pop_front()
			remnants.append(state)
			shot.erase("projectile_trail")

static func record(state:Dictionary,next:Vector2,elapsed:float):
	state.clock=elapsed
	if next.distance_squared_to(state.position)>.0001:state.head_time=elapsed
	state.position=next
	var points:PackedVector2Array=state.points
	var last=points[(int(state.cursor)+MAX_POINTS-1)%MAX_POINTS]
	if elapsed-float(state.sample_time)>=SAMPLE_INTERVAL-.00001 and last.distance_squared_to(next)>.01:
		var times:PackedFloat32Array=state.times
		points[int(state.cursor)]=next;times[int(state.cursor)]=elapsed
		state.points=points;state.times=times
		state.cursor=(int(state.cursor)+1)%MAX_POINTS;state.count=mini(int(state.count)+1,MAX_POINTS)
		state.sample_time=elapsed

static func actor_family(actor:Dictionary)->String:
	var kind=str(actor.get("data",{}).get("class","ProjectileDrone"))
	return "repair_drone" if kind=="EngineerDrone" else ("scrap_drone" if kind=="Drone" else "drone")

static func advance_actors(actors:Array,dt:float):
	if dt<=0:return
	for actor in actors:
		if actor.get("docked",false):actor.erase("flight_trail");continue
		if not actor.has("flight_trail"):
			var key=actor_family(actor)
			var created=make_state({"position":actor.position,"fx_family":key,"friendly":actor.get("friendly",true),"radius":2.2,"organic_family":key},0.0)
			created.max_distance=72.0;actor.flight_trail=created
		var state:Dictionary=actor.flight_trail
		record(state,actor.position,float(state.clock)+dt)

## Actual past positions, newest first, clipped by both time and arc length.
static func path(state: Dictionary, distance_limit:float=-1.0) -> Dictionary:
	var points = PackedVector2Array([Vector2(state.position)])
	var ages = PackedFloat32Array([maxf(0.0, float(state.clock) - float(state.head_time))])
	var distance = 0.0
	var maximum=float(state.max_distance) if distance_limit<0 else minf(distance_limit,float(state.max_distance))
	var history: PackedVector2Array = state.points
	var times: PackedFloat32Array = state.times
	if ages[0] >= RETENTION: return {"points":points, "ages":ages, "length":0.0}
	for i in int(state.count):
		var index = (int(state.cursor) + MAX_POINTS - 1 - i) % MAX_POINTS
		var point = history[index]
		var age = maxf(0.0, float(state.clock) - float(times[index]))
		var segment = points[-1].distance_to(point)
		if segment < .001: continue
		var fraction = minf(1.0, (maximum - distance) / segment)
		if age > RETENTION:
			fraction = minf(fraction, maxf(0.0, (RETENTION - ages[-1]) / maxf(.00001, age - ages[-1])))
		if fraction <= 0.0: break
		points.append(points[-1].lerp(point, fraction))
		ages.append(lerpf(ages[-1], age, fraction))
		distance += segment * fraction
		if fraction < .9999: break
	return {"points":points, "ages":ages, "length":distance}

static func indices(segments: int) -> PackedInt32Array:
	if strip_indices.has(segments): return strip_indices[segments]
	var result = PackedInt32Array()
	for i in segments:
		for bank in 2:
			var a = i * 3 + bank; var b = a + 3
			result.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	strip_indices[segments] = result
	return result

static func paint(canvas, state: Dictionary, zoom: float, time: float, live:bool=false):
	if canvas is AttackShaders.Painter:
		paint_gpu(canvas,state,zoom,live)
		return
	var trail = path(state,42.0/maxf(.01,zoom) if not state.friendly else -1.0)
	if trail.length * zoom < 1.0: return
	var points: PackedVector2Array = trail.points
	var ages: PackedFloat32Array = trail.ages
	var hostile = not bool(state.friendly)
	var segments = clampi(ceili(float(trail.length) * zoom / 7.0), 4 if hostile else 3, MAX_SEGMENTS)
	var vertices = PackedVector2Array(); vertices.resize((segments + 1) * 3)
	var colors = PackedColorArray(); colors.resize(vertices.size())
	var kind = str(state.organic_family)
	var pigment: Color = Color("d82746") if hostile else PALETTES.get(kind, PALETTES.get(str(state.fx_family), PALETTES.mucus))
	var dark = pigment.darkened(.04)
	var width = (2.6 if kind == "larva" else 3.6) * clampf(float(state.radius) / 4.0, 1.0, 1.8) * zoom
	if hostile: width = maxf(1.2, 1.9 * zoom)
	var fade = clampf(float(state.life) / FADE_TIME, 0.0, 1.0)
	var section = 1; var travelled = 0.0
	for i in range(segments + 1):
		var t = float(i) / segments
		var target = float(trail.length) * t
		while section < points.size() - 1 and travelled + points[section - 1].distance_to(points[section]) < target:
			travelled += points[section - 1].distance_to(points[section]); section += 1
		var segment_length = points[section - 1].distance_to(points[section])
		var blend = clampf((target - travelled) / maxf(.001, segment_length), 0.0, 1.0)
		var at: Vector2 = canvas.world(points[section - 1].lerp(points[section], blend))
		var tangent = points[section] - points[section - 1]
		var normal = tangent.normalized().orthogonal()
		# Waves only deform the tail mesh. The head remains on the collision path.
		at += normal * sin(t * 10.0 - time * 18.0 + float(state.phase)) * sin(t * PI) * minf(1.8 * zoom, float(trail.length) * zoom * .06)
		var half_width = width * pow(1.0 - t, .82) * (.88 + .12 * sin(t * 14.0 - time * 21.0 + float(state.phase)))
		var age = lerpf(ages[section - 1], ages[section], blend)
		var alpha = .94 * (1.0 - t) * clampf(1.0 - age / RETENTION, 0.0, 1.0) * fade
		var cross_section = normal * half_width
		vertices[i * 3] = at - cross_section
		vertices[i * 3 + 1] = at - cross_section * .22
		vertices[i * 3 + 2] = at + cross_section
		colors[i * 3] = Color(dark, alpha)
		colors[i * 3 + 1] = Color(pigment, alpha)
		colors[i * 3 + 2] = Color(pigment, alpha)
	canvas.draw_set_transform(Vector2.ZERO)
	# One indexed strip avoids polygon triangulation failures at tight turns and
	# keeps all three pigment bands in one native draw command.
	if canvas is AttackShaders.Painter:
		canvas.draw_triangle_array(indices(segments), vertices, colors)
	elif canvas is Node2D:
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices(segments), vertices, colors)
	else:
		var outline = PackedVector2Array()
		for i in range(segments + 1): outline.append(vertices[i * 3])
		for i in range(segments, -1, -1): outline.append(vertices[i * 3 + 2])
		canvas.draw_colored_polygon(outline, Color(pigment, .6 * fade))

## Production sends only path centres and encoded normals. The shared shader
## expands, tapers and animates the strip, avoiding per-vertex CPU wave math.
static func paint_gpu(canvas, state: Dictionary, zoom: float, live:bool=false):
	var origin:Vector2=canvas.world(Vector2.ZERO)
	var scale_factor:float=origin.distance_to(canvas.world(Vector2.RIGHT))
	if scale_factor<.0001:return
	var mesh=prepare_gpu_mesh(state,zoom,scale_factor)
	if mesh.segments==0:return
	var layer=canvas.owner_layer
	if layer!=null and layer.use_flight_batch and layer.batch_flights_this_frame and not layer.trace_commands and state.organic_family not in ["repair_drone","scrap_drone","drone"]:
		if layer.flight_batch.enqueue(canvas,state,mesh,origin,scale_factor,{},"live_trail" if live else "remnant"):return
	# Cached past vertices stay fixed in world space. Only the head is refreshed
	# every frame, keeping the joint tucked inside even the fastest small body.
	var vertices:PackedVector2Array=mesh.vertices
	vertices[0]=state.position;vertices[1]=state.position;vertices[2]=state.position
	canvas.draw_set_transform(origin,0.0,Vector2.ONE*scale_factor)
	canvas.draw_triangle_array(indices(mesh.segments),vertices,mesh.colors,strip_uvs[mesh.uv_key])

static func prepare_gpu_mesh(state:Dictionary,zoom:float,scale_factor:float)->Dictionary:
	var width_scale=zoom/scale_factor
	var distance_limit=42.0/maxf(.01,zoom) if not state.friendly else -1.0
	var id=int(state.visual_id)
	# Alternate rebuild frames across shots instead of rebuilding a burst together.
	var bucket=int(floor((float(state.clock)+float(id%2)*SAMPLE_INTERVAL+.00001)/MESH_INTERVAL))
	var mesh:Dictionary=mesh_cache.get(id,{})
	if mesh.is_empty() or bucket!=int(mesh.bucket) or (mesh.segments==0 and Vector2(mesh.head).distance_squared_to(state.position)>.01) or not is_equal_approx(width_scale,float(mesh.width_scale)) or not is_equal_approx(distance_limit,float(mesh.distance_limit)):
		mesh=build_mesh(state,width_scale,distance_limit)
		mesh.bucket=bucket
		if not mesh_cache.has(id) and mesh_cache.size()>=MAX_TRACKED+MAX_REMNANTS:mesh_cache.erase(mesh_cache.keys()[0])
		mesh_cache[id]=mesh
	return mesh

static func build_mesh(state:Dictionary,width_scale:float,distance_limit:float=-1.0)->Dictionary:
	var trail=path(state,distance_limit)
	var mesh={"clock":state.clock,"width_scale":width_scale,"distance_limit":distance_limit,"segments":0,"head":state.position}
	if trail.length<.1:return mesh
	var points: PackedVector2Array = trail.points
	var ages: PackedFloat32Array = trail.ages
	var hostile = not bool(state.friendly)
	var segments = mini(points.size()-1, MAX_SEGMENTS)
	var vertices = PackedVector2Array(); vertices.resize((segments+1)*3)
	var colors = PackedColorArray(); colors.resize(vertices.size())
	var width = (2.6 if state.organic_family=="larva" else 3.6) * clampf(float(state.radius)/4.0,1.0,1.8)*width_scale
	if hostile:width=1.9*width_scale
	var fade = clampf(float(state.life)/FADE_TIME,0.0,1.0)
	var previous = points[0]
	for i in range(segments+1):
		var index = int(float(i)*(points.size()-1)/segments)
		var next_index = int(float(mini(i+1,segments))*(points.size()-1)/segments)
		var tangent = points[next_index]-previous
		if tangent.length_squared()<.00001:tangent=Vector2.LEFT
		var normal = tangent.normalized().orthogonal()*width/16.0
		var at:Vector2=points[index]
		var encoded=Color(.5+normal.x,.5+normal.y,float(state.phase),clampf(1.0-ages[index]/RETENTION,0.0,1.0)*fade)
		var base=i*3
		vertices[base]=at;vertices[base+1]=at;vertices[base+2]=at
		colors[base]=encoded;colors[base+1]=encoded;colors[base+2]=encoded
		previous=points[index]
	var uv_key=segments*2+int(hostile)
	if not strip_uvs.has(uv_key):
		var uvs=PackedVector2Array();uvs.resize(vertices.size())
		var flag=3.0 if hostile else 2.0
		for i in range(segments+1):
			var t=float(i)/segments
			uvs[i*3]=Vector2(t,flag);uvs[i*3+1]=Vector2(t,flag+.39);uvs[i*3+2]=Vector2(t,flag+.999)
		strip_uvs[uv_key]=uvs
	mesh.vertices=vertices;mesh.colors=colors;mesh.segments=segments;mesh.uv_key=uv_key
	return mesh

static func paint_shot(canvas, shot: Dictionary, zoom: float, time: float):
	var state: Dictionary = shot.get("projectile_trail", {})
	if state.is_empty():
		# Isolated previews can show only their real previous/current segment.
		# Never invent a straight origin-to-head tail across a homing turn.
		if not shot.has("previous"): return
		state = make_state(shot, SAMPLE_INTERVAL)
		state.position = shot.position
	paint(canvas, state, zoom, time,true)

## Crowded friendly volleys retain a lightweight curved, fading trail.
static func paint_simple(canvas,shot:Dictionary,zoom:float):
	var state:Dictionary=shot.get("projectile_trail",{})
	if state.is_empty():return
	var trail=path(state)
	if trail.length*zoom<1.0:return
	var samples:PackedVector2Array=trail.points
	var middle=samples[0].lerp(samples[-1],.5) if samples.size()==2 else samples[(samples.size()-1)/2]
	var points=PackedVector2Array([canvas.world(samples[0]),canvas.world(middle),canvas.world(samples[-1])])
	var pigment:Color=PALETTES.get(str(state.organic_family),PALETTES.get(str(state.fx_family),PALETTES.mucus))
	var colors=PackedColorArray([Color(pigment,.48),Color(pigment,.22),Color(pigment,0)])
	canvas.draw_set_transform(Vector2.ZERO)
	if canvas is AttackShaders.Painter or canvas is Node2D:
		canvas.draw_polyline_colors(points,colors,maxf(.7,1.8*zoom),true)
	else:canvas.draw_polyline(points,Color(pigment,.3),maxf(.7,1.8*zoom),true)
