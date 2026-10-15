extends RefCounted
## Opaque, value-coded pickups keep their colors above friendly combat effects.
const TEXTURES = [preload("res://assets/ui_overhaul/energy_crystal_1.png"), preload("res://assets/ui_overhaul/energy_crystal_5.png"), preload("res://assets/ui_overhaul/energy_crystal_20.png")]
const COLORS = [Color("10adc6"), Color("9c50df"), Color("e6a329")]

static func tier(value:int)->int:
	return 2 if value>=20 else (1 if value>=5 else 0)

static func extent(value:int,zoom:float,carried:bool=false)->float:
	var base=[30.0,36.0,44.0][tier(value)]
	return clampf(base*zoom,base*.8,base*1.5)*(0.72 if carried else 1.0)

static func paint(canvas,drop:Dictionary,clock:float,zoom:float):
	if drop.get("delivered",false):return
	var rank=tier(int(drop.get("value",1)))
	var carried=bool(drop.get("carried",false))
	var at:Vector2=canvas.world(drop.position)
	if not canvas.get_viewport_rect().grow(70).has_point(at):return
	var size=extent(int(drop.get("value",1)),zoom,carried)
	var phase=float(drop.get("scatter_to",drop.position).x)*.031+float(drop.get("scatter_to",drop.position).y)*.017
	if carried:
		at+=Vector2(0,12*maxf(.8,zoom))
	else:
		canvas.draw_circle(at+Vector2(0,size*.32),size*.28,Color("173b7024"),true,-1,true)
		at.y-=2+sin(clock*2+phase)*2
		canvas.draw_arc(at,size*.48,0,TAU,24,Color(COLORS[rank],.32),1.2,true)
	canvas.draw_circle(at,size*.38,Color("fffaf0cc"),true,-1,true)
	var texture:Texture2D=TEXTURES[rank]
	var bounds=texture.get_size()*size/maxf(texture.get_width(),texture.get_height())
	canvas.draw_texture_rect(texture,Rect2(at-bounds*.5,bounds),false)
