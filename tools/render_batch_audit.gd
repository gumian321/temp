extends Node
## Visibility ablations in a frozen diagnostic fixture, never ordinary gameplay.
var game
var folder=""
var saved:Array=[]
var report:Dictionary={}
var main_erased=false
var hidden_organs:Array=[]
var auto_shader:Shader
func setup(owner_game,path:String):
	game=owner_game;folder=path;process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("execute")
func hide_node(node):
	if node==null:return
	if node is CanvasItem or node is CanvasLayer:
		saved.append([node,node.visible]);node.visible=false
	else:
		for child in node.get_children():hide_node(child)
func restore():
	var repaint=game.draw_audit_skip!="" or game.passive_fx.draw_audit_skip!=""
	game.draw_audit_skip="";game.passive_fx.draw_audit_skip=""
	if repaint:game.queue_redraw()
	for item in saved:item[0].visible=item[1]
	saved.clear()
	for rid in hidden_organs:RenderingServer.canvas_item_set_visible(rid,true)
	hidden_organs.clear()
	if main_erased:game.queue_redraw();main_erased=false
func sample(label:String,nodes:Array=[],hide_main:bool=false)->Dictionary:
	restore()
	for i in 3:await get_tree().process_frame
	for node in nodes:hide_node(node)
	if hide_main:RenderingServer.canvas_item_clear(game.get_canvas_item());main_erased=true
	if label.begins_with("without_main_section_"):
		game.draw_audit_skip=label.trim_prefix("without_main_section_");game.queue_redraw()
	if label=="without_upgrade_marks":game.passive_fx.draw_audit_skip="upgrade_marks";game.queue_redraw()
	if label.begins_with("without_passive_section_"):
		game.passive_fx.draw_audit_skip=label.trim_prefix("without_passive_section_");game.queue_redraw()
	if label.begins_with("without_attack_family_"):
		var painter=game.attack_shader_layer.batches[label.trim_prefix("without_attack_family_")]
		hidden_organs.append(painter.batch.rid);RenderingServer.canvas_item_set_visible(painter.batch.rid,false)
	if label=="without_organs":
		for item in game.soft_organs.gpu.items.values():hidden_organs.append(item.rid);RenderingServer.canvas_item_set_visible(item.rid,false)
	for i in 5:await get_tree().process_frame
	var draws:Array=[];var cpu:Array=[];var gpu:Array=[]
	for i in 16:
		await get_tree().process_frame
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(game.get_viewport().get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(game.get_viewport().get_viewport_rid()))
	return {"label":label,"draw_calls_mean":mean(draws),"draw_calls_min":draws.min(),"draw_calls_max":draws.max(),"render_cpu_mean_ms":mean(cpu),"render_gpu_mean_ms":mean(gpu)}
func mean(values:Array)->float:
	var total=0.0
	for value in values:total+=value
	return total/maxi(1,values.size())
func execute():
	get_tree().paused=true
	var actors=[]
	for drone in game.combat.drones+game.combat.enemy_drones:
		var source=game.db.sprite(drone.data.get("droneSprite",""))
		if source==null:continue
		var extent=preload("res://scripts/blue_ink.gd").fitted_size(source,Vector2(18,18)*game.zoom)
		var entry={"position":[drone.position.x,drone.position.y],"friendly":bool(drone.get("friendly",true)),"class":str(drone.data.get("class","")),"source_id":str(drone.data.get("droneSprite","")),"source_path":source.resource_path,"angle":float(drone.get("angle",0))+PI/2 if drone.data.get("class","")=="ProjectileDrone" else 0.0,"extent":[extent.x,extent.y],"native_screen":[game.world(drone.position).x,game.world(drone.position).y]}
		if source is AtlasTexture:
			entry.atlas=source.atlas.resource_path;entry.region=[source.region.position.x,source.region.position.y,source.region.size.x,source.region.size.y];entry.margin=[source.margin.position.x,source.margin.position.y,source.margin.size.x,source.margin.size.y];entry.filter_clip=source.filter_clip
		actors.append(entry)
	FileAccess.open(folder.path_join("actor-render-poses.json"),FileAccess.WRITE).store_string(JSON.stringify({"camera":[game.camera.x,game.camera.y],"center":[game.center.x,game.center.y],"kick":[game.camera_kick.x,game.camera_kick.y],"zoom":game.zoom,"actors":actors},"\t"))
	RenderingServer.viewport_set_measure_render_time(game.get_viewport().get_viewport_rid(),true)
	if OS.get_environment("RBPEW_AUDIT_TERRAIN_BATCH")=="1" or OS.get_environment("RBPEW_AUDIT_HOSTILE_BATCH")=="1" or OS.get_environment("RBPEW_AUDIT_POD_BATCH")=="1" or OS.get_environment("RBPEW_AUDIT_COMBINED_BATCH")=="1" or OS.get_environment("RBPEW_AUDIT_NECK_BATCH")=="1" or OS.get_environment("RBPEW_AUDIT_MORE_BATCH")=="1" or OS.get_environment("RBPEW_AUDIT_ACTOR_TRANSFORM")=="1":
		await compare_terrain_batch();return
	var before={"elapsed":game.run.elapsed,"hp":game.player.parts[0].hp,"rng":game.combat.rng.state,"actors":game.combat.enemies.size(),"parts":game.player.parts.size()}
	var rows:Array=[]
	rows.append(await sample("baseline"))
	game.get_viewport().get_texture().get_image().save_png(folder.path_join("render-audit-baseline.png"))
	var cases={"enemy_rigs":[game.insect_layer],"cave_terrain":[game.cave_terrain],"chasms":[game.charcoal_terrain],"illustrations":[game.ink_world],"attacks":[game.attack_shader_layer],"living_passives":[game.passive_fx.living],"enemy_health":[game.enemy_health_layer],"segment_damage":[game.segment_damage_layer],"background":[game.background_renderer],"fragments":[game.fragment_art],"encounter_feedback":[game.encounter_feedback],"mutations":[game.mutation_ground_layer],"particles":[game.particle_layer],"hud_radar_and_ui":[game.ui,game.tactical_radar,game.performance_overlay,game.popup_text,game.tutorials,game.cursor_system]}
	for key in cases:rows.append(await sample("without_"+key,cases[key]))
	rows.append(await sample("without_hud",[game.ui]))
	rows.append(await sample("without_radar",[game.tactical_radar]))
	rows.append(await sample("without_overlay",[game.performance_overlay]))
	rows.append(await sample("without_main_draw",[],true))
	for key in ["necks","passives","arrows"]:rows.append(await sample("without_main_section_"+key))
	rows.append(await sample("without_upgrade_marks"))
	for key in ["healed_stitches","fuel_pips","drone_pips","enemy_shields"]:rows.append(await sample("without_passive_section_"+key))
	rows.append(await sample("without_living_nodes",game.passive_fx.living.nodes))
	var attack_inventory=[]
	for key in game.attack_shader_layer.batches:
		var painter=game.attack_shader_layer.batches[key]
		if painter.batch.command_count>0:
			attack_inventory.append({"key":key,"commands":painter.batch.command_count})
			rows.append(await sample("without_attack_family_"+key))
	# Organ CanvasItems are RenderingServer-owned children, not Node children.
	rows.append(await sample("without_organs"))
	rows.append(await sample("baseline_restored"))
	var inventory:Array=[]
	for child in game.get_children():
		if child is CanvasItem or child is CanvasLayer:inventory.append({"name":child.name,"class":child.get_class(),"script":child.get_script().resource_path if child.get_script()!=null else "","visible":child.visible})
	var after={"elapsed":game.run.elapsed,"hp":game.player.parts[0].hp,"rng":game.combat.rng.state,"actors":game.combat.enemies.size(),"parts":game.player.parts.size()}
	report={"passed":before==after,"scope":"Actual renderer draw-call visibility ablation on a frozen fixture. Removing items can join adjacent batches; differences are not independently additive. This is not gameplay FPS.","state":before,"state_unchanged":before==after,"rows":rows,"inventory":inventory,"attack_inventory":attack_inventory,"living_counts":game.passive_fx.living.counts}
	FileAccess.open(folder.path_join("render-audit.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	# Preserve the replay driver's completion contract for the Python launcher.
	FileAccess.open(folder.path_join("replay-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":report.passed,"fixture":true,"frame":{},"counts":{"actors":before.actors,"parts":before.parts},"render_audit":true},"\t"))
	print("RENDER_BATCH_AUDIT=",JSON.stringify(report))
	game.cursor_system.shutdown();game.audio_system.shutdown();get_tree().quit(0 if report.passed else 1)

func image_delta(before:Image,after:Image)->Dictionary:
	var a=before.get_data();var b=after.get_data();var changed=0;var maximum=0
	for i in a.size():
		var delta=absi(int(a[i])-int(b[i]));maximum=maxi(maximum,delta)
		if delta:changed+=1
	return {"byte_identical":a==b,"maximum_channel_error":maximum,"changed_channels":changed}

func compare_terrain_batch():
	game.performance_overlay.visible=false
	var kind="more" if OS.get_environment("RBPEW_AUDIT_MORE_BATCH")=="1" else ("neck" if OS.get_environment("RBPEW_AUDIT_NECK_BATCH")=="1" else ("combined" if OS.get_environment("RBPEW_AUDIT_COMBINED_BATCH")=="1" else ("hostile" if OS.get_environment("RBPEW_AUDIT_HOSTILE_BATCH")=="1" else ("pod" if OS.get_environment("RBPEW_AUDIT_POD_BATCH")=="1" else "terrain"))))
	if OS.get_environment("RBPEW_AUDIT_ACTOR_TRANSFORM")=="1":kind="auto"
	var initial_camera:Vector2=game.camera
	var before=[game.run.elapsed,game.player.parts[0].hp,game.combat.rng.state]
	var rows:Array=[]
	for zoom in [1.0,.65,1.75]:
		game.zoom=zoom;game.camera=initial_camera+Vector2(13.375,-9.125)
		for i in 14:game.queue_redraw();await get_tree().process_frame
		for id in game.cave_terrain.visible_chunks:game.cave_terrain.prepare_chunk(id)
		game.cave_terrain.caps.queue_redraw();game.cave_terrain.minerals.queue_redraw();game.cave_terrain.details.queue_redraw()
		for i in 3:await get_tree().process_frame
		set_batch_mode(false,kind)
		var legacy=await sample("legacy_"+kind)
		var original=game.get_viewport().get_texture().get_image()
		set_batch_mode(true,kind)
		var current=await sample("batched_"+kind)
		var candidate=game.get_viewport().get_texture().get_image()
		var delta=image_delta(original,candidate)
		rows.append({"zoom":zoom,"legacy":legacy,"batched":current,"pixels":delta,"chunks":game.cave_terrain.visible_chunks.size()})
		if zoom==1.0 or delta.maximum_channel_error>1:
			original.save_png(folder.path_join(kind+"-legacy-"+str(zoom)+".png"));candidate.save_png(folder.path_join(kind+"-batched-"+str(zoom)+".png"))
	var passed=rows.all(func(row):return row.pixels.maximum_channel_error<=1 and row.batched.draw_calls_mean<=row.legacy.draw_calls_mean) and (kind=="auto" or rows.any(func(row):return row.batched.draw_calls_mean<row.legacy.draw_calls_mean)) and before==[game.run.elapsed,game.player.parts[0].hp,game.combat.rng.state]
	var result={"passed":passed,"scope":"Same frozen actual battle and three views. Only "+kind+" submission grouping changes. Overlay hidden for pixel comparison; this is not gameplay FPS.","comparisons":rows}
	FileAccess.open(folder.path_join(kind+"-batch-pixels.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	FileAccess.open(folder.path_join("replay-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"fixture":true,"frame":{},"counts":{"actors":game.combat.enemies.size(),"parts":game.player.parts.size()},"render_audit":true},"\t"))
	print("TERRAIN_BATCH_PIXELS=",JSON.stringify(result));game.cursor_system.shutdown();game.audio_system.shutdown();get_tree().quit(0 if passed else 1)

func set_batch_mode(enabled:bool,kind:String):
	if kind=="auto":
		game.attack_shader_layer.flight_batch.use_actor_batch=false
		var reference=preload("res://shaders/attack_material.gdshader")
		if auto_shader==null:
			var code=reference.code.replace(", skip_vertex_transform","")
			var start=code.find("// ACTOR_SCREEN_TRANSFORM_BEGIN")
			var stop=code.find("// ACTOR_SCREEN_TRANSFORM_END")+"// ACTOR_SCREEN_TRANSFORM_END".length()
			code=code.substr(0,start)+code.substr(stop)
			auto_shader=Shader.new();auto_shader.code=code
		for material in game.attack_shader_layer.materials.values():
			var parameters={}
			for entry in material.shader.get_shader_uniform_list():parameters[entry.name]=material.get_shader_parameter(entry.name)
			material.shader=reference if enabled else auto_shader
			for key in parameters:material.set_shader_parameter(key,parameters[key])
		game.queue_redraw()
	elif kind=="more":
		game.neck_geometry_batch.enabled=enabled;preload("res://scripts/boss_direction.gd").use_geometry_batch=enabled;game.attack_shader_layer.repair_tether_batch.enabled=enabled;game.queue_redraw()
		game.attack_shader_layer.flight_batch.use_actor_batch=enabled
		game.tactical_radar.icon_batch.enabled=enabled;game.tactical_radar.queue_redraw()
	elif kind=="neck":game.neck_geometry_batch.enabled=enabled;game.queue_redraw()
	elif kind=="combined":
		game.attack_shader_layer.use_hostile_geometry_batch=enabled
		preload("res://scripts/organic_world_objects.gd").use_geometry_batch=enabled
		game.cave_terrain.use_surface_batch=enabled
		game.tactical_radar.use_icon_atlas=enabled
		game.use_empty_neck_skip=enabled
		game.queue_redraw();game.tactical_radar.queue_redraw()
		game.cave_terrain.caps.queue_redraw();game.cave_terrain.minerals.queue_redraw()
	elif kind=="hostile":game.attack_shader_layer.use_hostile_geometry_batch=enabled;game.queue_redraw()
	elif kind=="pod":preload("res://scripts/organic_world_objects.gd").use_geometry_batch=enabled;game.queue_redraw()
	else:
		game.cave_terrain.use_surface_batch=enabled
		game.cave_terrain.caps.queue_redraw();game.cave_terrain.minerals.queue_redraw()
