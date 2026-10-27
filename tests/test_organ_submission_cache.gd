extends SceneTree
const Organs=preload("res://scripts/soft_organ_art.gd")
const Art=preload("res://scripts/insect_armaments.gd")
var checks:Array=[]

class Board extends Node2D:
	var organs=Organs.new()
	var variants:Array=[]
	var order:Array=[]
	var textures:Array=[]
	var clock=0.0
	var pulse=.18
	var timings:Array=[]
	func _init(cached:bool):
		organs.use_gpu=true;organs.gpu.use_cached_submission=cached
		variants=Art.entries().keys()
		for i in 48:
			order.append(i);textures.append(Art.texture(variants[i%variants.size()]))
	func _draw():
		var began=Time.get_ticks_usec();organs.begin_frame()
		for i in order:
			var at=Vector2(90+(i%12)*99,170+(i/12)*120)
			# Adjacent bounds deliberately overlap: painter order is visible.
			organs.paint(self,"player:"+str(i),textures[i],at,Vector2(140,150),float(i%5)*.37,variants[i%variants.size()],clock,pulse,Color(.88,1,.94,.8 if i%3==0 else 1.0),float(i),.7,Vector2(1,-.4),[-.24,0.0,.2,.36][i%4])
		organs.end_frame();timings.append(float(Time.get_ticks_usec()-began)/1000)

func check(passed:bool,label:String):
	checks.append({"passed":passed,"label":label})
	if not passed:push_error(label)
func _initialize():call_deferred("execute")
func picture(board:Board,other:Board)->Image:
	other.hide();board.show();board.queue_redraw()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func stats(values:Array)->Dictionary:
	var ordered=values.duplicate();ordered.sort();var sum=0.0
	for value in values:sum+=value
	return {"mean_ms":sum/maxi(1,values.size()),"p95_ms":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"max_ms":ordered[-1]}
func execute():
	if DisplayServer.get_name()=="headless":push_error("Organ submission cache test requires --render");quit(1);return
	root.size=Vector2i(1440,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var legacy=Board.new(false);var cached=Board.new(true);root.add_child(legacy);root.add_child(cached)
	legacy.hide();cached.hide()
	var comparisons:Array=[]
	for scenario in 5:
		for board in [legacy,cached]:
			board.clock=[0.0,.73,1.67,2.1,NAN][scenario];board.pulse=[.18,.07,0.0,.1,.18][scenario]
			if scenario==2:board.order.reverse()
			if scenario==3:
				var changed=board.textures[0].duplicate() as AtlasTexture
				board.textures[0]=changed
				changed.region=Rect2(changed.region.position+Vector2(1,1),changed.region.size-Vector2(2,2))
		var expected=await picture(legacy,cached)
		var actual=await picture(cached,legacy)
		var a=expected.get_data();var b=actual.get_data();var maximum=0;var different=0
		for i in a.size():
			var delta=absi(int(a[i])-int(b[i]));maximum=maxi(maximum,delta)
			if delta>0:different+=1
		comparisons.append({"scenario":scenario,"max_channel_error_255":maximum,"different_channels":different})
		check(different==0,"Cached GPU submission is pixel-identical with original layouts/order/traction: scenario "+str(scenario))
		if scenario==3:
			expected.save_png("res://artifacts/deep-organ-submission-original-20261026.png")
			actual.save_png("res://artifacts/deep-organ-submission-cached-20261026.png")
	var blocks:Array=[]
	for board in [legacy,cached,cached,legacy]:
		legacy.visible=board==legacy;cached.visible=board==cached;board.timings.clear()
		for frame in 102:
			board.clock=float(frame)*.017;board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		var result=stats(board.timings.slice(12));result.cached=board==cached;blocks.append(result)
	for board in [legacy,cached]:board.order=[0]
	await picture(legacy,cached);await picture(cached,legacy)
	check(cached.organs.gpu.items.size()==1 and cached.organs.gpu.geometry.size()==1,"Pruning after a smaller loadout releases every unused retained organ and layout")
	for board in [legacy,cached]:board.order=[]
	await picture(legacy,cached);await picture(cached,legacy)
	check(cached.organs.gpu.items.is_empty() and cached.organs.gpu.geometry.is_empty(),"Empty frames clean retained items despite skipping duplicate end_frame walks")
	for board in [legacy,cached]:board.order=[1,0]
	var a=await picture(legacy,cached);var b=await picture(cached,legacy)
	check(a.get_data()==b.get_data(),"Reentry after a fully empty frame restores exact geometry, order and shader state")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"pixel_comparisons":comparisons,"submission_abba":blocks,"scope":"Same 48 GPU-deformed original organs, unchanged mesh/shader and visible overlap; only submission bookkeeping differs. CPU submission times are not whole-game FPS."}
	FileAccess.open("res://artifacts/deep-organ-submission-cache-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	legacy.queue_free();cached.queue_free();await process_frame;quit(0 if report.passed else 1)
