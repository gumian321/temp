extends SceneTree
## Research gate for retaining actor trail/body order in the existing flight batch.
const Layers=preload("res://scripts/attack_shader_layer.gd")
const Trails=preload("res://scripts/projectile_trails.gd")
const Armaments=preload("res://scripts/insect_armaments.gd")
const Ink=preload("res://scripts/blue_ink.gd")
var checks:Array=[]
class Board extends Node2D:
	var layer=Layers.new()
	var actors:Array=[]
	var optimized=false
	var zoom=1.0
	var clock=.271
	var view_offset=Vector2.ZERO
	var space_offset=Vector2.ZERO
	func _ready():
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if OS.get_environment("RBPEW_PROTO_ACTOR_CLAMP")=="1":layer.flight_batch=preload("res://tests/prototypes/actor_flight_exact.gd").new()
		layer.attach(self)
		if OS.get_environment("RBPEW_PROTO_ACTOR_PRODUCTION")=="1":layer.flight_batch.use_actor_batch=true
	func world(at:Vector2)->Vector2:return (at-space_offset)*zoom+Vector2(719.375,449.125)+view_offset
	func _draw():
		draw_rect(get_viewport_rect(),Color("383836"))
		if OS.get_environment("RBPEW_PROTO_ACTOR_CLAMP")=="1":
			var chosen=layer.flight_batch.exact_shader if optimized else preload("res://shaders/attack_material.gdshader")
			for material in layer.materials.values():
				if material.shader!=chosen:material.shader=chosen
		layer.begin_frame(clock)
		for actor in actors:
			var painter=Layers.route(self,actor.family,not actor.friendly)
			var extent=Ink.fitted_size(actor.source,Vector2(18,18)*zoom)
			if optimized:
				var origin=world(Vector2.ZERO);var scale_factor=origin.distance_to(world(Vector2.RIGHT))
				var mesh=Trails.prepare_gpu_mesh(actor.state,zoom,scale_factor)
				var body={"source":actor.source,"size":extent,"heading":actor.angle,"screen_extent":extent,"screen_transform":Transform2D(actor.angle,world(actor.position))}
				if OS.get_environment("RBPEW_PROTO_ACTOR_PRODUCTION")=="1":
					if layer.flight_batch.enqueue_actor(painter,actor.state,mesh,origin,scale_factor,body,zoom):continue
				elif layer.flight_batch.enqueue(painter,actor.state,mesh,origin,scale_factor,body,"actor"):continue
			Trails.paint(painter,actor.state,zoom,clock)
			painter.draw_set_transform(world(actor.position),actor.angle)
			painter.draw_texture_rect(actor.source,Rect2(-extent*.5,extent),false,Color.WHITE)
			painter.draw_set_transform(Vector2.ZERO)
		layer.end_frame()
func _initialize():call_deferred("execute")
func picture(board:Board)->Dictionary:
	board.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return {"image":root.get_texture().get_image(),"dc":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func delta(a:Image,b:Image)->Dictionary:
	var aa=a.get_data();var bb=b.get_data();var maximum=0;var changed=0;var total=0
	for i in aa.size():
		var difference=absi(int(aa[i])-int(bb[i]));maximum=maxi(maximum,difference);total+=difference
		if difference:changed+=1
	return {"max_channel_error":maximum,"changed_channels":changed,"mean_channel_error":float(total)/aa.size()}
func execute():
	if DisplayServer.get_name()=="headless":printerr("Requires real rendering");quit(1);return
	root.size=Vector2i(1440,900)
	var board=Board.new();root.add_child(board)
	if OS.get_environment("RBPEW_PROTO_ACTOR_LARGE_SPACE")=="1":board.space_offset=Vector2(15567.375,-9394.125)
	var types=["drone_unit","repair_drone","scrap_drone"]
	for i in 48:
		var source=Armaments.texture(types[i%3])
		assert(source is AtlasTexture and source.margin==Rect2())
		var family=["drone","repair_drone","scrap_drone"][i%3]
		var position=Vector2(-180+(i%8)*45,-170+(i/8)*61)+Vector2(.375,-.125)+board.space_offset
		var shot={"position":position,"previous":position-Vector2(5,2),"friendly":i%2==0,"fx_family":family,"organic_family":family,"radius":2.2,"age":.271}
		var state=Trails.make_state(shot,0);state.max_distance=72.0
		for sample in 14:
			Trails.record(state,position-Vector2(58-sample*4,sin(sample*.57+i)*6),sample/60.0)
		Trails.record(state,position,.271)
		board.actors.append({"source":source,"family":family,"friendly":shot.friendly,"state":state,"position":position,"angle":.0 if family!="drone" else i*.71})
	var before=board.actors.duplicate(true);var rows:Array=[]
	var views=[[.4,Vector2.ZERO],[.65,Vector2.ZERO],[1.0,Vector2.ZERO],[1.75,Vector2.ZERO]]
	if OS.get_environment("RBPEW_PROTO_ACTOR_PRODUCTION")=="1" or OS.get_environment("RBPEW_PROTO_ACTOR_SCREEN")=="1":
		views.append_array([[1.0,Vector2(.1875,.375)],[1.0,Vector2(-.5,.625)],[1.0,Vector2(-600.25,-300.125)],[1.0,Vector2(630.375,330.75)]])
	for view in views:
		var zoom:float=view[0];board.zoom=zoom;board.view_offset=view[1];board.optimized=false
		var original=await picture(board)
		board.optimized=true
		var candidate=await picture(board)
		var pixels=delta(original.image,candidate.image)
		rows.append({"zoom":zoom,"space_offset":[board.space_offset.x,board.space_offset.y],"view_offset":[board.view_offset.x,board.view_offset.y],"native_dc":original.dc,"batch_dc":candidate.dc,"pixels":pixels})
		if zoom==1.0 or pixels.max_channel_error>1:
			original.image.save_png("res://artifacts/actor-flight-native-"+str(zoom)+".png")
			candidate.image.save_png("res://artifacts/actor-flight-batched-"+str(zoom)+".png")
	var result={"passed":rows.all(func(r):return r.pixels.max_channel_error<=1 and r.batch_dc<=r.native_dc) and rows.any(func(r):return r.batch_dc<r.native_dc),"comparisons":rows,"simulation_unchanged":before==board.actors,"scope":"Ordered native actor trail plus illustrated body, original family streams and native atlases. Production candidate preserves original CPU screen translation/rotation and AtlasTexture half-texel clipping; unsupported sources/transforms/capacity use native fallback. Strict maximum pixel error remains1."}
	var filename="actor-flight-production.json" if OS.get_environment("RBPEW_PROTO_ACTOR_PRODUCTION")=="1" else ("actor-flight-batch-screen.json" if OS.get_environment("RBPEW_PROTO_ACTOR_SCREEN")=="1" else ("actor-flight-batch-clamped.json" if OS.get_environment("RBPEW_PROTO_ACTOR_CLAMP")=="1" else "actor-flight-batch.json"))
	FileAccess.open("res://artifacts/"+filename,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	board.queue_free();await process_frame;quit(0 if result.passed and result.simulation_unchanged else 1)
