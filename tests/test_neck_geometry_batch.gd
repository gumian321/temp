extends SceneTree
const Batch=preload("res://scripts/neck_geometry_batch.gd")
const Ink=preload("res://scripts/blue_ink.gd")
const UI=preload("res://scripts/game_ui.gd")
class Canvas extends Node2D:
	var batch=Batch.new()
	var batched=false
	var zoom=1.0
	var cases:Array=[]
	func native_neck(anchor:Vector2,tip:Vector2,alpha:float):
		var bend=(tip-anchor).orthogonal().normalized()*minf(5.0*zoom,anchor.distance_to(tip)*.22)
		var curve=PackedVector2Array()
		for step in 9:
			var t=float(step)/8.0;curve.append(anchor.lerp(tip,t)+bend*sin(t*PI))
		draw_circle(anchor,4.0*zoom,Color(Ink.INK,alpha*.7),true,-1,true)
		draw_polyline(curve,Color(Ink.INK,alpha*.8),6.0*zoom,true)
		draw_polyline(curve,Color(Ink.WASH,alpha),3.0*zoom,true)
	func _draw():
		batch.enabled=batched;batch.begin(self)
		draw_rect(Rect2(20.375,30.125,110,170),Color(.7,.8,.6,.65))
		draw_string(UI.font(),Vector2(30.125,70.375),"原生 text 123",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color(.8,.3,.6,.8))
		for item in cases:
			if not batch.paint(self,item[0],item[1],4.0*zoom,zoom,item[2]):native_neck(item[0],item[1],item[2])
		draw_circle(Vector2(700.125,450.375),31,Color(.5,.3,.7,.4),true,-1,true)
		draw_line(Vector2(30.375,300.125),Vector2(1300.375,850.625),Color(.2,.8,.5,.4),2.35,true)
		batch.finish()
func _initialize():call_deferred("execute")
func capture(canvas,batched:bool)->Dictionary:
	canvas.batched=batched;canvas.queue_redraw()
	for i in 4:await process_frame
	return {"image":root.get_texture().get_image(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func execute():
	root.size=Vector2i(1440,900);RenderingServer.set_default_clear_color(Color("535457"))
	var canvas=Canvas.new();root.add_child(canvas);var rows=[]
	for scenario in 6:
		canvas.zoom=[.4,.65,1.0,1.75,.8,1.0][scenario];canvas.cases.clear()
		for i in (160 if scenario==4 else 48):
			var anchor=Vector2(90+(i%8)*170+(i%3)*.375,100+(i/8)*130+.125)
			if scenario>=4:anchor=Vector2(200.125+(i%7)*5.375,205.375+(i%5)*7.125)
			var delta=Vector2.from_angle(i*.597)*([0.0,.125,2.5,12.0,45.0,80.0][i%6]*canvas.zoom)
			canvas.cases.append([anchor,anchor+delta,.3 if i%5==0 else 1.0])
		var native=await capture(canvas,false);var current=await capture(canvas,true)
		var a=native.image.get_data();var b=current.image.get_data();var changed=0;var maximum=0
		for i in a.size():
			var delta=absi(int(a[i])-int(b[i]));maximum=maxi(maximum,delta)
			if delta>0:changed+=1
		rows.append({"scenario":scenario,"zoom":canvas.zoom,"max_error":maximum,"changed_channels":changed,"native_dc":native.draw_calls,"batched_dc":current.draw_calls})
		if maximum>1:
			native.image.save_png("res://artifacts/neck-production-native-"+str(scenario)+".png");current.image.save_png("res://artifacts/neck-production-batched-"+str(scenario)+".png")
	canvas.cases.clear();await capture(canvas,true)
	var report={"passed":rows.all(func(r):return r.max_error<=1 and r.batched_dc<r.native_dc) and canvas.batch.count==0,"rows":rows,"scope":"Production path, six views, overlapping translucent order, zero/subpixel lengths, capacity fallback160, clear, and native text/line/circle passthrough."}
	FileAccess.open("res://artifacts/neck-geometry-batch.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	canvas.queue_free();await process_frame;quit(0 if report.passed else 1)
