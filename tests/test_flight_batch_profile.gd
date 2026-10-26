extends "res://tests/test_flight_batch.gd"
func stats(values:Array)->Dictionary:
	values.sort();var total=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"p95":values[int(values.size()*.95)],"p99":values[mini(values.size()-1,int(values.size()*.99))]}
func execute():
	if DisplayServer.get_name()=="headless":push_error("Flight profile requires native renderer");quit(1);return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;root.size=Vector2i(1440,900)
	var board=Board.new();root.add_child(board);board.overlay=false
	var results=[]
	for count in [4,12,32,64,240]:
		for optimized in [false,true,true,false]:
			board.optimized=optimized;board.shots.clear();board.clock=.4
			for i in count:
				var at=Vector2(-500+i%20*52,-250+i/20*40)
				var shot={"position":at,"previous":at-Vector2(30,0),"origin":at,"velocity":Vector2.from_angle(i*.37)*600,"radius":4.0,"friendly":i%2==0,"fx_family":FAMILIES[i%9],"data":{},"age":.2}
				shot.projectile_trail=Trails.make_state(shot,0);board.shots.append(shot)
			var timings=[];var calls=[]
			for frame in 80:
				board.clock+=1.0/60
				for shot in board.shots:
					shot.position=shot.origin+Vector2.from_angle(board.clock*5+shot.origin.x)*20
					Trails.record(shot.projectile_trail,shot.position,board.clock)
				var began=Time.get_ticks_usec();board.queue_redraw()
				await process_frame;await RenderingServer.frame_post_draw
				if frame>=20:timings.append((Time.get_ticks_usec()-began)/1000.0);calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var result={"count":count,"optimized":optimized,"frame_ms":stats(timings),"draw_calls":stats(calls)}
			results.append(result);print("FLIGHT_PROFILE ",JSON.stringify(result))
	var report={"scope":"Moving projectile presentation only; identical scripted paths, no game simulation. Native-pacing OpenGL, alternating old/new/new/old.","results":results}
	FileAccess.open("res://artifacts/flight-batch-profile-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	board.queue_free();await process_frame;quit(0)
