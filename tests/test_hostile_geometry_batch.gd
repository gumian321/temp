extends SceneTree
const Layers=preload("res://scripts/attack_shader_layer.gd")
const Organic=preload("res://scripts/insect_projectiles.gd")
const FAMILIES=["gatling","shotgun","cannon","flak","rocket","nuke","emp","blackhole","sonic"]
class Board extends Node2D:
	var layer=Layers.new()
	var shots:Array=[]
	var zoom=1.0
	var clock=1.37
	var batched=false
	var submit_us=0
	func _ready():layer.attach(self)
	func world(at:Vector2)->Vector2:return at
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("b4b1a5"))
		layer.use_hostile_geometry_batch=batched;layer.begin_frame(clock)
		var began=Time.get_ticks_usec()
		for shot in shots:Organic.paint(self,shot,zoom,clock)
		submit_us=Time.get_ticks_usec()-began;layer.end_frame()
func _initialize():call_deferred("execute")
func picture(board:Board,batched:bool)->Dictionary:
	board.batched=batched
	for i in 5:board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	return {"image":root.get_texture().get_image(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"submit_us":board.submit_us}
func delta(a:Image,b:Image)->Dictionary:
	var x=a.get_data();var y=b.get_data();var maximum=0;var changed=0
	for i in x.size():
		var error=absi(int(x[i])-int(y[i]));maximum=maxi(maximum,error)
		if error:changed+=1
	return {"byte_identical":x==y,"max_channel_error":maximum,"changed_channels":changed}
func execute():
	if DisplayServer.get_name()=="headless":push_error("Native renderer required");quit(2);return
	root.size=Vector2i(1440,900)
	var board=Board.new();root.add_child(board);var rows:Array=[];var unchanged=true;var reused=true
	for scenario in 6:
		board.zoom=[.4,1.0,1.8,.8,1.0,1.0][scenario];board.clock=1.37+scenario*.71;board.shots=[]
		var count=240 if scenario==5 else 72
		for i in count:
			var at=Vector2(100+(i%12)*110,110+(i/12)*130)+Vector2(.375,.8125)*scenario
			if scenario in [3,4]:at=Vector2(600+i%9*7,340+i/9*9)+Vector2(.375,.125)
			if scenario==5:at=Vector2(50+i%20*68,60+i/20*65)+Vector2(.375,.125)
			var axis=Vector2.from_angle(i*.371+scenario*.12)
			var radius:float=4.0 if scenario==5 else ([4.0,8.0,4.0][i%3] if scenario==4 else [4.0,5.5,8.0][i%3])
			board.shots.append({"position":at,"previous":at-axis*20,"origin":at-axis*70,"velocity":axis*600,"radius":radius,"friendly":false,"fx_family":"gatling" if scenario>=4 else FAMILIES[i%9],"data":{},"projectile_trail":{"visual_id":i+1}})
		var before=board.shots.duplicate(true)
		var original=await picture(board,false);var current=await picture(board,true)
		var pixels=delta(original.image,current.image)
		var builds=[board.layer.projectile_geometry_builds,board.layer.hostile_shape_builds]
		var warm=await picture(board,true)
		reused=reused and builds==[board.layer.projectile_geometry_builds,board.layer.hostile_shape_builds];unchanged=unchanged and before==board.shots
		var instancing=board.layer.hostile_body_batch.stats()
		rows.append({"scenario":scenario,"shots":count,"zoom":board.zoom,"native_draw_calls":original.draw_calls,"batched_draw_calls":current.draw_calls,"native_warm_submit_us":original.submit_us,"batched_warm_submit_us":warm.submit_us,"pixels":pixels,"instancing":instancing})
		if scenario==1 or pixels.max_channel_error>1:
			original.image.save_png("res://artifacts/hostile-geometry-native-%d.png"%scenario);current.image.save_png("res://artifacts/hostile-geometry-batched-%d.png"%scenario)
	board.shots=[];await picture(board,true)
	var hidden=board.layer.retained_projectiles.values().all(func(entry):return not entry.visible) and board.layer.hostile_body_batch.stats().instances==0 and Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)==1
	var passed=rows.all(func(row):return row.pixels.max_channel_error<=1 and row.batched_draw_calls<row.native_draw_calls) and unchanged and reused and hidden
	var report={"passed":passed,"comparisons":rows,"state_unchanged":unchanged,"warm_geometry_reused":reused,"cleared_shapes_hidden":hidden,"scope":"Native production attack shaders; canonical hostile geometry cached as shared meshes, instanced only across consecutive equal shapes in each existing material stream. All nine families, fractional poses/zoom, A-B-A overlapping shape order, capacity growth to240, warm reuse and removal. No projectile/simulation edits."}
	FileAccess.open("res://artifacts/hostile-geometry-batch.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));board.queue_free();quit(0 if passed else 1)
