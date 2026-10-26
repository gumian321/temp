extends SceneTree
const Organs=preload("res://scripts/soft_organ_art.gd")
const Art=preload("res://scripts/insect_armaments.gd")
var checks:Array=[]
var comparisons:Array=[]

class Board extends Node2D:
	var organs=Organs.new()
	var variants=Art.entries().keys()
	var pose=0
	var timings:Array=[]
	var count=60
	func _draw():
		organs.begin_frame()
		var started=Time.get_ticks_usec()
		for i in count:
			var variant=variants[i%variants.size()]
			organs.paint(self,"player:"+str(i),Art.texture(variant),Vector2(80+i%10*140,100+i/10*125),Vector2(90,90),float(i%4)*.4,variant,NAN if pose==4 else [0.0,.72,.83,1.75][pose],[0.0,.18,.07,0.0][pose%4],Color(.88,1,.94,.8 if i%3==0 else 1.0),float(i),1.0,Vector2(1,-.4),[-.24,0.0,.2,.36][pose%4])
		timings.append(Time.get_ticks_usec()-started)

func check(value:bool,message:String):
	checks.append({"passed":value,"name":message})
	if not value:push_error(message)
func _initialize():call_deferred("execute")
func frame_image(board:Board)->Image:
	board.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func execute():
	if DisplayServer.get_name()=="headless":push_error("Organ GPU comparison requires --render");quit(1);return
	root.size=Vector2i(1440,900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var cpu=Board.new();root.add_child(cpu)
	var gpu=Board.new();gpu.organs.use_gpu=true;gpu.hide();root.add_child(gpu)
	for pose in 5:
		cpu.pose=pose;gpu.pose=pose;cpu.show();gpu.hide()
		var reference=await frame_image(cpu)
		cpu.hide();gpu.show()
		var actual=await frame_image(gpu)
		var a=reference.get_data();var b=actual.get_data();var error=0;var different=0
		for i in a.size():
			var difference=absi(int(a[i])-int(b[i]));error+=difference
			if difference>16:different+=1
		var mean=float(error)/a.size();var fraction=float(different)/a.size()
		comparisons.append({"pose":pose,"mean_channel_error_255":mean,"channels_over_16_fraction":fraction})
		check(mean<.7 and fraction<.005,"CPU/GPU artwork parity, including recoil, tint and traction: pose "+str(pose))
		if pose==2:
			reference.save_png("res://artifacts/organ-cpu-reference-20261025.png")
			actual.save_png("res://artifacts/organ-gpu-20261025.png")
	var costs:Dictionary={}
	for board in [cpu,gpu]:
		cpu.visible=board==cpu;gpu.visible=board==gpu
		board.timings.clear()
		for i in 120:
			board.pose=i%4;board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		var sum=0.0
		for cost in board.timings.slice(10):sum+=cost
		costs["gpu" if board==gpu else "cpu"]=sum/maxi(1,board.timings.size()-10)/1000.0
	check(costs.gpu<costs.cpu,"Sixty organs reduce CPU submission cost without reducing animation frequency")
	gpu.count=1
	await frame_image(gpu);await frame_image(gpu)
	check(gpu.organs.gpu.items.size()==1 and gpu.organs.gpu.geometry.size()==1,"Removed organs release retained items and unused geometry")
	gpu.count=0
	await frame_image(gpu);await frame_image(gpu)
	check(gpu.organs.gpu.items.is_empty() and gpu.organs.gpu.geometry.is_empty(),"Leaving combat clears all retained organs")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"comparisons":comparisons,"sixty_organs_cpu_ms":costs,"scope":"Same 60 poses, atlas art, mesh resolution, tint and traction; native OpenGL submission time, not whole-game FPS."}
	FileAccess.open("res://artifacts/organ-gpu-20261025.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));cpu.queue_free();gpu.queue_free();await process_frame;quit(0 if report.passed else 1)
