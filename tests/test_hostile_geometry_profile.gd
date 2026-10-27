extends "res://tests/test_hostile_geometry_batch.gd"
func execute():
	if DisplayServer.get_name()=="headless":push_error("Native renderer required");quit(2);return
	root.size=Vector2i(1440,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var board=Board.new();root.add_child(board)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var rows:Array=[]
	for count in [72,240]:
		board.shots=[];board.zoom=1.0
		for i in count:
			var at=Vector2(80+(i%20)*66,90+(i/20)*60)+Vector2(.375,.8125)
			var axis=Vector2.from_angle(i*.371)
			board.shots.append({"position":at,"previous":at-axis*20,"origin":at-axis*70,"velocity":axis*600,"radius":4.0,"friendly":false,"fx_family":FAMILIES[i%9],"data":{},"projectile_trail":{"visual_id":i+1}})
		for batch in [false,true,true,false]:
			board.batched=batch
			var frames:Array=[];var cpu:Array=[];var gpu:Array=[];var submits:Array=[]
			for i in 420:
				var began=Time.get_ticks_usec();board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
				if i>=120:
					frames.append(Time.get_ticks_usec()-began);submits.append(board.submit_us)
					cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			var row={"shots":count,"batched":batch,"backend":"ordered_instancing" if batch else "original_retained_cues","frames":frames.size(),"frame_mean_ms":average(frames)/1000,"frame_p95_ms":percentile(frames,.95)/1000,"render_cpu_mean_ms":average(cpu),"render_gpu_mean_ms":average(gpu),"warm_submit_mean_ms":average(submits)/1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"instancing":board.layer.hostile_body_batch.stats(),"shape_meshes":board.layer.hostile_shape_meshes.size()}
			rows.append(row);print("HOSTILE_BATCH_PROFILE_CASE=",JSON.stringify(row))
	var report={"passed":true,"scope":"Ordered ABBA native renderer microbenchmark, frozen hostile cues only. Excludes collision/AI/terrain/gameplay; not game FPS or thirty-minute acceptance.","cases":rows}
	FileAccess.open("res://artifacts/hostile-geometry-profile-instanced.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));board.queue_free();print(JSON.stringify(report));quit()
func average(values:Array)->float:
	var total=0.0
	for value in values:total+=value
	return total/maxi(1,values.size())
func percentile(values:Array,fraction:float)->float:
	var copy=values.duplicate();copy.sort();return copy[mini(copy.size()-1,int(copy.size()*fraction))]
