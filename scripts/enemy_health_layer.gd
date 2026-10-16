extends Node2D
## One unshaded screen-space batch, above combat particles and below menu/HUD.
## Never interpolate the true health fill: its end always means current HP.
const Brood=preload("res://scripts/brood_theme.gd")
const FRAME=Color("101522")
const EMPTY=Color("394353")
const EDGE=Color("d8e4ee")
const HEALTH=Color("ff657c")
const LOW=Color("ffc14c")
const SHIELD=Color("5be7ff")
var game
var bars:Array=[]
var shield_sources:Array=[]

static func eligible(e:Dictionary)->bool:
	return float(e.get("hp",0))>0 and float(e.get("max_hp",0))>0 and e.get("role","")!="friendly" and not e.get("cloaked",false) and float(e.get("warp",0))<=0

static func bar_size(e:Dictionary)->Vector2:
	if e.get("kind","")=="AIBossUnit":return Vector2(88,8)
	if e.get("objective",false) or float(e.get("radius",18))>=30:return Vector2(64,7)
	return Vector2(48,6)

func rebuild():
	bars.clear();shield_sources.clear()
	if game==null or game.combat==null or not game.screen in ["game","pause","result","rewards"] or game.radar_mode:return
	var view:Rect2=game.get_viewport_rect()
	var radar=Rect2(view.size-Vector2(210,235),Vector2(180,150)).grow(6)
	for e in game.combat.enemies:
		if float(e.get("hp",0))<=0 or float(e.get("stun",0))>0:continue
		for gun in e.get("guns",[]):
			var core:Dictionary=game.db.asset(gun.id)
			if core.get("class","")!="ShieldCore":continue
			var hp=float(gun.get("shield",core.maxShieldHealth))
			if hp>0:shield_sources.append({"point":e.position,"radius2":pow(float(core.ShieldRange)*48,2),"ratio":clampf(hp/maxf(1,float(core.maxShieldHealth)),0,1),"role":e.get("role","")})
	# Small spatial occupancy table avoids quadratic layout when a swarm overlaps.
	var occupied:Dictionary={}
	for e in game.combat.enemies:
		if not eligible(e):continue
		var point:Vector2=game.world(e.position)
		if not view.grow(80).has_point(point):continue
		var hp=Vector2(float(e.hp),float(e.max_hp))
		# Boss hp/max_hp already aggregate all original parts in Combat.
		# Do not normalize by surviving parts: destroying one must not refill it.
		if not e.get("damageable",true) and e.get("kind","")!="AIBossUnit":continue
		if hp.y<=0 or hp.x<=0:continue
		var extent=Brood.extent(e)*0.5 if Brood.eligible(e) else float(e.get("radius",18))
		var size=bar_size(e)
		var anchor=(point-Vector2(size.x*0.5,extent*game.zoom+14)).round()
		var at=anchor
		# At most three short lifts; keep association with the insect via a stem.
		for attempt in range(4):
			at=anchor-Vector2(0,attempt*12)
			var left=Vector2i(floori(at.x/24),floori(at.y/12))
			var right=Vector2i(floori((at.x+size.x)/24),floori((at.y+size.y)/12))
			var free=true
			for x in range(left.x,right.x+1):
				for y in range(left.y,right.y+1):
					if occupied.has(Vector2i(x,y)):free=false
			if free or attempt==3:
				for x in range(left.x,right.x+1):
					for y in range(left.y,right.y+1):occupied[Vector2i(x,y)]=true
				break
		var rect=Rect2(at,size)
		if not view.intersects(rect.grow(3)) or radar.intersects(rect.grow(3)):continue
		var shield=0.0
		for source in shield_sources:
			if (source.role=="friendly")== (e.get("role","")=="friendly") and Vector2(e.position).distance_squared_to(source.point)<source.radius2:
				shield=source.ratio
				break # Same first eligible provider consumed by Combat.hit_enemy.
		bars.append({"rect":rect,"ratio":clampf(hp.x/hp.y,0,1),"shield":shield,"anchor":anchor,"uid":e.uid})

func _draw():
	rebuild()
	for bar in bars:
		var rect:Rect2=bar.rect
		draw_rect(rect.grow(2),FRAME)
		draw_rect(rect.grow(1),EDGE)
		draw_rect(rect,EMPTY)
		# Fractional fill stays truthful even below one pixel; no minimum fake HP.
		draw_rect(Rect2(rect.position,Vector2(rect.size.x*bar.ratio,rect.size.y)),LOW if bar.ratio<=0.25 else HEALTH)
		if bar.shield>0:
			var strip=Rect2(rect.position-Vector2(0,6),Vector2(rect.size.x,3))
			draw_rect(strip.grow(1),FRAME)
			draw_rect(strip,EMPTY)
			draw_rect(Rect2(strip.position,Vector2(strip.size.x*bar.shield,3)),SHIELD)
	# Group line primitives after every filled rectangle, avoiding rect/line
	# batch breaks for each enemy. No per-enemy node or material.
	for bar in bars:
		var rect:Rect2=bar.rect
		if rect.position!=bar.anchor:draw_line(Vector2(rect.get_center().x,rect.end.y+2),Vector2(rect.get_center().x,bar.anchor.y+rect.size.y+3),FRAME,1)
		for tick in [0.25,0.5,0.75]:
			var x=roundf(rect.position.x+rect.size.x*tick)
			draw_line(Vector2(x,rect.end.y-2),Vector2(x,rect.end.y),FRAME,1)
