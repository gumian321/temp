extends RefCounted
## Bounded visual elasticity only: never writes simulation positions or consumes RNG.
const AttackShaders = preload("res://scripts/attack_shader_layer.gd")
const MAX_CONTROLS = 32
const CURVE_SEGMENTS = 18
const INK = Color("173b70")
const PAPER = Color("fff1cf")

static func organ_scale(family: String, pulse_left: float, time: float) -> Vector2:
	if not is_finite(pulse_left) or not is_finite(time): return Vector2.ONE
	var pulse = clampf(pulse_left / 0.18, 0.0, 1.0)
	var age = (1.0-pulse)*PI
	var elastic = sin(age*2.0)*pulse
	var breath = sin(time*3.0)*0.012
	var sac = family in ["cannon","flak","missile","rocket","nuke","flame","emp","blackhole","sonic"]
	var amount = 0.15 if sac else 0.075
	return Vector2(1.0 + elastic*amount + breath, 1.0 - elastic*amount*0.65 - breath*0.5)

static func control_alpha(control: Dictionary) -> float:
	var life = float(control.get("life",0.0))
	var duration = float(control.get("duration",0.0))
	if not is_finite(life) or not is_finite(duration) or duration <= 0: return 0.0
	return clampf(life / minf(0.16,duration),0,1)

static func curve_points(start: Vector2, end: Vector2, age: float, kind: String, strand: int = 0) -> PackedVector2Array:
	var points = PackedVector2Array()
	if not start.is_finite() or not end.is_finite() or not is_finite(age): return points
	var side = start.direction_to(end).orthogonal()
	var length = start.distance_to(end)
	var bend = minf(25.0,length*0.15)
	for i in range(CURVE_SEGMENTS+1):
		var t = float(i)/CURVE_SEGMENTS
		var wave = sin(t*PI)
		var offset = wave*(bend*sin(age*13.0+strand*1.6)*(1.0-t)*0.65 + (strand-1)*3.0)
		if kind == "tendril": offset += sin(t*PI*4.0-age*18.0)*wave*2.4
		points.append(start.lerp(end,t)+side*offset)
	# Explicit endpoints stay planted, including at zero distance.
	points[0]=start;points[CURVE_SEGMENTS]=end
	return points

static func ownership_color(kind: String, friendly: bool) -> Color:
	if not friendly: return Color("f06888")
	return Color("72e8dc") if kind == "tendril" else Color("b8e5ee")

static func paint(canvas, controls: Array, zoom: float):
	var source_canvas=canvas
	var count = mini(MAX_CONTROLS,controls.size())
	for i in range(count):
		canvas=source_canvas
		var effect: Dictionary = controls[i]
		var target: Dictionary = effect.get("target",{})
		var alpha = control_alpha(effect)
		if target.is_empty() or float(target.get("hp",0))<=0 or alpha<=0: continue
		var start: Vector2 = canvas.world(effect.origin)
		var end: Vector2 = canvas.world(target.position)
		if not start.is_finite() or not end.is_finite(): continue
		var bounds = Rect2(start,Vector2.ZERO).expand(end).grow(60.0)
		if not bounds.intersects(canvas.get_viewport_rect()): continue
		var kind = str(effect.get("kind","silk"))
		var friendly = bool(effect.get("friendly",true))
		canvas=AttackShaders.route(canvas,kind,not friendly)
		var color = ownership_color(kind,friendly)
		var age = maxf(0,float(effect.duration)-float(effect.life))
		var radius = clampf(float(target.get("radius",18)),12,34)*zoom
		for strand in range(3 if kind=="silk" else 1):
			var curve = curve_points(start,end,age,kind,strand)
			if curve.is_empty(): continue
			canvas.draw_polyline(curve,Color(INK,alpha*0.88),(3.7 if kind=="silk" else 6.0)*zoom,true)
			canvas.draw_polyline(curve,Color(color,alpha),(1.5 if kind=="silk" else 3.0)*zoom,true)
			if kind=="tendril":canvas.draw_polyline(curve,Color(PAPER,alpha*0.85),0.9*zoom,true)
		# Coils sit on the affected target; a terminal hook and source knot explain attachment.
		for turn in range(3 if kind=="silk" else 2):
			var wrap = PackedVector2Array()
			for step in range(19):
				var a = float(step)/18.0*TAU
				wrap.append(end+Vector2(cos(a)*radius,sin(a)*radius*0.32+(turn-1)*radius*0.38).rotated(-0.38))
			canvas.draw_polyline(wrap,Color(INK,alpha*0.9),3.9*zoom,true)
			canvas.draw_polyline(wrap,Color(color,alpha),1.8*zoom,true)
		canvas.draw_circle(start,4.5*zoom,Color(INK,alpha),true,-1,true)
		canvas.draw_circle(start,2.3*zoom,Color(color,alpha),true,-1,true)
		if not friendly:
			var axis = start.direction_to(end)
			var side = axis.orthogonal()
			canvas.draw_polyline(PackedVector2Array([end-axis*12*zoom-side*7*zoom,end,end-axis*12*zoom+side*7*zoom]),Color(color,alpha),2.3*zoom,true)
