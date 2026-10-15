extends RefCounted
## Detached visual snapshots never retain a gameplay owner or mutable part.
const Art = preload("res://scripts/centipede_art.gd")
const Ink = preload("res://scripts/blue_ink.gd")
const LIFETIME = 0.95
const MAX_DEBRIS = 24
const HIT_TIME = 0.42
const KICK_TIME = 0.24
const TRAIL_TIME = 1.25
const NUMBER_TIME = 0.85
const HURT = Color("ff635b")
const HURT_INK = Color("9b263f")

static func record_hit(part: Dictionary, previous_hp: float, direction: Vector2):
	var lost = minf(previous_hp, previous_hp-float(part.hp))
	if lost<=0:return
	part.impact_left=HIT_TIME
	part.impact_direction=direction.normalized() if direction.length_squared()>0.0001 else Vector2.LEFT
	part.impact_force=lerpf(3.0,6.0,clampf(lost/maxf(1,part.max_hp)*4.0,0,1))
	part.damage_trail_hp=maxf(previous_hp,float(part.get("damage_trail_hp",previous_hp)) if float(part.get("damage_trail_left",0))>0 else previous_hp)
	part.damage_trail_left=TRAIL_TIME
	# One number per live part, including continuous damage; no per-hit nodes.
	if float(part.get("damage_number_left",0))<=0:
		part.damage_number=0.0
		part.damage_number_left=NUMBER_TIME
	part.damage_number=float(part.get("damage_number",0))+lost

static func step_hit(part: Dictionary, dt: float):
	part.impact_left=maxf(0,float(part.get("impact_left",0))-dt)
	part.damage_number_left=maxf(0,float(part.get("damage_number_left",0))-dt)
	part.damage_trail_left=maxf(0,float(part.get("damage_trail_left",0))-dt)
	if float(part.damage_trail_left)<TRAIL_TIME-0.25:
		part.damage_trail_hp=move_toward(float(part.get("damage_trail_hp",part.hp)),float(part.hp),maxf(1,part.max_hp)*dt*1.3)

static func hit_amount(part: Dictionary) -> float:
	return smoothstep(0.0,HIT_TIME,float(part.get("impact_left",0)))

static func tint(part: Dictionary, base: Color = Color.WHITE) -> Color:
	var color=base.lerp(HURT,hit_amount(part)*0.85)
	color.a=base.a
	return color

static func offset(part: Dictionary) -> Vector2:
	var age=HIT_TIME-float(part.get("impact_left",0))
	if age<0 or age>=KICK_TIME:return Vector2.ZERO
	var envelope=pow(1.0-age/KICK_TIME,2)
	return Vector2(part.get("impact_direction",Vector2.ZERO))*float(part.get("impact_force",0))*envelope*cos(age/KICK_TIME*PI*1.5)

static func snapshot(player, index: int) -> Dictionary:
	var part: Dictionary = player.parts[index]
	var pose: Dictionary = player.segment_pose(player.segment_index(index))
	return {"kind":"segment_break", "position":Vector2(pose.point), "radius":72.0,
		"life":LIFETIME, "duration":LIFETIME, "particle_type":0, "player_hit":true,
		"segment":player.segment_index(index), "id":str(part.id),
		"angle":Vector2(pose.direction).angle(), "weapon_angle":float(part.angle),
		"weapon_offset":Vector2(player.weapon_origin(index))-Vector2(pose.point),
		"velocity":Vector2(player.velocity)*0.18, "module_size":player.module_size(index) if player.has_method("module_size") else 56.0}

static func progress(effect: Dictionary) -> float:
	return clampf(1.0-float(effect.life)/LIFETIME,0.0,1.0)

static func debris_position(effect: Dictionary, piece: int) -> Vector2:
	var t = progress(effect)
	var side = -1.0 if piece%2==0 else 1.0
	var direction = Vector2.from_angle(float(effect.angle))
	return Vector2(effect.position)+Vector2(effect.velocity)*t*LIFETIME+direction.orthogonal()*side*(12+55*t)+direction*(piece/2.0-0.75)*38*t

static func paint_hit(canvas, at: Vector2, angle: float, strength: float, zoom: float, radius: float = 32.0):
	if strength<=0:return
	var alpha = clampf(strength/HIT_TIME,0,1)
	var reach=(radius+(1-alpha)*10)*zoom
	canvas.draw_arc(at,reach,0,TAU,40,Color(Ink.PAPER,alpha*0.95),5.6*zoom,true)
	canvas.draw_arc(at,reach,0,TAU,40,Color(HURT_INK,alpha),3.3*zoom,true)
	canvas.draw_arc(at,reach,angle-0.7,angle+0.7,12,Color(HURT,alpha),3.5*zoom,true)
	for side in range(4):
		var axis=Vector2.from_angle(angle+PI*0.25+side*PI*0.5)
		canvas.draw_line(at+axis*(reach+3*zoom),at+axis*(reach+9*zoom),Color(HURT_INK,alpha),2.2*zoom,true)

static func paint_health(canvas, part: Dictionary, at: Vector2, zoom: float, radius: float, head: bool = false):
	var hp=clampf(float(part.hp)/maxf(1,part.max_hp),0,1)
	var hit=hit_amount(part)
	if not head or hp<0.999 or hit>0:
		var scale_factor=maxf(0.85,zoom)
		var size=Vector2(48*zoom,5*scale_factor)
		var position=at+Vector2(-size.x*0.5,(radius+8)*zoom)
		canvas.draw_rect(Rect2(position-Vector2.ONE, size+Vector2.ONE*2),Ink.INK)
		canvas.draw_rect(Rect2(position,size),Ink.PAPER)
		if float(part.get("damage_trail_left",0))>0:
			var trail=clampf(float(part.get("damage_trail_hp",part.hp))/maxf(1,part.max_hp),hp,1)
			canvas.draw_rect(Rect2(position,Vector2(size.x*trail,size.y)),Color("f6b34f"))
		var color=HURT if hit>0 or hp<0.3 else Ink.BLUE
		canvas.draw_rect(Rect2(position,Vector2(size.x*hp,size.y)),color)
	var left=float(part.get("damage_number_left",0))
	if left<=0:return
	var age=1.0-left/NUMBER_TIME
	var alpha=1.0-smoothstep(0.65,1.0,age)
	var damage=float(part.get("damage_number",0))
	var label="-%d"%roundi(damage) if damage>=1 else "-%.1f"%damage
	if damage<0.1:label="-<0.1"
	var font=Ink.theme().default_font
	var font_size=roundi(20*maxf(0.9,zoom))
	var position=at+Vector2(-42*zoom,-(radius+14+age*20)*zoom)
	canvas.draw_string_outline(font,position,label,HORIZONTAL_ALIGNMENT_CENTER,84*zoom,font_size,4,Color(Ink.PAPER,alpha))
	canvas.draw_string(font,position,label,HORIZONTAL_ALIGNMENT_CENTER,84*zoom,font_size,Color(HURT_INK,alpha))

static func paint(canvas, battle, zoom: float):
	Art.prepare()
	var count = 0
	for effect in battle.effects:
		if effect.kind!="segment_break":continue
		if count>=MAX_DEBRIS:break
		count+=1
		var at: Vector2 = canvas.world(effect.position)
		if not Rect2(-200,-200,1840,1300).has_point(at):continue
		var t = progress(effect)
		var fade = 1.0-smoothstep(0.42,1.0,t)
		var flash = maxf(0,1-t*5)
		canvas.draw_circle(at,(18+52*t)*zoom,Color("b7cbd5",flash*0.40))
		canvas.draw_arc(at,(28+65*t)*zoom,0,TAU,40,Color("bb704f",(1-t)*0.8),maxf(0.7,(3-2*t)*zoom),true)
		var texture: Texture2D = Art.pieces.body
		var half = texture.get_size()/2
		for piece in range(4):
			var side = -1.0 if piece%2==0 else 1.0
			var point: Vector2 = canvas.world(debris_position(effect,piece))
			var rotation = float(effect.angle)+side*t*(1.6+piece*0.3)
			canvas.draw_set_transform(point,rotation,Vector2.ONE*zoom*(1-0.24*t))
			canvas.draw_texture_rect_region(texture,Rect2(-14,-14,28,28),Rect2(Vector2(piece%2,floori(piece/2.0))*half,half),Color(1,1,1,fade))
			canvas.draw_polyline(PackedVector2Array([Vector2(-6,side*10),Vector2(-15,side*(26-12*t)),Vector2(-24,side*(33-18*t))]),Color("264774",fade),2.6,true)
			canvas.draw_set_transform(Vector2.ZERO)
		# The colored equipment visibly tumbles away from the broken shell.
		var weapon_at: Vector2 = canvas.world(Vector2(effect.position)+Vector2(effect.weapon_offset)+Vector2(effect.velocity)*t+Vector2(0,-45*t+35*t*t))
		canvas.module_art(canvas.db.core_sprite(canvas.db.asset(effect.id)),weapon_at,Vector2.ONE*float(effect.module_size)*zoom*(1-0.4*t),float(effect.weapon_angle)+PI/2+t*2.2,Color(1,1,1,fade))
		for i in range(7):
			var axis = Vector2.from_angle(i*TAU/7+float(effect.angle))
			canvas.draw_line(at+axis*(25+25*t)*zoom,at+axis*(32+58*t)*zoom,Color("274974",(1-t)*0.7),1.8*zoom,true)
		if t<0.78 and count<=3:
			var label_at = at+Vector2(-48,-55-25*t)*zoom
			canvas.draw_string(Ink.theme().default_font,label_at,"体节损毁",HORIZONTAL_ALIGNMENT_CENTER,96*zoom,roundi(17*zoom),Color("a4573f",minf(1,fade*1.5)))
