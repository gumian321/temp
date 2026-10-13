extends RefCounted
## Procedural colored ink VFX: transparent radial washes, ribbons, fragments,
## beam filaments and delayed shock rings. No opaque particle billboards.
const Feedback = preload("res://scripts/weapon_feedback.gd")
const INK = Color("213b6e")
var halo_texture: GradientTexture2D
var clock = 0.0
var draw_count = 0
const MAX_TRANSIENTS = 180
const MAX_PROJECTILES = 280

func _init():
	halo_texture = GradientTexture2D.new()
	halo_texture.width = 96; halo_texture.height = 96
	halo_texture.fill = GradientTexture2D.FILL_RADIAL
	halo_texture.fill_from = Vector2(0.5, 0.5); halo_texture.fill_to = Vector2(1.0, 0.5)
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0.75), Color(1,1,1,0.40), Color(1,1,1,0.12), Color(1,1,1,0)])
	halo_texture.gradient = gradient

func glow(canvas, at: Vector2, radius: float, color: Color, alpha: float):
	canvas.draw_texture_rect(halo_texture, Rect2(at-Vector2.ONE*radius, Vector2.ONE*radius*2), false, Color(color, clampf(alpha,0,1)))

func ring(canvas, at: Vector2, radius: float, color: Color, alpha: float, width: float, begin: float = 0.0, end: float = TAU):
	if radius < 0.2 or alpha <= 0.0: return
	canvas.draw_arc(at, radius, begin, end, 44, Color(color, minf(alpha,1.0)), maxf(0.5,width), true)

func ribbon(canvas, start: Vector2, end: Vector2, width: float, color: Color, alpha: float):
	if start.distance_squared_to(end)<0.01 or alpha<=0:return
	var axis = start.direction_to(end)
	var side = axis.orthogonal()
	var points = PackedVector2Array([start-side*width*0.25, start.lerp(end,0.65)-side*width*0.5, end, start.lerp(end,0.65)+side*width*0.5, start+side*width*0.25])
	canvas.draw_colored_polygon(points, Color(color, clampf(alpha,0,1)))

func spark_star(canvas, at: Vector2, radius: float, color: Color, alpha: float, seed: float, count: int = 10):
	var points = PackedVector2Array()
	for i in range(count*2):
		var angle = float(i)*PI/count + seed
		var reach = radius*(0.62+0.38*sin(i*3.71+seed)**2) if i%2==0 else radius*0.18
		points.append(at + Vector2.from_angle(angle)*reach)
	canvas.draw_colored_polygon(points, Color(color,clampf(alpha,0,1)))

func visible(canvas, at: Vector2, margin: float = 220.0) -> bool:
	return Rect2(-margin,-margin,1440+margin*2,900+margin*2).has_point(canvas.world(at))

func paint_projectile(canvas, bullet: Dictionary, time: float, zoom: float):
	if draw_count >= MAX_PROJECTILES or not visible(canvas,bullet.position): return
	draw_count += 1
	var key = str(bullet.get("fx_family", Feedback.family(bullet.data)))
	var style = Feedback.profile(key)
	var at = canvas.world(bullet.position)
	var axis = Vector2(bullet.velocity).normalized()
	var alpha = 0.95 if bullet.friendly else 0.52
	var travelled = Vector2(bullet.position).distance_to(bullet.get("origin",bullet.previous))
	var length = minf(style.trail, travelled)*zoom
	var back = at-axis*length
	if key == "sonic":
		var size = maxf(12,float(bullet.radius))*zoom
		for i in range(3):
			ring(canvas,at-axis*i*11*zoom,size*(1-i*0.12),style.color,alpha*(1-i*0.25),2.8*zoom,axis.angle()-1.12,axis.angle()+1.12)
		return
	glow(canvas,at,(10+style.weight*3)*zoom,style.color,alpha*0.8)
	ribbon(canvas,back,at,(7+style.weight*2)*zoom,style.accent,alpha*0.35)
	canvas.draw_line(back,at,Color(style.color,alpha),maxf(1.5,(2+style.weight)*zoom),true)
	canvas.draw_line(at-axis*minf(length,18*zoom),at,Color("fff5d9"),maxf(1,1.5*zoom),true)
	if key in ["rocket","nuke"]:
		for i in range(4):
			var offset = (fposmod(time*7+i*0.25,1.0))*length
			var ember = at-axis*offset+axis.orthogonal()*sin(i*4.3+time*16)*offset*0.08
			glow(canvas,ember,lerpf(5,15,offset/maxf(length,1))*zoom,style.accent,(1-offset/maxf(length,1))*0.5)
	if key in ["emp","blackhole"]:
		ring(canvas,at,9*zoom,style.accent,alpha,1.8*zoom,time*5,time*5+4.5)

func paint(canvas, battle, time: float, zoom: float):
	clock = time
	# Culling/budget only affects embellishment; gameplay bullets are always drawn.
	var drawn = 0
	var flame_owners: Dictionary = {}
	var major=["explosion","chain","hole_birth","hole_collapse"]
	var ordered=battle.effects.filter(func(e):return e.kind in major)+battle.effects.filter(func(e):return e.kind not in major)
	for effect in ordered:
		if drawn >= MAX_TRANSIENTS: break
		if not visible(canvas,effect.position,440): continue
		if effect.kind not in ["muzzle","hit","shield_hit","explosion","chain","flame","emp","mine_arm","hole_birth","hole_collapse"]: continue
		if effect.kind=="flame":
			var owner=str(effect.get("owner",""))
			if flame_owners.has(owner):continue
			flame_owners[owner]=true
		drawn += 1
		paint_effect(canvas,effect,zoom)
	for hole in battle.special.black_holes:
		if visible(canvas,hole.position,300): paint_hole(canvas,hole,zoom)
	for mine in battle.special.mines:
		if not visible(canvas,mine.position): continue
		var at=canvas.world(mine.position)
		var pulse=0.5+0.5*sin(clock*6+mine.position.x)
		ring(canvas,at,(15+pulse*4)*zoom,Feedback.PROFILES.mine.color,0.35+pulse*0.35,1.5*zoom)
		glow(canvas,at,12*zoom,Feedback.PROFILES.mine.accent,0.55)

func paint_effect(canvas, effect: Dictionary, zoom: float):
	var key = str(effect.get("fx_family", "tesla" if effect.kind=="chain" else ("emp" if effect.kind in ["emp","shield_hit"] else "impact")))
	var style = Feedback.profile(key)
	var at = canvas.world(effect.position)
	var duration = float(effect.get("fx_duration",0.15))
	var age = clampf(duration-float(effect.life),0,duration)
	var progress = age/maxf(duration,0.001)
	var fade = pow(1-progress,1.3)
	var alpha = 1.0 if effect.get("friendly",true) else 0.6
	var seed = effect.position.x*0.03+effect.position.y*0.017
	match effect.kind:
		"muzzle":
			var axis=Vector2(effect.direction)
			var size=clampf(float(effect.get("visual_scale",1.0)),0.55,1.0)*zoom
			var length=(20+style.weight*14)*size*(0.65+fade*0.35)
			glow(canvas,at,length*0.75,style.color,fade*alpha)
			ribbon(canvas,at-axis*3*size,at+axis*length,13*size,style.accent,fade*alpha*0.85)
			ribbon(canvas,at,at+axis*length*0.78,7*size,style.color,fade*alpha)
			ribbon(canvas,at,at+axis*length*0.56,3.5*size,Color("fff8df"),fade*alpha)
			for side in [-1,1]: ribbon(canvas,at,at+axis.rotated(side*0.7)*length*0.43,5*size,style.color,fade*alpha)
			if key in ["gatling","shotgun","cannon","flak"]:
				var casing=at+axis.orthogonal()*(8+age*190)*size-axis*age*60*size
				canvas.draw_line(casing,casing+Vector2.from_angle(age*18+seed)*5*size,Color(style.accent,fade),2.5*size,true)
		"chain": paint_beam(canvas,effect,style,fade*alpha,zoom,key)
		"flame": paint_flame(canvas,effect,style,alpha,zoom)
		"hit", "shield_hit", "emp":
			var radius=(18+style.weight*12)*zoom
			if effect.kind=="shield_hit":
				style=Feedback.PROFILES.emp
				ring(canvas,at,radius*(0.5+progress),style.color,fade*alpha,3*zoom)
				ring(canvas,at,radius*(0.8+progress*0.8),style.accent,fade*alpha*0.5,1.2*zoom)
			glow(canvas,at,radius*1.45,style.color,fade*alpha)
			if progress<0.55:
				spark_star(canvas,at,radius*(1+progress),style.accent,fade*alpha,seed,7)
				spark_star(canvas,at,radius*0.65,style.color,fade*alpha,seed,7)
				spark_star(canvas,at,radius*0.32,Color("fff9e8"),fade*alpha,seed,6)
			fragments(canvas,at,radius*2.4,style,progress,fade*alpha,seed,zoom,8)
			if key in ["emp","sonic","tesla"]:
				for i in range(3): ring(canvas,at,radius*(progress*2.2+i*0.24),style.color if i%2==0 else style.accent,fade*alpha*(0.7-i*0.12),2*zoom,seed+i,seed+i+5.0)
		"explosion", "hole_collapse":
			paint_blast(canvas,at,effect,style,progress,fade*alpha,seed,zoom,key)
		"mine_arm", "hole_birth":
			glow(canvas,at,50*zoom,style.accent,fade*alpha)
			for i in range(2): ring(canvas,at,(12+progress*44+i*8)*zoom,style.color,fade*alpha,2*zoom)

func fragments(canvas, at: Vector2, radius: float, style: Dictionary, progress: float, fade: float, seed: float, zoom: float, count: int):
	for i in range(count):
		var angle=float(i)*TAU/count+sin(i*4.7+seed)*0.3
		var axis=Vector2.from_angle(angle)
		var reach=radius*(0.35+0.65*sin(i*7.13+seed)**2)*(1-pow(1-progress,2))
		var tip=at+axis*reach
		var tail=at+axis*maxf(0,reach-(8+sin(i*2.1)*4)*zoom)
		canvas.draw_line(tail,tip,Color(INK,fade*0.75),3*zoom,true)
		canvas.draw_line(tail,tip,Color(style.color if i%2==0 else style.accent,fade),1.6*zoom,true)
		if i%3==0: canvas.draw_circle(tip,1.7*zoom,Color("fff5d7")*Color(1,1,1,fade))

func paint_blast(canvas, at: Vector2, effect: Dictionary, style: Dictionary, progress: float, fade: float, seed: float, zoom: float, key: String):
	var radius=clampf(float(effect.radius),24,430)*zoom
	var expansion=1-pow(1-progress,3)
	var nuclear=key=="nuke"
	var inner=minf(radius*0.62,150*zoom)*(0.5+expansion*0.5)
	glow(canvas,at,radius*(0.8+expansion*0.6),style.accent,fade*0.75)
	# Delayed shock fronts make a blast unfold instead of reading as one circle.
	for i in range(3 if nuclear else 2):
		var t=clampf((progress-i*0.095)/(1-i*0.095),0,1)
		if t<=0: continue
		var r=radius*(1-pow(1-t,2.8))*(1.16-i*0.16)
		ring(canvas,at,r,INK,(1-t)*0.3,5*zoom)
		ring(canvas,at,r,style.color if i%2==0 else style.accent,(1-t)*0.85,2.4*zoom)
		for shard in range(6):
			var angle=seed+shard*TAU/6+0.08*sin(clock*5)
			ring(canvas,at,r+4*zoom,style.accent,(1-t)*0.7,1.2*zoom,angle,angle+0.42)
	if progress<0.48:
		var flash=pow(1-progress/0.48,1.4)
		for puff in range(7):
			var puff_axis=Vector2.from_angle(seed+puff*TAU/7)
			var puff_at=at+puff_axis*inner*(0.28+progress*0.9)
			canvas.draw_circle(puff_at,inner*(0.24+progress*0.35),Color(style.accent,flash*0.22))
		spark_star(canvas,at,inner*1.45,style.accent,flash*0.95,seed,13 if nuclear else 9)
		spark_star(canvas,at,inner,style.color,flash,seed+0.15,11)
		glow(canvas,at,inner*0.85,Color("fff9e6"),flash)
		spark_star(canvas,at,inner*0.55,Color("fffbed"),flash,seed,8)
	fragments(canvas,at,radius*1.35,style,progress,fade,seed,zoom,28 if nuclear else 16)
	# Expanding colored ink puffs and embers persist after the bright core.
	for i in range(7):
		var axis=Vector2.from_angle(seed+i*TAU/7)
		var center=at+axis*inner*expansion*0.9
		glow(canvas,center,inner*(0.2+progress*0.28),style.accent,fade*0.24)
	if nuclear:
		var stripe=Vector2(radius*(0.3+expansion),0)
		canvas.draw_line(at-stripe,at+stripe,Color(style.color,fade*0.65),2*zoom,true)

func paint_beam(canvas, effect: Dictionary, style: Dictionary, fade: float, zoom: float, key: String):
	var start=canvas.world(effect.position)
	var finish=canvas.world(effect.end)
	var axis=start.direction_to(finish)
	var side=axis.orthogonal()
	if key=="rail":
		canvas.draw_line(start,finish,Color(style.accent,fade*0.25),18*zoom,true)
		canvas.draw_line(start,finish,Color(style.color,fade*0.7),7*zoom,true)
		canvas.draw_line(start,finish,Color("fffbed")*Color(1,1,1,fade),2.5*zoom,true)
		for i in range(1,6):
			var at=start.lerp(finish,i/6.0)
			canvas.draw_line(at-side*9*zoom,at+side*9*zoom,Color(style.accent,fade*0.65),1.5*zoom,true)
		glow(canvas,finish,42*zoom,style.color,fade)
		return
	var distance=start.distance_to(finish)
	var count=clampi(int(distance/(17*zoom)),5,28)
	var points=PackedVector2Array([start])
	for i in range(1,count):
		var t=float(i)/count
		var offset=sin(i*11.7+floor(clock*25)*3.7)*11*zoom*sin(t*PI)
		points.append(start.lerp(finish,t)+side*offset)
	points.append(finish)
	canvas.draw_polyline(points,Color(style.accent,fade*0.28),12*zoom,true)
	canvas.draw_polyline(points,Color(style.color,fade),4*zoom,true)
	canvas.draw_polyline(points,Color("edfdff")*Color(1,1,1,fade),1.4*zoom,true)
	for i in range(2,points.size()-1,4):
		var branch=points[i]+side*sin(i*7.0+clock*18)*22*zoom-axis*13*zoom
		canvas.draw_line(points[i],branch,Color(style.accent,fade*0.7),1.4*zoom,true)
	glow(canvas,finish,28*zoom,style.color,fade)

func paint_flame(canvas, effect: Dictionary, style: Dictionary, alpha: float, zoom: float):
	var start=canvas.world(effect.position)
	var finish=canvas.world(effect.end)
	var axis=start.direction_to(finish)
	var side=axis.orthogonal()
	if start.distance_squared_to(finish)<0.01:return
	# A continuous, rippling jet gives the moving tongues a shared hot core.
	for layer in range(3):
		var outline=PackedVector2Array()
		var length_scale=1.0-layer*0.11
		for bank in [1,-1]:
			for index in range(49):
				var t=float(index if bank==1 else 48-index)/48.0
				var width=(3+22*pow(sin(t*PI),0.85))*(1.0-layer*0.30)*zoom
				var sway=sin(t*21-clock*16)*8*t*zoom
				var edge=sin(t*53-clock*21+bank)*3.5*t*zoom
				outline.append(start.lerp(finish,t*length_scale)+side*(sway+bank*maxf(0.7*zoom,width+edge)))
		canvas.draw_colored_polygon(outline,Color([Color("f45d38"),Color("ffb13c"),Color("fff0ae")][layer],alpha*[0.62,0.82,0.9][layer]))
	for i in range(13):
		var t=fposmod(clock*2.5+i/13.0,1.0)
		var at=start.lerp(finish,t)+side*sin(i*3.7+clock*8)*t*14*zoom
		var radius=(5+20*t)*zoom
		glow(canvas,at,radius*1.5,style.accent,(1-t)*alpha*0.7)
		var ember=at+side*sin(i*5+clock*12)*t*24*zoom
		canvas.draw_line(ember-axis*radius*0.4,ember,Color(style.color,(1-t)*alpha),2.2*zoom,true)
		if t<0.65:glow(canvas,at,radius*0.55,Color("fff4cb"),(1-t)*alpha)

func paint_hole(canvas, hole: Dictionary, zoom: float):
	var at=canvas.world(hole.position)
	var radius=float(hole.radius)*zoom
	var style=Feedback.PROFILES.blackhole
	glow(canvas,at,radius*1.4,style.color,0.7)
	canvas.draw_circle(at,radius*0.46,Color("253360"))
	ring(canvas,at,radius*0.40,Color("48518c"),0.7,5*zoom)
	ring(canvas,at,radius*0.46,style.color,0.55,12*zoom)
	ring(canvas,at,radius*0.49,style.accent,0.9,3*zoom)
	ring(canvas,at,radius*0.51,Color("fff2b7"),0.9,1.3*zoom,clock,clock+4.7)
	for i in range(5):
		var start=clock*(1.1+i*0.15)+i*TAU/5
		var points=PackedVector2Array()
		for j in range(28):
			var t=float(j)/27
			points.append(at+Vector2.from_angle(start+t*3.5)*radius*(lerpf(1.25,0.48,t)+sin(t*17+i+clock*2)*0.024))
		canvas.draw_polyline(points,Color(style.color,0.10),14*zoom,true)
		canvas.draw_polyline(points,Color(style.color if i%2==0 else style.accent,0.72),2*zoom,true)
	var disk=PackedVector2Array()
	for i in range(65):
		var angle=float(i)/64*TAU
		disk.append(at+Vector2(cos(angle)*radius*0.90,sin(angle)*radius*0.21).rotated(-0.25))
	canvas.draw_polyline(disk,Color(style.accent,0.14),12*zoom,true)
	canvas.draw_polyline(disk,Color(style.accent,0.85),3.0*zoom,true)
	canvas.draw_polyline(disk,Color("fff1bd"),1.0*zoom,true)
	for i in range(12):
		var t=fposmod(clock*0.7+i/12.0,1)
		var axis=Vector2.from_angle(i*2.4+t*3)
		var point=at+axis*radius*lerpf(1.35,0.48,t)
		canvas.draw_line(point,point-axis*9*zoom,Color(style.color,0.9),1.6*zoom,true)
