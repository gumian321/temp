extends RefCounted
## A continuous flexible centreline; the root follows the organ and the tip lags.
## Kept inside the existing secretion corridor, so damage/range stay unchanged.
const SEGMENTS=24

static func advance(state:Dictionary,root:Vector2,axis:Vector2,reach:float,dt:float)->PackedVector2Array:
	axis=axis.normalized()
	if axis.is_zero_approx():axis=Vector2.RIGHT
	state.clock=float(state.get("clock",0))+maxf(0,dt)
	var side=axis.orthogonal()
	var points:PackedVector2Array=state.get("points",PackedVector2Array())
	var fresh=points.size()!=SEGMENTS+1 or points[0].distance_to(root)>reach*1.5
	if fresh:points.resize(SEGMENTS+1)
	var phase=float(state.clock)*8.0+float(state.get("phase",0))
	for i in range(SEGMENTS+1):
		var t=float(i)/SEGMENTS
		var offset=sin(phase-t*6.5)*reach*.145*t*sin(t*PI*.8)
		var desired=root+axis*reach*t+side*offset
		if fresh:points[i]=desired
		else:points[i]=points[i].lerp(desired,1-exp(-(25.0-14.0*t)*maxf(0,dt)))
		# Steering cannot make the visible whip hit behind its real firing cone.
		var along=clampf((points[i]-root).dot(axis),0,reach)
		var across=clampf((points[i]-root).dot(side),-along*.18,along*.18)
		points[i]=root+axis*along+side*across
	points[0]=root
	for pass_index in 3:
		var previous=points.duplicate()
		for i in range(1,SEGMENTS):points[i]=previous[i].lerp((previous[i-1]+previous[i+1])*.5,.4)
	state.points=points;state.idle=0.0
	return points

static func paint(canvas,points:PackedVector2Array,zoom:float,color:Color,accent:Color,alpha:float=1.0,retraction:float=1.0):
	if points.size()<2:return
	var root=points[0]
	# Overlapping tapered segments avoid self-crossing polygon triangulation.
	for i in range(1,points.size()):
		var t=float(i)/(points.size()-1)
		var a=canvas.world(root+(points[i-1]-root)*retraction)
		var b=canvas.world(root+(points[i]-root)*retraction)
		var width=lerpf(8.0,.65,pow(t,.8))*zoom
		canvas.draw_line(a,b,Color(accent,alpha*.3),width*2.1,true)
		canvas.draw_line(a,b,Color(color,alpha*.96),width,true)
		canvas.draw_line(a,b,Color("fff0bd",alpha*.8),maxf(.45,width*.26),true)
