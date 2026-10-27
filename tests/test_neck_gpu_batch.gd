extends SceneTree
const Batch=preload("res://tests/prototypes/neck_gpu_batch.gd")
const Ink=preload("res://scripts/blue_ink.gd")
class Canvas extends Node2D:
	var batch=Batch.new()
	var batched=false
	var zoom=1.0
	var cases:Array=[]
	func _draw():
		if batched:
			batch.begin(zoom)
			for item in cases:batch.append(item[0],item[1],4.0*zoom,zoom,item[2])
			batch.finish();draw_multimesh(batch.instances,null)
		else:
			for item in cases:
				var anchor:Vector2=item[0];var tip:Vector2=item[1];var alpha:float=item[2]
				var bend=(tip-anchor).orthogonal().normalized()*minf(5.0*zoom,anchor.distance_to(tip)*.22)
				var curve=PackedVector2Array()
				for step in 9:
					var t=float(step)/8.0;curve.append(anchor.lerp(tip,t)+bend*sin(t*PI))
				draw_circle(anchor,4.0*zoom,Color(Ink.INK,alpha*.7),true,-1,true)
				draw_polyline(curve,Color(Ink.INK,alpha*.8),6.0*zoom,true)
				draw_polyline(curve,Color(Ink.WASH,alpha),3.0*zoom,true)
func _initialize():call_deferred("execute")
func capture(canvas,batched:bool)->Dictionary:
	canvas.batched=batched;canvas.material=canvas.batch.material if batched else null;canvas.queue_redraw()
	for i in 4:await process_frame
	return {"image":root.get_texture().get_image(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func execute():
	root.size=Vector2i(1440,900);RenderingServer.set_default_clear_color(Color("535457"))
	var canvas=Canvas.new();root.add_child(canvas)
	var rows=[]
	for scenario in 4:
		canvas.zoom=[.4,1.0,1.8,.8][scenario];canvas.cases.clear()
		for i in 48:
			var anchor=Vector2(90+(i%8)*170+(i%3)*.375,100+(i/8)*130+.125)
			var delta=Vector2.from_angle(i*.597)*([0.0,.125,2.5,12.0,45.0,80.0][i%6]*canvas.zoom)
			canvas.cases.append([anchor,anchor+delta,.3 if i%5==0 else 1.0])
		var native=await capture(canvas,false);var current=await capture(canvas,true)
		var a=native.image.get_data();var b=current.image.get_data();var changed=0;var maximum=0
		for i in a.size():
			var delta=absi(int(a[i])-int(b[i]));maximum=maxi(maximum,delta)
			if delta>0:changed+=1
		rows.append({"zoom":canvas.zoom,"max_error":maximum,"changed_channels":changed,"native_dc":native.draw_calls,"batched_dc":current.draw_calls})
		if maximum>1:
			native.image.save_png("res://artifacts/neck-gpu-native-"+str(scenario)+".png")
			current.image.save_png("res://artifacts/neck-gpu-batched-"+str(scenario)+".png")
	var report={"passed":rows.all(func(r):return r.max_error<=1),"rows":rows}
	FileAccess.open("res://artifacts/neck-gpu-batch.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	canvas.queue_free();await process_frame;quit(0 if report.passed else 1)
