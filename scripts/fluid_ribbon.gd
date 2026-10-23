extends RefCounted
## Shared moving membrane for beams and spray. Bodies/impact decals remain separate.
const Layers=preload("res://scripts/attack_shader_layer.gd")
const Trails=preload("res://scripts/projectile_trails.gd")
const TAIL=0
const BEAM=1
const JET=2
const MAX_SEGMENTS=12
const MAX_STRIPS=12

static func line(start:Vector2,finish:Vector2,segments:int=MAX_SEGMENTS)->PackedVector2Array:
	var points=PackedVector2Array();points.resize(segments+1)
	for i in range(segments+1):points[i]=start.lerp(finish,float(i)/segments)
	return points

class Batch extends RefCounted:
	static var uv_cache:Dictionary={}
	var vertices=PackedVector2Array()
	var colors=PackedColorArray()
	var uvs=PackedVector2Array()
	var triangles=PackedInt32Array()
	var fallback:Array=[]
	var count=0
	func add(canvas,points:PackedVector2Array,width:float,time:float,phase:float,mode:int=TAIL,alpha:float=1.0,friendly:bool=true,pigment:Color=Color("b9cd48")):
		if count>=MAX_STRIPS or points.size()<2 or alpha<=0 or width<=0:return
		var segments=mini(points.size()-1,MAX_SEGMENTS)
		if points[0].distance_squared_to(points[-1])<.01:return
		count+=1
		var offset=vertices.size()
		var flag=2+mode*2+int(not friendly)
		var encoded=canvas is Layers.Painter
		var left=PackedVector2Array();var right=PackedVector2Array()
		for i in range(segments+1):
			var index=int(float(i)*(points.size()-1)/segments)
			var prior=int(float(maxi(0,i-1))*(points.size()-1)/segments)
			var next=int(float(mini(segments,i+1))*(points.size()-1)/segments)
			var normal=(points[next]-points[prior]).normalized().orthogonal()*width*.5
			var t=float(i)/segments
			var at=points[index]
			if encoded:
				var normal_scale=16.0 if mode==TAIL else 128.0
				var data=Color(.5+normal.x/normal_scale,.5+normal.y/normal_scale,phase,alpha)
				for bank in 3:vertices.append(at);colors.append(data)
			else:
				var wave=sin(t*10.0-time*18.0+phase)*sin(t*PI)*(1.05 if mode==BEAM else .65)
				var taper=pow(1.0-t,.55) if mode==TAIL else (.65+.35*sin(t*PI))
				if mode==JET:taper=.2+.8*pow(maxf(0,sin(t*PI)),.6)
				at+=normal*wave
				var extent=normal*taper*(.88+.12*sin(t*14.0-time*21.0+phase))
				var opacity=alpha*(1.0-t if mode==TAIL else 1.0)
				vertices.append_array(PackedVector2Array([at-extent,at-extent*.22,at+extent]))
				colors.append_array(PackedColorArray([Color(pigment.darkened(.5),opacity*.25),Color(pigment.lerp(Color("fff4cf"),.6),opacity),Color(pigment,opacity*.25)]))
				left.append(at-extent);right.append(at+extent)
		var key=segments*10+flag
		if not uv_cache.has(key):
			var coordinates=PackedVector2Array()
			for i in range(segments+1):
				var t=float(i)/segments
				coordinates.append_array(PackedVector2Array([Vector2(t,flag),Vector2(t,flag+.39),Vector2(t,flag+.999)]))
			uv_cache[key]=coordinates
		uvs.append_array(uv_cache[key])
		for index in Trails.indices(segments):triangles.append(offset+index)
		if not encoded and not canvas is Node2D:
			var outline=left
			for i in range(right.size()-1,-1,-1):outline.append(right[i])
			fallback.append({"points":outline,"color":Color(pigment,alpha*.7)})
	func flush(canvas):
		if vertices.is_empty():return
		canvas.draw_set_transform(Vector2.ZERO)
		if canvas is Layers.Painter:canvas.draw_triangle_array(triangles,vertices,colors,uvs)
		elif canvas is Node2D:RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),triangles,vertices,colors)
		else:
			for strip in fallback:canvas.draw_colored_polygon(strip.points,strip.color)

static func paint(canvas,points:PackedVector2Array,width:float,time:float,phase:float=0.0,mode:int=TAIL,alpha:float=1.0,friendly:bool=true,pigment:Color=Color("b9cd48")):
	var batch=Batch.new();batch.add(canvas,points,width,time,phase,mode,alpha,friendly,pigment);batch.flush(canvas)
