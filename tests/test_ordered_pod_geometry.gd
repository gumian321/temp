extends SceneTree
const Props=preload("res://scripts/organic_world_objects.gd")
const Prototype=preload("res://tests/prototypes/ordered_pod_geometry.gd")
var checks:Array=[]
class Board extends Node2D:
	var backend="native"
	var entries:Array=[]
	var geometry:Array=[]
	var static_geometry:Dictionary={}
	var build_us=0
	var submit_us=0
	var ink=preload("res://scripts/blue_ink_layer.gd").new()
	func _ready():
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ink.show_behind_parent=true;ink.material=preload("res://scripts/blue_ink.gd").illustration();add_child(ink)
	func world(point:Vector2)->Vector2:return point
	func art(texture:Texture2D,at:Vector2,extent:Vector2,angle:float,tint:Color):ink.paint(texture,at,extent,angle,tint)
	func prepare():
		geometry.clear();var began=Time.get_ticks_usec()
		for entry in entries:
			var item=Prototype.new();item.build(entry.at,entry.size,entry.clock,entry.accent,entry.reward);geometry.append(item)
			if not static_geometry.has(entry.size):
				var retained=Prototype.new();retained.build_static(entry.size);static_geometry[entry.size]=retained
		build_us=Time.get_ticks_usec()-began
	func _draw():
		ink.begin_frame()
		var began=Time.get_ticks_usec()
		for i in entries.size():
			var entry=entries[i]
			if backend=="native":Props.pod(self,entry.at,entry.size,entry.clock,entry.accent,entry.reward)
			else:
				var breathing=1.0+sin(entry.clock*2.2+entry.at.x*.01)*.025
				art(preload("res://scripts/viscous_projectiles.gd").texture("egg"),entry.at,Vector2(entry.size*.95,entry.size*.88)*breathing,-PI/2,Color.WHITE)
				if backend=="triangle_array":geometry[i].submit(self)
				else:static_geometry[entry.size].submit_static(self,entry.at,entry.size,entry.clock,entry.accent,entry.reward,backend=="static_mesh")
		submit_us=Time.get_ticks_usec()-began
func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)
func picture(board:Board,backend:String)->Dictionary:
	board.backend=backend;board.queue_redraw()
	for i in 3:await process_frame;await RenderingServer.frame_post_draw
	return {"image":root.get_texture().get_image(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"submit_us":board.submit_us}
func compare(a:Image,b:Image)->Dictionary:
	var before=a.get_data();var after=b.get_data();var maximum=0;var changed=0;var total=0
	for i in before.size():
		var delta=absi(int(before[i])-int(after[i]));maximum=maxi(maximum,delta);total+=delta
		if delta>0:changed+=1
	return {"byte_identical":before==after,"max_channel_error_255":maximum,"changed_channels":changed,"mean_channel_error_255":float(total)/before.size()}
func stats(values:Array)->Dictionary:
	var ordered=values.duplicate();ordered.sort();var total=0.0
	for value in values:total+=value
	return {"mean_us":total/maxi(1,values.size()),"p50_us":ordered[ordered.size()/2],"p95_us":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"frames":values.size()}
func warmed_submission(board:Board,backend:String)->Dictionary:
	board.backend=backend;var samples:Array=[];var calls:Array=[]
	for frame in 42:
		board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		if frame>=10:
			samples.append(board.submit_us);calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return {"backend":backend,"submit":stats(samples),"draw_calls_min":calls.min(),"draw_calls_max":calls.max()}
func execute():
	if DisplayServer.get_name()=="headless":push_error("Ordered pod requires native renderer");quit(1);return
	root.size=Vector2i(1440,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# The ink child is behind its parent, matching main.gd. Put the background in
	# an earlier sibling so it cannot cover the actual egg texture being checked.
	var backdrop=ColorRect.new();backdrop.color=Color("38353b");backdrop.size=Vector2(1440,900);root.add_child(backdrop)
	var board=Board.new();root.add_child(board);var rows:Array=[]
	for scenario in 8:
		board.entries=[]
		var zoom=[.35,.65,1.0,1.75,2.2,.9,1.0,1.0][scenario]
		for i in (6 if scenario<6 else 1):
			var at=Vector2(190+i%3*440,220+i/3*390)+Vector2(.375,.8125)*scenario
			if scenario==6:at=Vector2(-10.125,350.625)
			if scenario==7:at=Vector2(1445.375,910.125)
			board.entries.append({"at":at,"size":[28.0,44.0,46.0,65.0,92.0,70.125][i%6]*zoom,"clock":float(scenario)*.713+i*.37,"accent":[Color("54bdce"),Color("b681d1"),Color("e0b364"),Color("f46b95"),Color("6ac8c7"),Color("ff508d")][i%6],"reward":i%2==0})
		board.prepare()
		var native=await picture(board,"native")
		for backend in ["triangle_array","static_triangles","static_mesh"]:
			var candidate=await picture(board,backend);var delta=compare(native.image,candidate.image)
			rows.append({"scenario":scenario,"backend":backend,"zoom":zoom,"pods":board.entries.size(),"native_draw_calls":native.draw_calls,"candidate_draw_calls":candidate.draw_calls,"geometry_build_us":board.build_us,"native_submit_us":native.submit_us,"candidate_submit_us":candidate.submit_us,"pixels":delta})
			check(delta.max_channel_error_255<=1,"Scenario %d %s preserves all shadow/filament/arc/reward channels within 1/255"%[scenario,backend])
			check(candidate.draw_calls<=native.draw_calls and (scenario==7 or candidate.draw_calls<native.draw_calls),"Scenario %d %s reduces visible geometry draws and never adds a draw when fully clipped"%[scenario,backend])
			if scenario==2 or delta.max_channel_error_255>1:
				native.image.save_png("res://artifacts/ordered-pod-native-%d.png"%scenario)
				candidate.image.save_png("res://artifacts/ordered-pod-%s-%d.png"%[backend,scenario])
	board.entries=[]
	for i in 18:
		board.entries.append({"at":Vector2(200+i%6*190,220+i/6*250)+Vector2(.375,.8125),"size":65.0 if i%6<5 else 92.0,"clock":1.25+i*.37,"accent":Color("f46b95"),"reward":i%6==5})
	board.prepare();var warmed:Array=[]
	for backend in ["native","static_triangles","static_mesh","static_mesh","static_triangles","native"]:warmed.append(await warmed_submission(board,backend))
	var report={"passed":checks.all(func(row):return row.passed),"checks":checks,"comparisons":rows,"warmed_18_pods":warmed,"cached_sizes":board.static_geometry.size(),"scope":"Isolated prototype only: unchanged generated egg art routed through original behind-parent ink layer; original Godot 4.6.3 AA geometry and painter triangle order combined into one float-color triangle array per pod. Static backends cache local shadow/four filaments by exact size and retain native arc/reward commands. Reports actual draw calls; geometry cost is separate from retained submission."}
	FileAccess.open("res://artifacts/ordered-pod-geometry.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	board.queue_free();quit(0 if report.passed else 1)
