extends SceneTree
const Prototype=preload("res://tests/prototypes/ordered_pointer_geometry.gd")
var checks:Array=[]
class Board extends Node2D:
	var entries:Array=[]
	var backend="native"
	var geometry=Prototype.new()
	var submit_us=0
	func _draw():
		geometry.begin();var started=Time.get_ticks_usec()
		for entry in entries:
			var at:Vector2=entry.at;var direction:Vector2=entry.direction
			if backend!="native":geometry.paint(self,at,direction,backend=="absolute_mesh");continue
			var side=direction.orthogonal();var tip=at+direction*12;var base=at-direction*14
			var outline=PackedVector2Array([tip,base+side*9,base+direction*6,base-side*9,tip])
			draw_colored_polygon(outline,Color("121212"));draw_polyline(outline,Color("d7d3c3"),1.4,true)
			draw_line(base+direction*8,tip-direction*3,Color("ff387c"),2.0,true)
			var gem=base-direction*12
			draw_colored_polygon(PackedVector2Array([gem+direction*6,gem+side*4,gem-direction*6,gem-side*4]),Color("ff387c"))
		submit_us=Time.get_ticks_usec()-started
func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)
func picture(board:Board,backend:String)->Dictionary:
	board.backend=backend;board.queue_redraw()
	for i in 3:await process_frame;await RenderingServer.frame_post_draw
	return {"image":root.get_texture().get_image(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"submit_us":board.submit_us}
func compare(a:Image,b:Image)->Dictionary:
	var left=a.get_data();var right=b.get_data();var maximum=0;var channels=0
	for i in left.size():
		var difference=absi(int(left[i])-int(right[i]));maximum=maxi(maximum,difference)
		if difference:channels+=1
	return {"maximum_channel_error":maximum,"changed_channels":channels,"byte_identical":left==right}
func execute():
	if DisplayServer.get_name()=="headless":push_error("Pointer test needs native renderer");quit(1);return
	root.size=Vector2i(1440,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var backdrop=ColorRect.new();backdrop.color=Color("38353b");backdrop.size=Vector2(1440,900);root.add_child(backdrop)
	var board=Board.new();root.add_child(board);var rows:Array=[]
	for scenario in 7:
		board.entries.clear()
		for i in 16:
			var at=Vector2(110+(i%4)*390,130+(i/4)*210)+Vector2(.375,.8125)*scenario
			if scenario==4:at=Vector2(680,420)+Vector2(i*.4,i*.35)
			if scenario==5:at=Vector2(-4+(i%4)*480,-6+(i/4)*300)
			if scenario==6:at=Vector2(1460+(i%4)*20,920+(i/4)*25)
			var angle=TAU*float(i)/16+scenario*.1275
			board.entries.append({"at":at,"direction":Vector2.from_angle(angle)})
		var native=await picture(board,"native")
		for backend in ["cached_template","absolute_mesh"]:
			var candidate=await picture(board,backend);var pixels=compare(native.image,candidate.image)
			rows.append({"scenario":scenario,"backend":backend,"native_draw_calls":native.draw_calls,"candidate_draw_calls":candidate.draw_calls,"native_submit_us":native.submit_us,"candidate_submit_us":candidate.submit_us,"pixels":pixels})
			check(pixels.maximum_channel_error<=1,"Pointer scenario %d %s preserves pixels within1/255"%[scenario,backend])
			check(candidate.draw_calls<=native.draw_calls,"Pointer scenario %d %s never adds draws"%[scenario,backend])
			if pixels.maximum_channel_error>1:
				native.image.save_png("res://artifacts/pointer-native-%d.png"%scenario);candidate.image.save_png("res://artifacts/pointer-%s-%d.png"%[backend,scenario])
	board.entries.clear()
	for i in 4:board.entries.append({"at":Vector2(100+i*340,420),"direction":Vector2.from_angle(i*.8275)})
	var timing:Array=[]
	for backend in ["native","cached_template","absolute_mesh","absolute_mesh","cached_template","native"]:
		board.backend=backend;var total=0
		for i in 70:
			board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			if i>=10:total+=board.submit_us
		timing.append({"backend":backend,"submit_mean_us":float(total)/60,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	var report={"passed":checks.all(func(item):return item.passed),"checks":checks,"comparisons":rows,"four_pointer_warm_submission":timing,"scope":"Boss arrow geometry only. Original text untouched. Native polygon/AApolyline/AAline/gem order retained. Cached template uses an exact direction/orthogonal basis; absolute fallback compiles source coordinates."}
	FileAccess.open("res://artifacts/pointer-geometry-batch.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));board.queue_free();quit(0 if report.passed else 1)
