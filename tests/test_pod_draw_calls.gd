extends SceneTree
const Props=preload("res://scripts/organic_world_objects.gd")
class Board extends Node2D:
	var mode="blank"
	var ink=preload("res://scripts/blue_ink_layer.gd").new()
	func _ready():ink.show_behind_parent=true;ink.material=preload("res://scripts/blue_ink.gd").illustration();add_child(ink)
	func world(point:Vector2)->Vector2:return point
	func art(texture:Texture2D,at:Vector2,extent:Vector2,angle:float,tint:Color):ink.paint(texture,at,extent,angle,tint)
	func _draw():
		ink.begin_frame()
		if mode=="pod":Props.pod(self,Vector2(400,350),65,1.25,Color("f46b95"))
		if mode=="reward_pod":Props.pod(self,Vector2(400,350),92,1.25,Color("f46b95"),true)
		if mode=="nest":Props.nest(self,Vector2(400,350),1,1.25)
		if mode=="circle":draw_circle(Vector2(400,350),25,Color("11111277"),true,-1,true)
		if mode=="polyline":draw_polyline(PackedVector2Array([Vector2(300,300),Vector2(320,305),Vector2(350,300)]),Color("1b1b1b"),2.4,true)
func _initialize():call_deferred("execute")
func execute():
	root.size=Vector2i(1440,900)
	var board=Board.new();root.add_child(board);var rows:Array=[]
	for mode in ["blank","circle","polyline","pod","reward_pod","nest"]:
		board.mode=mode;board.queue_redraw()
		for i in 6:await process_frame;await RenderingServer.frame_post_draw
		var values:Array=[]
		for i in 8:
			await process_frame;await RenderingServer.frame_post_draw
			values.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		rows.append({"mode":mode,"draw_calls_min":values.min(),"draw_calls_max":values.max()})
	var report={"passed":rows.all(func(row):return row.draw_calls_min==row.draw_calls_max),"rows":rows,"scope":"Actual native GLES3 counters for unchanged generated pod art and original AA geometry, empty scene excludes battle/UI."}
	FileAccess.open("res://artifacts/pod-draw-calls.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
