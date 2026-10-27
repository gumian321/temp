extends RefCounted
## Replace the remaining factory/crate placeholders with biological world props.
const Wet=preload("res://scripts/viscous_projectiles.gd")
const COLORS=[Color("b9b7ae"),Color("54bdce"),Color("b681d1"),Color("e0b364")]
const GeometryBatch=preload("res://scripts/pod_geometry_batch.gd")
static var use_geometry_batch=OS.get_environment("RBPEW_ENABLE_POD_GEOMETRY_BATCH")!="0" and OS.get_environment("RBPEW_LEGACY_POD_GEOMETRY_BATCH")!="1"

static func pod(canvas,at:Vector2,size:float,clock:float,accent:Color,reward:bool=false):
	if not canvas.get_viewport_rect().grow(size).has_point(at):return
	if use_geometry_batch and GeometryBatch.paint(canvas,at,size,clock,accent,reward):return
	var breathing=1.0+sin(clock*2.2+at.x*.01)*.025
	canvas.draw_circle(at+Vector2(0,size*.22),size*.37,Color("11111277"),true,-1,true)
	var extent=Vector2(size*.95,size*.88)*breathing
	canvas.art(Wet.texture("egg"),at,extent,-PI/2,Color.WHITE)
	# Root filaments and a lit seam identify a living pod, not a metal crate.
	for side in [-1,1]:
		var line=PackedVector2Array()
		for i in 9:
			var t=float(i)/8
			line.append(at+Vector2(side*size*(.12+.31*t),size*(.15+.16*sin(t*PI))))
		canvas.draw_polyline(line,Color("1b1b1b"),2.4,true)
		canvas.draw_polyline(line,Color("aaa89c"),.8,true)
	canvas.draw_arc(at,extent.y*.28,-1.25,1.05,15,Color(accent,.8),1.3,true)
	if reward:
		var glint=PackedVector2Array([at+Vector2(0,-9),at+Vector2(5,0),at+Vector2(0,9),at+Vector2(-5,0)])
		canvas.draw_colored_polygon(glint,accent)
		canvas.draw_line(at-Vector2(0,5),at+Vector2(0,4),Color("fff4dd"),1.1,true)

static func container(canvas,actor:Dictionary,at:Vector2,zoom:float,clock:float):
	var rarity=clampi(int(actor.get("unit",{}).get("containerRarity",0)),0,3)
	pod(canvas,at,maxf(46,float(actor.radius)*3.3)*zoom,clock,COLORS[rarity])

static func loot(canvas,drop:Dictionary,zoom:float,clock:float):
	if drop.get("delivered",false):return
	var at:Vector2=canvas.world(drop.position)
	var carried=bool(drop.get("carried",false))
	at+=Vector2(0,10 if carried else -2-sin(clock*2.5+at.x*.03)*2)
	pod(canvas,at,(28 if carried else 44)*zoom,clock,Color("ff508d"),true)

static func nest(canvas,position:Vector2,zoom:float,clock:float,friendly:bool=false):
	var at:Vector2=canvas.world(position)
	if not canvas.get_viewport_rect().grow(160*zoom).has_point(at):return
	var color=Color("6ac8c7") if friendly else Color("f46b95")
	for i in 5:
		var offset=Vector2.from_angle(i*TAU/5)*43*zoom
		pod(canvas,at+offset,65*zoom,clock+i,color)
	pod(canvas,at,92*zoom,clock,color,true)
