extends RefCounted
## Original AI-generated cutouts; animation only transforms the painted raster.
static var textures: Dictionary = {}

static func portrait(id: String) -> Texture2D:
	if not id in ["centipede", "spider", "beetle"]: id = "centipede"
	if textures.has(id): return textures[id]
	var path = "res://assets/characters/%s.png" % id
	if not ResourceLoader.exists(path): return null
	textures[id] = load(path)
	return textures[id]

static func draw_body(canvas: CanvasItem, player, at: Vector2, zoom: float, _clock: float):
	var id: String = player.character_id
	if id == "centipede": return
	var texture = portrait(id)
	if texture == null: return
	var size = Vector2(180, 180) if id == "spider" else Vector2(174, 124)
	var activity = clampf(float(player.motion.activity), 0.0, 1.0)
	var phase = float(player.motion.elapsed) * 11.0
	var rotation = PI * 0.5 if id == "spider" else 0.0
	canvas.draw_set_transform(at, player.facing.angle() + rotation, Vector2.ONE * zoom)
	# Texture-grid deformation moves only the outer limb bands. Carapace pixels
	# remain stable; gait follows simulation time and stops when paused/idle.
	for row in range(10):
		for column in range(10):
			var points = PackedVector2Array()
			var uv = PackedVector2Array()
			for corner in [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)]:
				var unit = (Vector2(column, row) + corner) / 10.0
				uv.append(unit)
				var point = (unit - Vector2(0.5, 0.5)) * size
				var lateral = point.x if id == "spider" else point.y
				var along = point.y if id == "spider" else point.x
				var band = smoothstep(26.0, 66.0 if id == "spider" else 53.0, absf(lateral))
				var bend = sin(phase + along * 0.105 + (PI if lateral < 0 else 0.0)) * band * activity
				if id == "spider": point += Vector2(bend * 1.2, bend * 3.5)
				else: point += Vector2(bend * 2.6, bend * 1.1)
				points.append(point)
			canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), uv, texture)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_skill(canvas: CanvasItem, player, state: Dictionary, at: Vector2, zoom: float, clock: float):
	clock = float(player.motion.elapsed)
	var active = float(state.get("active", 0.0))
	if player.character_id == "spider" and active > 0:
		for thread in state.get("threads", []):
			var target: Vector2 = at + (Vector2(thread.position) - player.head) * zoom
			var axis = target - at
			var normal = axis.orthogonal().normalized()
			var points = PackedVector2Array()
			for step in range(19):
				var t = float(step) / 18.0
				var sag = sin(t * PI) * minf(15.0, axis.length() * 0.07) * (0.3 + active * 0.35)
				var wave = sin(clock * 13.0 + t * 9.0 + float(thread.uid)) * sin(t * PI) * 2.0 * zoom
				points.append(at.lerp(target, t) + normal * (sag + wave))
			canvas.draw_polyline(points, Color(0.10, 0.24, 0.40, 0.85), 3.6 * zoom, true)
			canvas.draw_polyline(points, Color(0.86, 0.96, 1.0, 0.95), 1.5 * zoom, true)
	elif player.character_id == "beetle":
		canvas.draw_set_transform(at, player.facing.angle(), Vector2.ONE * zoom)
		var armor = clampf(float(state.get("armor", 0)) / 100.0, 0, 1)
		if armor > 0:
			canvas.draw_arc(Vector2(16, 0), 53, -0.8, 0.8, 18, Color(0.26, 0.60, 0.80, 0.2 + armor * 0.55), 2.2, true)
		if active > 0:
			var charge = float(state.get("charge", 0))
			if charge > 0:
				canvas.draw_arc(Vector2.ZERO, 65 + sin(clock * 35) * 3, -0.9, 0.9, 20, Color(0.95, 0.71, 0.25, 0.9), 3.0, true)
			else:
				for lane in [-1, 0, 1]:
					var points = PackedVector2Array([Vector2(-35, lane * 21), Vector2(-80, lane * 27), Vector2(-140 - lane * 8, lane * 34)])
					canvas.draw_polyline(points, Color(0.25, 0.59, 0.76, 0.5), 3.0, true)
		canvas.draw_set_transform(Vector2.ZERO)
