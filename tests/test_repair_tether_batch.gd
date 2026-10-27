extends SceneTree
const Layers=preload("res://scripts/attack_shader_layer.gd")
const Feedback=preload("res://scripts/passive_feedback.gd")
class Board extends Node2D:
	var layer=Layers.new()
	var passive=Feedback.new()
	var drones:Array=[]
	var zoom=1.0
	var clock=.271
	var optimized=false
	func _ready():layer.attach(self)
	func world(at:Vector2)->Vector2:return at*zoom+Vector2(719.375,449.125)
	func _draw():
		draw_rect(get_viewport_rect(),Color("383836"));layer.begin_frame(clock);passive.clock=clock
		layer.repair_tether_batch.enabled=optimized
		for drone in drones:
			passive.paint_repair_tether(self,drone,zoom)
		layer.end_frame()
func _initialize():call_deferred("execute")
func picture(board:Board)->Dictionary:
	board.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return {"image":root.get_texture().get_image(),"dc":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func execute():
	root.size=Vector2i(1440,900)
	var board=Board.new();root.add_child(board)
	for i in 48:
		var position=Vector2(-180+(i%8)*45,-170+(i/8)*61)+Vector2(.375,-.125)
		var end=position+Vector2.from_angle(i*.33)*[0.0,.125,2.5,12.0,45.0,80.0][i%6]
		board.drones.append({"position":position,"target":{"position":end},"angle":i*.75,"friendly":i%2==0})
	var before=board.drones.duplicate(true);var rows:Array=[]
	for zoom in [.4,.65,1.0,1.75]:
		board.zoom=zoom;board.optimized=false
		var original=await picture(board)
		board.optimized=true
		var candidate=await picture(board)
		var a=original.image.get_data();var b=candidate.image.get_data();var maximum=0;var changed=0
		for i in a.size():
			var difference=absi(int(a[i])-int(b[i]));maximum=maxi(maximum,difference)
			if difference:changed+=1
		rows.append({"zoom":zoom,"native_dc":original.dc,"batch_dc":candidate.dc,"max_channel_error":maximum,"changed_channels":changed})
		if maximum>1:
			original.image.save_png("res://artifacts/repair-tether-native-"+str(zoom)+".png")
			candidate.image.save_png("res://artifacts/repair-tether-batched-"+str(zoom)+".png")
	var result={"passed":rows.all(func(r):return r.max_channel_error<=1 and r.batch_dc<r.native_dc),"simulation_unchanged":before==board.drones,"comparisons":rows,"scope":"Original passive repair tether method compared with shared ordered native AA topology in the original attack shader/material and streams; no gameplay writes."}
	FileAccess.open("res://artifacts/repair-tether-batch.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(JSON.stringify(result))
	board.queue_free();await process_frame;quit(0 if result.passed and result.simulation_unchanged else 1)
