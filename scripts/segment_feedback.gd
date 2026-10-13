extends RefCounted
## Detached visual snapshots never retain a gameplay owner or mutable part.
const Art = preload("res://scripts/centipede_art.gd")
const Ink = preload("res://scripts/blue_ink.gd")
const LIFETIME = 0.95
const MAX_DEBRIS = 24
const HIT_TIME = 0.20

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

static func paint_hit(canvas, at: Vector2, angle: float, strength: float, zoom: float):
	if strength<=0:return
	var alpha = clampf(strength/HIT_TIME,0,1)
	canvas.draw_arc(at,(32+(1-alpha)*12)*zoom,0,TAU,32,Color("c8754d",alpha),2.8*zoom,true)
	canvas.draw_set_transform(at,angle,Vector2.ONE*zoom)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-23,-20),Vector2(20,-22),Vector2(24,20),Vector2(-21,23)]),Color(1,0.88,0.67,alpha*0.43))
	canvas.draw_polyline(PackedVector2Array([Vector2(-17,-14),Vector2(-4,-5),Vector2(-9,3),Vector2(10,13)]),Color("fff2ce",alpha),2.4,true)
	canvas.draw_set_transform(Vector2.ZERO)

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
