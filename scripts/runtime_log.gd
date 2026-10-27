extends Node
## Local long-run diagnostics, independent of F3 and gameplay RNG/save data.
const Writer=preload("res://scripts/runtime_log_writer.gd")
const BUILD_ID="cpu-depth-probe5-20261027"
const LOG_ROOT="user://performance-logs"
const SUMMARY_USEC=1000000
const SAMPLE_PERIOD=15000000
const SAMPLE_LENGTH=400000
const SLOW_LENGTH=1500000
const SLOW_COOLDOWN=30000000
const MAX_FRAME_SAMPLES=4096
var enabled=false
var sampling=false
var main_times:Dictionary={}
var writer
var session_path=""
var session_serial=0
var run_identity=0
var last_start=0
var last_engine_frame=-1
var last_cpu_us=0
var pending_active=false
var pending_sampling=false
var pending_elapsed=0.0
var tick_run_elapsed=0.0
var summary_started=0
var frame_times:Array=[]
var cpu_times:Array=[]
var summary_frames=0
var total_frames=0
var total_active_us=0
var total_draw_calls=0.0
var frame_sum=0.0
var cpu_sum=0.0
var draw_sum=0.0
var draw_min=INF
var draw_max=0.0
var over_60=0
var over_30=0
var slow_streak=0
var sample_until=0
var next_sample=0
var last_slow=-SLOW_COOLDOWN
var last_screen=""
var last_loadout=""
var sources:Dictionary={}
var last_combat
var last_error=""

func setup(game):
	name="RuntimePerformanceLog";set_process(false)
	var preference=OS.get_environment("RBPEW_RUNTIME_LOG")
	enabled=preference=="1" or (preference!="0" and OS.get_environment("RBPEW_TEST_SANDBOX").is_empty() and not game.get_tree().has_meta("performance_fixture"))
	if enabled:
		for key in ["main","combat","combat_spatial_index","cave_world","cave_contour_mesh","cave_sweep_accelerator","cave_overlap_cache","map_director","passive_feedback","living_passive_layer","soft_organ_gpu","soft_insect","conservative_pilot","pilot_escape_terrain","battle_snapshot","runtime_log","runtime_log_writer","attack_shader_layer","ordered_canvas_geometry","retained_hostile_geometry","hostile_body_batch","cave_terrain","pod_geometry_batch","organic_world_objects","tactical_radar","radar_icon_atlas","radar_icon_batch","neck_geometry_batch","pointer_geometry_batch","boss_direction","repair_tether_batch","flight_batch"]:sources[key]=fingerprint("res://scripts/"+key+".gd")

func fingerprint(path:String)->Dictionary:
	var resolved=path
	if not FileAccess.file_exists(resolved):
		var config=ConfigFile.new()
		if config.load(path+".remap")==OK:resolved=str(config.get_value("remap","path",""))
	return {"sha256":FileAccess.get_sha256(resolved) if not resolved.is_empty() and FileAccess.file_exists(resolved) else "","format":resolved.get_extension()}

func begin_tick(game,now:int=-1)->bool:
	if not enabled:return false
	var real_clock=now<0
	if real_clock:now=Time.get_ticks_usec()
	var engine_frame=Engine.get_process_frames()
	if real_clock and engine_frame==last_engine_frame:return false
	# Real callers are once per process frame; test clocks may advance explicitly.
	if writer!=null and (game.run==null or game.run.get_instance_id()!=run_identity):finish_session("new_run")
	if last_start>0 and writer!=null:
		commit_frame(game,now)
	if game.screen=="game" and game.run!=null and not game.deployment_active:
		var identity=game.run.get_instance_id()
		if identity!=run_identity:
			finish_session("new_run");start_session(game,now,real_clock);run_identity=identity
	elif writer!=null and game.screen not in ["game","pause","build","rewards","result"]:
		finish_session("left_run")
	if writer==null:
		last_start=0;return false
	if game.screen!=last_screen:
		if game.screen!="game":flush_summary(game,now)
		write({"type":"state","screen":game.screen,"run_elapsed":game.run.elapsed});last_screen=game.screen
	var active=game.screen=="game" and not game.deployment_active and not game.death_transition.active
	if active and now>=next_sample:sample_until=maxi(sample_until,now+SAMPLE_LENGTH);next_sample=now+SAMPLE_PERIOD
	sampling=active and now<sample_until
	main_times.clear()
	if last_combat!=null:last_combat.diagnostic_profile=false
	last_combat=game.combat
	last_combat.diagnostic_profile=sampling;last_combat.diagnostic_times.clear()
	last_start=now;last_engine_frame=engine_frame;pending_active=active;pending_sampling=sampling
	pending_elapsed=game.run.elapsed;tick_run_elapsed=game.run.elapsed
	return true

func end_tick(game,cpu_us:int):
	last_cpu_us=cpu_us
	pending_active=pending_active and game.screen=="game" and not game.deployment_active and not game.death_transition.active and game.run.elapsed>tick_run_elapsed
	if game.run!=null:pending_elapsed=game.run.elapsed

func start_session(game,now:int,real_clock:bool=true):
	session_serial+=1
	var stamp=Time.get_datetime_string_from_system(true).replace("-","").replace(":","")
	var name="run-"+stamp+"Z-%d-%02d"%[OS.get_process_id(),session_serial]
	writer=Writer.new()
	var viewport=game.get_viewport_rect().size
	var header={"type":"header","schema":1,"owner":Writer.OWNER,"build_id":BUILD_ID,"created_at_utc":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info(),"debug_build":OS.is_debug_build(),"editor":OS.has_feature("editor"),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":[viewport.x,viewport.y],"vsync_mode":DisplayServer.window_get_vsync_mode(),"refresh_rate":DisplayServer.screen_get_refresh_rate(),"character":game.player.character_id,"mission":game.run.mission.get("name",""),"difficulty":game.difficulty,"sources":sources,"summary_seconds":1,"periodic_profile_ms":400,"profile_period_seconds":15,"slow_profile_ms":1500,"slow_profile_cooldown_seconds":30,"frame_time_scope":"wall interval between main process calls; CPU excludes logging and drawing; phase timers are nested microseconds; only active combat enters frame summaries","local_only":true}
	header.synthetic_clock=not real_clock;header.fixture=game.get_tree().has_meta("performance_fixture");header.isolated_test_profile=not OS.get_environment("RBPEW_TEST_SANDBOX").is_empty()
	header.window_mode=DisplayServer.window_get_mode();header.window_size=[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y]
	var result=writer.start(ProjectSettings.globalize_path(LOG_ROOT),name,header)
	if result!=OK:last_error="Unable to start log writer";writer=null;return
	session_path=writer.session_path
	summary_started=now;next_sample=now;sample_until=0;last_slow=now-SLOW_COOLDOWN
	last_start=0;last_screen="";last_loadout="";total_frames=0;total_active_us=0;total_draw_calls=0;reset_summary()
	write({"type":"run_start","run_elapsed":game.run.elapsed,"counts":counts(game)})
	record_loadout(game)
	print("RUNTIME_PERFORMANCE_LOG=",session_path)

func commit_frame(game,now:int):
	if not pending_active:return
	var elapsed_us=now-last_start
	if elapsed_us<=0:return
	var ms=float(elapsed_us)/1000.0;var cpu=float(last_cpu_us)/1000.0
	var draws=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	total_active_us+=elapsed_us;total_draw_calls+=draws
	draw_sum+=draws;draw_min=minf(draw_min,draws);draw_max=maxf(draw_max,draws)
	summary_frames+=1;total_frames+=1;frame_sum+=ms;cpu_sum+=cpu
	if frame_times.size()<MAX_FRAME_SAMPLES:frame_times.append(ms);cpu_times.append(cpu)
	if ms>1000.0/60:over_60+=1
	if ms>1000.0/30:over_30+=1
	slow_streak=slow_streak+1 if ms>=1000.0/30 else 0
	if slow_streak>=3 and now-last_slow>=SLOW_COOLDOWN:
		last_slow=now;sample_until=maxi(sample_until,now+SLOW_LENGTH)
		write({"type":"slow_trigger","run_elapsed":pending_elapsed,"frame_ms":ms,"cpu_ms":cpu,"counts":counts(game)})
	if pending_sampling:
		write({"type":"detail","run_elapsed":pending_elapsed,"frame_ms":ms,"cpu_ms":cpu,"main_us":main_times.duplicate(),"combat_us":last_combat.diagnostic_times.duplicate() if last_combat!=null else {},"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"actors":game.combat.enemies.size(),"bullets":game.combat.bullets.size(),"effects":game.combat.effects.size(),"f3_capture":game.performance_overlay.capture_active})
	if now-summary_started>=SUMMARY_USEC:flush_summary(game,now)

func stats(values:Array)->Dictionary:
	if values.is_empty():return {}
	var sorted=values.duplicate();sorted.sort()
	return {"p50":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"p99":sorted[mini(sorted.size()-1,int(sorted.size()*.99))],"max":sorted[-1]}

func flush_summary(game,now:int):
	if summary_frames==0:summary_started=now;return
	var timing=stats(frame_times);timing.mean=frame_sum/summary_frames;timing.fps=1000.0/maxf(.001,timing.mean)
	timing.over_16_67_percent=100.0*over_60/summary_frames;timing.over_33_33_percent=100.0*over_30/summary_frames
	var cpu=stats(cpu_times);cpu.mean=cpu_sum/summary_frames
	write({"type":"summary","run_elapsed":pending_elapsed,"frames":summary_frames,"frame_ms":timing,"cpu_ms":cpu,"draw_calls":{"mean":draw_sum/summary_frames,"min":draw_min,"max":draw_max,"frames":summary_frames,"scope":"Engine completed-render counter sampled for each committed active frame"},"active_totals":active_totals(),"counts":counts(game),"writer":writer.status(),"percentile_samples":frame_times.size()})
	record_loadout(game);summary_started=now;reset_summary()

func reset_summary():
	frame_times.clear();cpu_times.clear();summary_frames=0;frame_sum=0;cpu_sum=0;over_60=0;over_30=0
	draw_sum=0;draw_min=INF;draw_max=0

func active_totals()->Dictionary:
	return {"frames":total_frames,"microseconds":total_active_us,"seconds":float(total_active_us)/1000000.0,"fps":float(total_frames)*1000000.0/total_active_us if total_active_us>0 else 0.0,"draw_calls_mean":total_draw_calls/total_frames if total_frames>0 else 0.0}

func record_loadout(game):
	var parts=[]
	for part in game.player.parts:parts.append({"core":part.id,"fusion":part.get("fusion_level",1)})
	var data={"parts":parts,"hq":game.player.hq_weapon,"upgrades":game.player.levels.duplicate(),"stats":game.player.stats.duplicate()}
	var signature=JSON.stringify(data)
	if signature==last_loadout:return
	last_loadout=signature;write({"type":"loadout","run_elapsed":game.run.elapsed,"equipment":data})

func counts(game)->Dictionary:
	var battle=game.combat;var world=game.charcoal_terrain.world;var terrain=game.cave_terrain;var map=game.run.map_director
	var hostile=0;var visible_actors=0;var checked=0;var actors_checked=0
	for shot in battle.bullets:
		if not shot.friendly:hostile+=1
		checked+=1
		if checked>=4096:break
	var view=game.get_viewport_rect().grow(250)
	for actor in battle.enemies:
		if view.has_point(game.world(actor.position)):visible_actors+=1
		actors_checked+=1
		if actors_checked>=4096:break
	var static_bytes=Performance.get_monitor(Performance.MEMORY_STATIC)
	var result={"heat":game.run.heat,"level":game.run.level,"kills":battle.kills,"actors":battle.enemies.size(),"visible_actors_sample":visible_actors,"actors_classified":actors_checked,"bullets":battle.bullets.size(),"hostile_bullets_sample":hostile,"bullets_classified":checked,"effects":battle.effects.size(),"trails":battle.projectile_trails.size(),"splatter":battle.death_splatters.size(),"drones":battle.drones.size(),"enemy_drones":battle.enemy_drones.size(),"loot":battle.loot.size(),"mines":battle.special.mines.size(),"black_holes":battle.special.black_holes.size(),"controls":battle.insect_controls.size(),"released_controls":battle.insect_control_system.released.size(),"mutation_shots":battle.mutation_weapons.shots.size(),"toxin_pools":battle.mutation_weapons.pools.size(),"larvae":battle.mutation_weapons.larvae.size(),"parts":game.player.parts.size(),"particle_nodes":game.particle_effects.get_child_count(),"particle_followers":game.particle_effects.followers.size(),"particle_engines":game.particle_effects.engines.size(),"particle_flames":game.particle_effects.flames.size(),"rigs":game.insect_layer.rigs.size(),"hidden_rigs":game.insect_layer.hidden_rigs.size(),"pooled_rigs":game.insect_layer.rig_pool.size(),"rig_builds":game.insect_layer.rig_builds,"rig_reuses":game.insect_layer.rig_reuses,"flight_entries":game.attack_shader_layer.flight_batch.entries.size(),"flight_groups":game.attack_shader_layer.flight_batch.groups.size(),"trail_meshes":preload("res://scripts/projectile_trails.gd").mesh_cache.size(),"terrain_chunks":world.chunks.size(),"terrain_geometry":world.geometry.size(),"collision_rows":world.collision_rows.size(),"collision_blocks":world.collision_blocks.size(),"collision_block_hits":world.collision_block_hits,"collision_block_misses":world.collision_block_misses,"collision_fragment_hits":world.collision_fragment_hits,"collision_fragment_misses":world.collision_fragment_misses,"sweep_cache":world.sweep_neighborhoods.size(),"sweep_result_entries":world.sweep_result_ring.size(),"sweep_result_hits":world.sweep_result_hits,"sweep_result_misses":world.sweep_result_misses,"recovery_entries":world.recovery_ring.size(),"recovery_hits":world.recovery_hits,"recovery_misses":world.recovery_misses,"recovery_invalidations":world.recovery_invalidations,"extended_sweeps":world.extended_sweeps,"sweep_neighborhood_grows":world.sweep_neighborhood_grows,"free_regions":world.free_regions.size(),"clear_points":world.clear_point_count,"nav_grids":world.nav_grids.size(),"nav_open":world.nav_open.size(),"nav_waiting":world.nav_waiting.size(),"nav_prepare_us":world.nav_prepare_us,"nav_scanned_cells":world.nav_scanned_cells,"nav_skipped_cells":world.nav_skipped_cells,"nav_skipped_rows":world.nav_skipped_rows,"nav_row_tests":world.nav_row_tests,"nav_ready_rebuilds":world.nav_ready_rebuilds,"material_certificates":world.material_certificates.size(),"material_certificate_hits":world.material_certificate_hits,"material_certificate_misses":world.material_certificate_misses,"material_certificate_builds":world.material_certificate_builds,"ore_clearance":world.ore_clearance.size(),"blocked_free_regions":world.blocked_free_regions.size(),"room_cache":world.room_cache.size(),"patch_versions":world.patch_versions.size(),"rock_meshes":terrain.meshes.size(),"retired_rock_meshes":terrain.retired_meshes.size(),"rock_patches":terrain.patches.size(),"ore_patches":terrain.ore_patches.size(),"cap_cells":terrain.cap_cells.size(),"mineral_cells":terrain.mineral_cells.size(),"map_nodes":map.nodes.size(),"map_remembered":map.remembered_types.size(),"map_spawn_jobs":map.actor_jobs.size(),"local_spawn_jobs":game.run.local_spawn_jobs.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"static_memory_bytes":static_bytes if static_bytes>0 else null,"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"viewport":[view.size.x-500,view.size.y-500],"window_mode":DisplayServer.window_get_mode(),"window_size":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"zoom":game.zoom,"position":[game.player.head.x,game.player.head.y],"engine_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"engine_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"focused":DisplayServer.window_is_focused()}
	for key in ["geometry_hits","geometry_misses","geometry_empty_misses","geometry_mask_zero","geometry_mask_full","geometry_mask_mixed","geometry_evictions","geometry_eviction_batches","collision_row_hits","collision_row_misses","collision_row_evictions","collision_block_evictions","sweep_result_invalidations","nav_invalidation_calls","nav_invalidation_cells","nav_invalidation_clear_kept","nav_invalidation_outside_kept","nav_invalidation_grids_unchanged","nav_clear_certificate_checks","nav_invalidation_fragile_clear"]:result[key]=world.get(key)
	var fracture_stats=preload("res://scripts/cave_contour_mesh.gd").cache_stats()
	for key in fracture_stats:result["fractured_"+str(key)]=fracture_stats[key]
	result.spatial_reuse_enabled=battle.spatial.use_cell_reuse
	result.absent_knockback_enabled=battle.use_absent_knockback
	result.control_absent_knockback_enabled=battle.insect_control_system.use_absent_knockback
	result.enemy_core_frame_enabled=battle.use_enemy_core_frame
	result.enemy_core_frame_entries=battle.enemy_core_frame.size()
	result.ai_component_frame_enabled=battle.use_ai_component_frame
	result.ai_component_frame_hits=battle.ai_component_frame_hits
	result.spatial_build_enabled=battle.spatial.use_spatial_build
	result.near_contact_probe_enabled=world.use_near_contact_probe
	result.near_contact_probes=world.near_contact_probes
	result.near_contact_hits=world.near_contact_hits
	result.near_contact_fallbacks=world.near_contact_fallbacks
	result.native_sweep_enabled=world.use_native_sweep
	result.native_sweep_available=world.native_available
	result.native_overlap_enabled=world.use_native_overlap
	result.native_overlap_min_radius=world.NATIVE_OVERLAP_MIN_RADIUS
	result.native_overlap_entries=world.native_overlap_cache.order.size()
	result.native_overlap_hits=world.native_overlap_cache.hits
	result.native_overlap_misses=world.native_overlap_cache.misses
	result.native_overlap_invalidations=world.native_overlap_cache.invalidations
	result.wide_near_contact_enabled=world.use_wide_near_contact
	var native_stats=world.native_accel.stats()
	for key in native_stats:result["native_sweep_"+str(key)]=native_stats[key]
	result.orbit_observer_pruning_enabled=map.use_orbit_observer_pruning
	result.orbit_observers_total=map.orbit_observers_total
	result.orbit_observers_kept=map.orbit_observers_kept
	result.wall_overlap_memo_enabled=world.use_wall_overlap_memo
	result.wall_overlap_entries=world.wall_overlap_ring.size()
	result.wall_overlap_hits=world.wall_overlap_hits
	result.wall_overlap_misses=world.wall_overlap_misses
	result.wall_overlap_invalidations=world.wall_overlap_invalidations
	result.spatial_full_rebuilds=battle.spatial.full_rebuilds
	result.spatial_reuse_frames=battle.spatial.reuse_frames
	result.visual_settling_enabled=preload("res://scripts/soft_insect.gd").use_visual_settling
	result.hostile_geometry_batch=game.attack_shader_layer.use_hostile_geometry_batch
	result.hostile_shape_meshes=game.attack_shader_layer.hostile_shape_meshes.size()
	result.hostile_shape_builds=game.attack_shader_layer.hostile_shape_builds
	var hostile_batches=game.attack_shader_layer.hostile_body_batch.stats()
	for key in hostile_batches:result["hostile_body_"+key]=hostile_batches[key]
	result.terrain_surface_batch=game.cave_terrain.use_surface_batch
	result.pod_geometry_batch=preload("res://scripts/organic_world_objects.gd").use_geometry_batch
	result.pod_meshes=preload("res://scripts/pod_geometry_batch.gd").templates.size()
	result.pod_mesh_builds=preload("res://scripts/pod_geometry_batch.gd").builds
	result.radar_icon_atlas=game.tactical_radar.use_icon_atlas and game.tactical_radar.atlas_ready
	result.neck_geometry_batch=game.neck_geometry_batch.enabled and game.soft_organs.use_gpu
	result.neck_instances=game.neck_geometry_batch.count
	result.repair_tether_batch=game.attack_shader_layer.repair_tether_batch.enabled
	result.repair_tether_instances=game.attack_shader_layer.repair_tether_batch.count
	result.actor_flight_batch=game.attack_shader_layer.flight_batch.use_actor_batch
	result.pointer_geometry_batch=preload("res://scripts/boss_direction.gd").use_geometry_batch
	result.radar_icon_batch=game.tactical_radar.icon_batch.enabled and game.tactical_radar.icon_batch.compatible_filter
	result.radar_icon_instances=game.tactical_radar.icon_batch.count
	result.radar_icon_groups=game.tactical_radar.icon_batch.group_cursor
	result.radar_icon_sources=game.tactical_radar.icon_batch.sources.size()
	result.nav_clear_certificates=world.nav_clear_certificates.size()
	return result

func record_main(key:String,microseconds:int):main_times[key]=int(main_times.get(key,0))+microseconds

func mark(game,label:String="manual_f3"):
	if writer==null:return
	sample_until=maxi(sample_until,Time.get_ticks_usec()+3000000)
	write({"type":"marker","label":label,"run_elapsed":game.run.elapsed,"screen":game.screen,"counts":counts(game)})

func write(record:Dictionary):
	if writer!=null:writer.push(record)

func attach_capture(report:Dictionary):
	# Preserve F3's detail in the same shareable journal without copying absolute
	# executable/project paths or save data into it.
	write({"type":"f3_capture","run_elapsed":report.get("run_elapsed",pending_elapsed),"frames":report.frames,"loadout":report.get("loadout",[]),"rows":report.rows})

func finish_session(reason:String):
	if last_combat!=null:last_combat.diagnostic_profile=false
	sampling=false;main_times.clear();pending_active=false;last_start=0
	if writer==null:return
	if summary_frames>0:
		var timing=stats(frame_times);timing.mean=frame_sum/summary_frames;timing.fps=1000.0/maxf(.001,timing.mean)
		var cpu=stats(cpu_times);cpu.mean=cpu_sum/summary_frames
		write({"type":"summary","partial":true,"run_elapsed":pending_elapsed,"frames":summary_frames,"frame_ms":timing,"cpu_ms":cpu,"draw_calls":{"mean":draw_sum/summary_frames,"min":draw_min,"max":draw_max,"frames":summary_frames},"active_totals":active_totals()})
	write({"type":"session_end","reason":reason,"run_elapsed":pending_elapsed,"active_frames":total_frames,"active_totals":active_totals(),"writer":writer.status()})
	writer.close();last_error=writer.status().error;writer=null
	reset_summary()

func open_directory()->Error:
	if writer!=null:write({"type":"open_directory","run_elapsed":pending_elapsed});writer.flush()
	var path=ProjectSettings.globalize_path(LOG_ROOT)
	var result=DirAccess.make_dir_recursive_absolute(path)
	return OS.shell_open(path) if result==OK else result

func _exit_tree():finish_session("shutdown")
