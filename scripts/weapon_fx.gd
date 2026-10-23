extends RefCounted
## Organic projectile bodies, pollen trails, split husks, and directional ink VFX.
## Presentation only; no opaque particle billboards or factory ordnance art.
const AttackShaders = preload("res://scripts/attack_shader_layer.gd")
const Feedback = preload("res://scripts/weapon_feedback.gd")
const Organic = preload("res://scripts/insect_projectiles.gd")
const DeathSplatter=preload("res://scripts/enemy_death_splatter.gd")
const Viscous = preload("res://scripts/viscous_projectiles.gd")
const ProjectileTrails = preload("res://scripts/projectile_trails.gd")
const FluidRibbon = preload("res://scripts/fluid_ribbon.gd")
const INK = Color("213b6e")
var halo_texture: GradientTexture2D
var clock = 0.0
var draw_count = 0
const MAX_TRANSIENTS = 180
const MAX_PROJECTILES = 280
const MAX_DETAILED_TRAILS = 96
const MAJOR_EFFECTS = ["explosion","chain","hole_birth","hole_collapse"]
var hazard_effects:Array=[]
var major_effects:Array=[]
var minor_effects:Array=[]
var flame_owners:Dictionary={}
var use_mine_batches=true
var egg_visuals=preload("res://scripts/egg_visual_batch.gd").new()

func paint_mine_sprites(canvas,battle,zoom:float):
	if use_mine_batches and egg_visuals.paint_sprites(canvas,battle,zoom):return
	for mine in battle.special.mines:
		canvas.skill_module_art("mine",canvas.db.sprite(mine.data.mineSprite),canvas.world(mine.position),Vector2(22,22)*zoom,0.0,not bool(mine.get("friendly",true)))

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

func visible(canvas, at: Vector2, margin: float = 220.0) -> bool:
	return canvas.get_viewport_rect().grow(margin).has_point(canvas.world(at))

# Pure geometry shared with regression checks: the tail always trails velocity.
static func gatling_geometry(bullet: Dictionary, zoom: float) -> Dictionary:
	var axis = Vector2(bullet.velocity).normalized()
	var travelled = Vector2(bullet.position).distance_to(bullet.get("origin",bullet.previous))
	var length = minf(30.0,travelled)*zoom
	return {"axis":axis,"tail":-axis*length,"tip":axis*3.5*zoom}

func paint_gatling(canvas, bullet: Dictionary, zoom: float):
	# Compatibility entrypoint shares the generated stinger route.
	paint_projectile(canvas,bullet,clock,zoom)

func paint_projectile(canvas, bullet: Dictionary, time: float, zoom: float):
	if not visible(canvas,bullet.position):return
	canvas=AttackShaders.route(canvas,Organic.family(bullet),not bool(bullet.get("friendly",true)))
	# Draw the independent trail first so its head is tucked under the body.
	# Incoming hazards keep their direction cue even after the friendly FX cap.
	if not bool(bullet.get("friendly",true)) or draw_count<MAX_PROJECTILES:
		if bool(bullet.get("friendly",true)) and draw_count>=MAX_DETAILED_TRAILS:
			ProjectileTrails.paint_simple(canvas,bullet,zoom)
		else:ProjectileTrails.paint_shot(canvas,bullet,zoom,time)
		if bool(bullet.get("friendly",true)):draw_count+=1
	Organic.paint(canvas,bullet,zoom,time)

func paint(canvas, battle, time: float, zoom: float):
	clock = time
	if battle.get("mutation_weapons")!=null:battle.mutation_weapons.paint(canvas,time,zoom)
	if "projectile_trails" in battle:
		for trail in battle.projectile_trails:
			if visible(canvas,trail.position,ProjectileTrails.MAX_DISTANCE*zoom):
				ProjectileTrails.paint(AttackShaders.route(canvas,str(trail.fx_family),not bool(trail.friendly)),trail,zoom,time)
	if "death_splatters" in battle:
		var visible_deaths=0
		for burst in battle.death_splatters:
			if visible(canvas,burst.position,float(burst.radius)*4.0*zoom):visible_deaths+=1
		# Older ground stains first; newest pressure jets must not be painted over
		# by old puddles. Offscreen deaths never spend the detail budget.
		for burst in battle.death_splatters:
			if not visible(canvas,burst.position,float(burst.radius)*4.0*zoom):continue
			DeathSplatter.paint(canvas,burst,zoom,visible_deaths<=DeathSplatter.MAX_DETAILED)
			visible_deaths-=1
	# Culling/budget only affects embellishment; gameplay bullets are always drawn.
	var drawn = 0
	flame_owners.clear()
	# Stable priority order without repeated filters or Dictionary membership
	# searches. Each effect is classified once, regardless of hostile beam count.
	order_effects(battle.effects)
	for bucket in [hazard_effects,major_effects,minor_effects]:
		for effect in bucket:
			if drawn >= MAX_TRANSIENTS: break
			if not visible(canvas,effect.position,440): continue
			if effect.kind not in ["stone_chips","muzzle","hit","shield_hit","explosion","chain","flame","emp","mine_arm","hole_birth","hole_collapse","viscous_contact","egg_burst"]: continue
			if effect.kind=="flame":
				var owner=str(effect.get("owner",""))
				if flame_owners.has(owner):continue
				flame_owners[owner]=true
			drawn += 1
			paint_effect(canvas,effect,zoom)
	for hole in battle.special.black_holes:
		if visible(canvas,hole.position,300): paint_hole(canvas,hole,zoom)
	if use_mine_batches and egg_visuals.paint_markers(canvas,battle,zoom,clock,halo_texture):return
	for mine in battle.special.mines:
		if not visible(canvas,mine.position): continue
		var at=canvas.world(mine.position)
		var pulse=0.5+0.5*sin(clock*6+mine.position.x)
		var mine_canvas=AttackShaders.route(canvas,"mine",not bool(mine.get("friendly",true)))
		ring(mine_canvas,at,(15+pulse*4)*zoom,Feedback.PROFILES.mine.color,0.35+pulse*0.35,1.5*zoom)
		glow(mine_canvas,at,12*zoom,Feedback.PROFILES.mine.accent,0.55)

func order_effects(effects:Array):
	hazard_effects.clear();major_effects.clear();minor_effects.clear()
	for effect in effects:
		if not effect.get("friendly",true) and effect.kind in ["chain","flame"]:
			hazard_effects.append(effect)
		elif effect.kind in MAJOR_EFFECTS:
			major_effects.append(effect)
		else:
			minor_effects.append(effect)

func paint_effect(canvas, effect: Dictionary, zoom: float):
	if effect.kind=="stone_chips":
		var age=.38-float(effect.life)
		var fade=clampf(float(effect.life)/.16,0,1)
		for i in 5:
			var seed=int(effect.seed)+i*31
			var speed=35.0+float(seed%47)
			var direction=Vector2(effect.direction).rotated(float(seed%21-10)*.12)
			var point=canvas.world(effect.position)+(direction*speed*age+Vector2(0,90*age*age))*zoom
			var size=float(effect.size)*(0.7+float(seed%5)*.15)*zoom
			var axis=Vector2.from_angle(seed+age*7)*size
			var triangle=PackedVector2Array([point+axis,point+axis.rotated(2.2),point+axis.rotated(4.1)*.7])
			canvas.draw_colored_polygon(triangle,Color(Color("bdbbb0") if i%2==0 else Color("74746f"),fade))
		return
	canvas=AttackShaders.route(canvas,str(effect.get("fx_family","tesla" if effect.kind=="chain" else ("emp" if effect.kind in ["emp","shield_hit"] else "impact"))),not bool(effect.get("friendly",true)))
	var key = str(effect.get("fx_family", "tesla" if effect.kind=="chain" else ("emp" if effect.kind in ["emp","shield_hit"] else "impact")))
	var style = Feedback.profile(key)
	if not effect.get("friendly",true):
		style=style.duplicate();style.color=Organic.DANGER;style.accent=Organic.DANGER_EDGE
	var at = canvas.world(effect.position)
	var duration = float(effect.get("fx_duration",0.15))
	var age = clampf(duration-float(effect.life),0,duration)
	var progress = age/maxf(duration,0.001)
	var fade = pow(1-progress,1.3)
	var alpha = 1.0
	var seed = effect.position.x*0.03+effect.position.y*0.017
	match effect.kind:
		"viscous_contact", "egg_burst":
			paint_viscous_contact(canvas,at,effect,progress,zoom)
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
				var husk=at+axis.orthogonal()*(8+age*190)*size-axis*age*60*size
				canvas.draw_line(husk,husk+Vector2.from_angle(age*18+seed)*5*size,Color(style.accent,fade),2.5*size,true)
		"chain":
			# Hold the discharge briefly, then decay; no repeated damage is applied.
			var beam_fade=1.0 if progress<0.35 else pow((1.0-progress)/0.65,0.8)
			paint_beam(canvas,effect,style,(beam_fade if key=="tesla" else fade)*alpha,zoom,key)
		"flame": paint_flame(canvas,effect,style,alpha,zoom)
		"hit", "shield_hit":
			paint_contact(canvas,at,effect,style,progress,fade,zoom)
		"emp":
			# Status indicator stays small; contact feedback has its own directional cue.
			ring(canvas,at,7*zoom,style.color,fade*0.45,1.2*zoom)
		"explosion", "hole_collapse":
			paint_blast(canvas,at,effect,style,progress,fade*alpha,seed,zoom,key)
		"mine_arm", "hole_birth":
			glow(canvas,at,50*zoom,style.accent,fade*alpha)
			for i in range(2): ring(canvas,at,(12+progress*44+i*8)*zoom,style.color,fade*alpha,2*zoom)

func paint_contact(canvas, at: Vector2, effect: Dictionary, style: Dictionary, progress: float, fade: float, zoom: float):
	var size=clampf(float(effect.get("radius",5.0)),3.5,24.0)*zoom
	var axis=Vector2(effect.get("direction",Vector2.RIGHT)).normalized()
	var normal=Vector2(effect.get("normal",-axis)).normalized()
	var friendly=bool(effect.get("friendly",true))
	var color:Color=style.color if friendly else Color("ec526e")
	var accent:Color=style.accent if friendly else Color("9b3159")
	if effect.kind=="shield_hit":color=Color("58c4d8") if friendly else Color("ef739e")
	# A tiny contact slit and 3–5 backward/tangential splinters, never a radial star.
	# Deterministic fan follows the struck surface; no gameplay RNG is touched.
	var spray=(normal*0.8-axis*0.2).normalized()
	var count=3 if size/maxf(zoom,0.001)<12 else 5
	for i in range(count):
		var spread=(float(i)/maxf(1,count-1)-0.5)*1.7
		var direction=spray.rotated(spread)
		var travel=size*(0.16+progress*(0.7+0.3*sin(i*2.4+1.0)))
		var tip=at+direction*travel
		var tail=tip-direction*size*(0.18+0.10*float(i%2))*fade
		canvas.draw_line(tail,tip,Color(INK,fade*0.65),maxf(1.0,2.2*zoom),true)
		canvas.draw_line(tail,tip,Color(color if i%2==0 else accent,fade),maxf(0.8,1.2*zoom),true)
	if progress<0.35:
		var flash=1-progress/0.35
		var tangent=normal.orthogonal()
		canvas.draw_line(at-tangent*size*0.13,at+tangent*size*0.13,Color(color,flash),maxf(1.4,2.1*zoom),true)
		canvas.draw_circle(at,minf(2.1*zoom,size*0.14),Color("fff5d8")*Color(1,1,1,flash))
	if effect.kind=="shield_hit":
		# A local tangential shield glint, not expanding concentric circles.
		var tangent=normal.orthogonal()
		canvas.draw_line(at-tangent*size*0.45,at+tangent*size*0.45,Color(color,fade*0.55),maxf(1.0,zoom),true)

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
	var radius=clampf(float(effect.radius),18,180)*zoom
	var spread=1-pow(1-progress,2)
	var color:Color=style.color if effect.get("friendly",true) else Color("e66c98")
	var count=13 if key=="nuke" else 9
	# Asymmetric acid/spore droplets and torn husks; no bomb flash or shock rings.
	for i in range(count):
		var direction=Vector2.from_angle(seed+i*2.39996)
		var reach=radius*(0.25+0.65*pow(sin(i*3.19+seed),2))*spread
		var point=at+direction*reach
		var size=(3+float(i%3)*1.6)*zoom*(1-progress*0.65)
		canvas.draw_circle(point,size,Color(color,fade*0.7),true,-1,true)
		if i%2==0:
			var side=direction.orthogonal()
			canvas.draw_polyline(PackedVector2Array([point-side*size,point+direction*size*1.7,point+side*size*0.6]),Color(INK,fade*0.8),maxf(1,1.5*zoom),true)
	if progress<0.35:
		var acid=1-progress/0.35
		for i in range(4):
			var offset=Vector2.from_angle(seed+i*2.4)*radius*0.10
			canvas.draw_circle(at+offset,minf(13*zoom,radius*0.14),Color(style.accent,acid*0.23),true,-1,true)

func paint_beam(canvas, effect: Dictionary, style: Dictionary, fade: float, zoom: float, key: String):
	if key in ["tesla","rail","sonic"] or effect.get("organic_family","")=="tongue":
		paint_tongue(canvas,effect,zoom)
		return
	var start=canvas.world(effect.position)
	var finish=canvas.world(effect.end)
	var axis=start.direction_to(finish)
	var side=axis.orthogonal()
	if key=="rail":
		canvas.draw_line(start,finish,Color(Organic.SEPARATION,fade*.90),11*zoom,true)
		canvas.draw_line(start,finish,Color(style.accent,fade*.95),8.5*zoom,true)
		canvas.draw_line(start,finish,Color(style.color,fade*0.7),7*zoom,true)
		canvas.draw_line(start,finish,Color("fffbed")*Color(1,1,1,fade),2.5*zoom,true)
		for i in range(1,6):
			var at=start.lerp(finish,i/6.0)
			canvas.draw_line(at-side*9*zoom,at+side*9*zoom,Color(style.accent,fade*0.65),1.5*zoom,true)
		canvas.draw_circle(finish,2*zoom,Color(style.color,fade))
		return
	var distance=start.distance_to(finish)
	var count=clampi(int(distance/(17*zoom)),5,28)
	var points=PackedVector2Array([start])
	for i in range(1,count):
		var t=float(i)/count
		# A continuous contracting nerve, with a stable danger edge and slow sap flow.
		var offset=sin(t*PI*5-clock*7.0)*7*zoom*sin(t*PI)
		points.append(start.lerp(finish,t)+side*offset)
	points.append(finish)
	canvas.draw_polyline(points,Color(Organic.SEPARATION,fade*.88),maxf(7,10*zoom),true)
	canvas.draw_polyline(points,Color(style.accent,fade*0.30),maxf(10,16*zoom),true)
	canvas.draw_polyline(points,Color(INK,fade*0.95),maxf(4.5,8*zoom),true)
	canvas.draw_polyline(points,Color(style.color,fade),maxf(2.8,5*zoom),true)
	canvas.draw_polyline(points,Color("edfdff")*Color(1,1,1,fade),maxf(1.2,2*zoom),true)
	for i in range(2,points.size()-1,4):
		var branch=points[i]+side*sin(i*7.0+clock*18)*22*zoom-axis*13*zoom
		canvas.draw_line(points[i],branch,Color(style.accent,fade*0.7),1.4*zoom,true)
	for i in 3:
		var t=fposmod(clock*.65+i/3.0,1.0)
		var lump=start.lerp(finish,t)+side*sin(t*PI*5-clock*7.0)*7*zoom*sin(t*PI)
		canvas.draw_circle(lump,3.8*zoom,Color(style.accent,fade),true,-1,true)
		canvas.draw_circle(lump+Vector2(-.6,-.8)*zoom,1.7*zoom,Color("f6bdcc",fade*.8),true,-1,true)
	glow(canvas,start,23*zoom,style.accent,fade*0.8)
	canvas.draw_circle(finish,2*zoom,Color(style.color,fade))

func paint_flame(canvas, effect: Dictionary, style: Dictionary, alpha: float, zoom: float):
	var curve:PackedVector2Array=effect.get("curve",PackedVector2Array())
	if curve.is_empty():
		curve=preload("res://scripts/flame_whip.gd").advance({"clock":clock},effect.position,Vector2(effect.position).direction_to(effect.end),Vector2(effect.position).distance_to(effect.end),0)
	var release=clampf(float(effect.life)/.11,0,1)
	preload("res://scripts/flame_whip.gd").paint(canvas,curve,zoom,style.color,style.accent,alpha*release,lerpf(.2,1.0,release))
	return

func paint_hole(canvas, hole: Dictionary, zoom: float):
	canvas=AttackShaders.route(canvas,"blackhole",not bool(hole.get("friendly",true)))
	var at=canvas.world(hole.position)
	canvas.draw_set_transform(at)
	at=Vector2.ZERO
	var radius=float(hole.radius)*zoom
	var style=Feedback.PROFILES.blackhole
	if not bool(hole.get("friendly",true)):
		style=style.duplicate();style.color=Organic.DANGER;style.accent=Color("ef94b5")
	glow(canvas,at,radius*1.4,style.color,0.7)
	canvas.draw_circle(at,radius*0.46,Color("381c39") if not bool(hole.get("friendly",true)) else Color("253360"))
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

	canvas.draw_set_transform(Vector2.ZERO)

func paint_viscous_contact(canvas,at:Vector2,effect:Dictionary,progress:float,zoom:float):
	var kind=str(effect.get("organic_family","mucus"))
	var heading=Vector2(effect.get("direction",Vector2.RIGHT)).angle()
	var size=clampf(float(effect.get("radius",8.0))*2.2,14.0,34.0)*zoom
	var fade=clampf(float(effect.life)/0.14,0.0,1.0)
	if effect.kind=="egg_burst":
		var burst_progress=1.0-clampf(float(effect.life)/0.18,0.0,1.0)
		Viscous.stamp(canvas,"egg_burst",at,Vector2.ONE*size*(1.0+burst_progress*0.4),heading,fade)
	elif kind=="egg":
		var swell=1.0+progress*0.48
		Viscous.stamp(canvas,"egg",at,Vector2(size*0.85,size)*swell,heading+sin(progress*18)*0.06,1.0)
	elif kind=="larva":
		Viscous.stamp(canvas,"larva_contact",at,Vector2(size,size*0.65),heading+sin(clock*24+at.x)*0.16,fade)
	else:
		Viscous.stamp(canvas,"mucus_splat",at,Vector2(size,size*0.72)*(1.0+progress*0.15),heading,fade*0.84)

func paint_tongue(canvas,effect:Dictionary,zoom:float):
	var duration=maxf(float(effect.get("fx_duration",0.22)),0.001)
	var progress=clampf(1.0-float(effect.life)/duration,0.0,1.0)
	var start=canvas.world(effect.position)
	var target=canvas.world(effect.end)
	# Full contact endpoint holds first; the final third visibly reels into the organ.
	var reach=1.0 if progress<0.64 else pow((1.0-progress)/0.36,0.75)
	var finish=start.lerp(target,reach)
	# One continuous animated membrane; anchors and gameplay reach stay exact.
	var width=(6.0+sin(progress*PI)*1.5)*zoom
	var friendly=bool(effect.get("friendly",true))
	FluidRibbon.paint(canvas,FluidRibbon.line(start,finish),width,clock,float(effect.position.x)*.017,FluidRibbon.BEAM,.96,friendly,Feedback.profile(str(effect.get("fx_family","rail"))).color if friendly else Organic.DANGER)
	if friendly:Viscous.stamp(canvas,"tongue",finish,Vector2(21,11)*zoom,start.direction_to(target).angle(),clampf(float(effect.life)/0.04,0.0,1.0))
	else:Organic.paint_hostile_cue(canvas,finish,start.direction_to(target).angle(),{"size":Vector2(21,14)*zoom})
	# Distinct bioelectric structures run on the family shader batch, over the
	# generated tongue. All endpoints and retraction still use the same contact.
	var family=str(effect.get("fx_family","rail"))
	var axis=start.direction_to(finish)
	var side=axis.orthogonal()
	var alpha=clampf(float(effect.life)/0.045,0.0,1.0)
	var electric=Color("72e9ff") if friendly else Organic.DANGER
	var pale=Color("f1fdff") if friendly else Color("ffb9c8")
	var accent=Color("537df9") if friendly else Organic.DANGER_EDGE
	if family=="tesla":
		var arc=PackedVector2Array([start])
		var steps=clampi(int(start.distance_to(finish)/(12.0*zoom)),5,30)
		for i in range(1,steps):
			var t=float(i)/steps
			var offset=sin(i*9.7+floor(clock*24.0)*2.7)*4.0*zoom*sin(t*PI)
			arc.append(start.lerp(finish,t)+side*offset)
		arc.append(finish)
		canvas.draw_polyline(arc,Color(accent,alpha*.38),6.0*zoom,true)
		canvas.draw_polyline(arc,Color(electric,alpha),2.1*zoom,true)
		canvas.draw_polyline(arc,Color(pale,alpha),0.8*zoom,true)
		for i in range(2,arc.size()-1,4):
			var tip=arc[i]+side*sin(clock*29.0+i)*8.0*zoom-axis*3.0*zoom
			canvas.draw_polyline(PackedVector2Array([arc[i],tip,tip+axis*5.0*zoom]),Color(pale,alpha*.85),1.0*zoom,true)
	elif family=="sonic":
		canvas.draw_line(start,finish,Color(Color("a596ff") if friendly else Organic.DANGER,alpha*.7),2.0*zoom,true)
		for i in range(4):
			var phase=fposmod(clock*2.6+i*0.25,1.0)
			var center=start.lerp(finish,phase)
			var band=PackedVector2Array()
			var radius=(3.0+phase*7.0)*zoom
			for j in range(17):
				var angle=float(j)/16.0*TAU
				band.append(center+axis*cos(angle)*radius*0.27+side*sin(angle)*radius)
			canvas.draw_polyline(band,Color((Color("8ce7e9" if i%2==0 else "d5a2ff") if friendly else pale),alpha*sin(phase*PI)*.85),1.35*zoom,true)
	elif family=="rail":
		canvas.draw_line(start,finish,Color(Color("657bf2") if friendly else Organic.DANGER,alpha*.62),3.5*zoom,true)
		var pressure=clampf(progress/0.32,0.0,1.0)
		canvas.draw_line(start.lerp(finish,maxf(0.0,pressure-0.38)),start.lerp(finish,pressure),Color(Color("d3ffff") if friendly else pale,alpha),1.9*zoom,true)
