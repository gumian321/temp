extends SceneTree
const Prototype=preload("res://tests/prototypes/ordered_aa_stroke_mesh.gd")
const PairBatch=preload("res://tests/prototypes/ordered_aa_pair_batch.gd")
const Flagella=preload("res://scripts/flagella.gd")
const Ink=preload("res://scripts/blue_ink.gd")
var checks:Array=[]
var comparisons:Array=[]

class Board extends Node2D:
	var strokes:Array=[]
	var origin=Vector2(480,360)
	var angle=0.0
	var scale_factor=Vector2.ONE
	var backend="native"
	var prototype=Prototype.new()
	var pair_batch=PairBatch.new()
	var analytic=MultiMeshInstance2D.new()
	var stroke_batch=PairBatch.new()
	var analytic_strokes=MultiMeshInstance2D.new()
	var points=PackedVector2Array()
	var geometry_us=0
	var pair_prepare_us=0
	func _ready():
		analytic.multimesh=pair_batch.instances;analytic.material=pair_batch.material;analytic.visible=false;add_child(analytic)
		analytic_strokes.multimesh=stroke_batch.instances;analytic_strokes.material=stroke_batch.material;analytic_strokes.visible=false;add_child(analytic_strokes)
	func prepare(styles_changed:bool=true):
		var began=Time.get_ticks_usec()
		prototype.begin(strokes.size(),styles_changed)
		for line in strokes:prototype.stroke(line[0],line[1],line[2],line[3])
		prototype.finish();geometry_us=Time.get_ticks_usec()-began
		points=prototype.triangle_points()
		began=Time.get_ticks_usec()
		assert(pair_batch.prepare(strokes),"All fixtures must support the analytic pair prototype")
		assert(stroke_batch.prepare(strokes,true),"All fixtures must support separate original stroke layers")
		pair_prepare_us=Time.get_ticks_usec()-began
	func _draw():
		analytic.visible=backend=="analytic_pair"
		analytic.transform=Transform2D(angle,scale_factor,0.0,origin)
		analytic_strokes.visible=backend=="analytic_strokes"
		analytic_strokes.transform=analytic.transform
		draw_rect(Rect2(0,0,960,720),Color("34333b"))
		for i in 15:
			if i%2==0:draw_rect(Rect2(i*64,0,64,720),Color("d8d1ba"))
		draw_set_transform(origin,angle,scale_factor)
		if backend=="native":
			for line in strokes:draw_line(line[0],line[1],line[2],line[3],true)
		elif backend=="array_mesh":draw_mesh(prototype.mesh,null)
		elif backend in ["analytic_pair","analytic_strokes"]:pass # The independent children apply their shader only to the ordered strokes.
		else:RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),prototype.indices,points,prototype.colors)
		draw_set_transform(Vector2.ZERO)

func check(passed:bool,label:String):
	checks.append({"passed":passed,"label":label})
	if not passed:push_error(label)

func flagella_strokes(poses:Array,evolved:bool=false)->Array:
	var result:Array=[]
	for pts in poses:
		var smooth=PackedVector2Array()
		for i in range(pts.size()-1):
			for sample in 3:smooth.append(Vector2(pts[i]).cubic_interpolate(pts[i+1],pts[maxi(0,i-1)],pts[mini(pts.size()-1,i+2)],sample/3.0))
		smooth.append(pts[-1])
		for i in range(smooth.size()-1):
			var width=lerpf(5.8 if evolved else 4.8,.45,float(i)/(smooth.size()-1))
			result.append([smooth[i],smooth[i+1],Ink.INK,width])
			result.append([smooth[i],smooth[i+1],Color("739ca0") if evolved else Ink.PAPER,maxf(.25,width*.38)])
	return result

func fixture(index:int)->Array:
	if index<3:return flagella_strokes([Flagella.natural_pose(0,true,index*.73),Flagella.natural_pose(1,true,index*.73)],index==2)
	if index==3:
		var crossing=PackedVector2Array()
		for i in 16:crossing.append(Vector2(sin(i*.82)*130,cos(i*.47)*80))
		return flagella_strokes([crossing])
	var result:Array=[]
	for i in 7:
		var start=Vector2(-180+i*55,-100+i*25)
		var finish=start+Vector2(50,23).rotated(i*.52)
		if i==5:finish=start+Vector2(.001,0)
		if i==6:finish=start
		var width=[4.8,1.824,.99,.45,.25,1.0,2.0][i]
		result.append([start,finish,Color(.15,.67,.49,.37 if index==5 else 1),width])
		result.append([start,finish,Color(.83,.31,.58,.69 if index==5 else 1),maxf(.25,width*.38)])
	return result

func picture(board:Board,backend:String)->Dictionary:
	board.backend=backend;board.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	await process_frame;await RenderingServer.frame_post_draw
	return {"image":root.get_texture().get_image(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}

func compare(old:Image,now:Image)->Dictionary:
	var a=old.get_data();var b=now.get_data();var maximum=0;var changed=0;var sum=0
	for i in a.size():
		var delta=absi(int(a[i])-int(b[i]));maximum=maxi(maximum,delta);sum+=delta
		if delta>0:changed+=1
	return {"maximum_channel_error":maximum,"mean_channel_error":float(sum)/a.size(),"changed_channels":changed}

func _initialize():call_deferred("execute")
func execute():
	if DisplayServer.get_name()=="headless":push_error("Native renderer required for ordered AA stroke comparison");quit(1);return
	root.size=Vector2i(960,720)
	var board=Board.new();root.add_child(board)
	for pose in 7:
		board.strokes=fixture(mini(pose,5));board.angle=[0.0,.37,-.68,.21,1.14,-.31,.12][pose]
		board.scale_factor=Vector2(-.75,.75) if pose==2 else Vector2.ONE*[1.0,.65,1.0,1.7,1.0,.8,1.2][pose]
		board.origin=Vector2(-10,350) if pose==6 else Vector2(480,360)
		board.prepare()
		check(board.prototype.vertices.size()==board.strokes.size()*36 and board.prototype.indices.size()==board.strokes.size()*54,"pose %d retains all nine quads per AA stroke in exact order"%pose)
		var original=await picture(board,"native")
		for backend in ["array_mesh","triangle_array","analytic_pair","analytic_strokes"]:
			var candidate=await picture(board,backend);var delta=compare(original.image,candidate.image)
			comparisons.append({"pose":pose,"backend":backend,"delta":delta,"native_draw_calls":original.draw_calls,"candidate_draw_calls":candidate.draw_calls,"stroke_count":board.strokes.size(),"prototype_geometry_us":board.geometry_us,"pair_payload_us":board.pair_prepare_us})
			check(delta.maximum_channel_error<=1,"pose %d %s keeps every channel within 1/255"%[pose,backend])
			if pose==3 or delta.maximum_channel_error>1:
				original.image.save_png("res://artifacts/ordered-aa-native-%d.png"%pose)
				candidate.image.save_png("res://artifacts/ordered-aa-%s-%d.png"%[backend,pose])
	# The stable-style path updates positions only; it must retain the same pixels.
	board.strokes=fixture(1);board.origin=Vector2(480,360);board.prepare()
	board.strokes=fixture(0);board.prepare(false)
	var old=await picture(board,"native");var cached=await picture(board,"array_mesh")
	var updated=compare(old.image,cached.image)
	check(board.prototype.vertex_updates>0 and updated.maximum_channel_error<=1,"warm vertex-buffer update retains AA and ordered layers")
	var passed=checks.all(func(item):return item.passed)
	var report={"suite":"ordered_aa_stroke_mesh","passed":passed,"checks":checks,"pixel_comparisons":comparisons,"warm_update":updated,"scope":"Experimental geometry only. Same 16 control points, three cubic subdivisions per link, per-segment outer/inner order, native square feather sides/corners and all original alpha layers; no production integration or FPS claim."}
	FileAccess.open("res://artifacts/ordered-aa-stroke-mesh.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
	board.queue_free();quit(0 if passed else 1)
