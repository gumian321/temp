extends CanvasLayer
## Real wall-clock frame intervals, independent of simulation speed and pause.
const UI = preload("res://scripts/game_ui.gd")
const REFRESH_USEC = 250000
var game
var display: Control
var plate: PanelContainer
var reading: Label
var peak_reading: Label
var current_fps = 0.0
var average_ms = 0.0
var peak_ms = 0.0
var draw_calls = 0
var compact = false
var previous_usec = 0
var window_start_usec = 0
var window_frames = 0
var recent: Array[Vector2] = []
var capture_active=false
var capture_started_usec=0
var capture_deadline_usec=0
var capture_rows:Array=[]
var capture_previous_main=false
var capture_previous_combat=false
var capture_notice:Label
var capture_notice_until=0
var capture_path=""
var capture_filename="runtime-performance-latest.json"
const MAX_CAPTURE_ROWS=1024

func setup(owner_game):
	game = owner_game; layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	UI.protect(self)
	display = Control.new(); display.name = "FrameRateDisplay"
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display); display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate = PanelContainer.new(); plate.name = "FrameRatePlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(plate)
	plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	plate.offset_left = -238; plate.offset_right = -16
	plate.offset_top = -64; plate.offset_bottom = -12
	var skin = StyleBoxFlat.new()
	skin.bg_color = Color(0.025, 0.025, 0.025, 0.88)
	skin.border_color = Color(0.75, 0.74, 0.69, 0.6)
	skin.set_border_width_all(1); skin.set_corner_radius_all(4)
	skin.content_margin_left = 10; skin.content_margin_right = 10
	skin.content_margin_top = 4; skin.content_margin_bottom = 4
	plate.add_theme_stylebox_override("panel", skin)
	var rows = VBoxContainer.new(); rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 0); plate.add_child(rows)
	reading = make_label(rows, 17); reading.text = "-- FPS   -- ms"
	peak_reading = make_label(rows, 12); peak_reading.text = "1s MAX -- ms · DC --"
	peak_reading.add_theme_color_override("font_color", Color("aaa89f"))
	capture_notice=make_label(display,14)
	capture_notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	capture_notice.offset_left=-300;capture_notice.offset_right=-16
	capture_notice.offset_top=-90;capture_notice.offset_bottom=-68
	capture_notice.visible=false
	display.visible = false

func begin_capture(duration_seconds:float=3.0):
	if capture_active or game.screen!="game":return
	capture_previous_main=game.performance_profile_enabled
	capture_previous_combat=game.combat.profile_enabled
	game.performance_profile_enabled=true;game.combat.profile_enabled=true
	game.performance_samples.clear();game.combat.phase_times.clear();capture_rows.clear()
	capture_started_usec=Time.get_ticks_usec()
	capture_deadline_usec=capture_started_usec+int(clampf(duration_seconds,.1,10)*1000000)
	capture_active=true;capture_notice.visible=true;capture_notice.text="性能采样中…"

func capture_frame(now:int,elapsed:int):
	if not capture_active:return
	# Leave reward/pause frames out of live-combat attribution. This records
	# real editor play without changing damage, equipment, input or RNG.
	if elapsed>0 and game.screen=="game" and capture_rows.size()<MAX_CAPTURE_ROWS:
		capture_rows.append({"frame_ms":float(elapsed)/1000,"engine_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,
			"main_phases":game.performance_samples.duplicate(true),"combat_phases_us":game.combat.phase_times.duplicate(),
			"actors":game.combat.enemies.size(),"bullets":game.combat.bullets.size(),"hostile_bullets":game.combat.bullets.filter(func(b):return not b.friendly).size(),
			"drones":game.combat.drones.size()+game.combat.enemy_drones.size(),"death_splatters":game.combat.death_splatters.size(),
			"effects":game.combat.effects.size(),"parts":game.player.parts.size(),"zoom":game.zoom,
			"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
	game.performance_samples.clear();game.combat.phase_times.clear()
	if now<capture_deadline_usec:return
	capture_active=false
	game.performance_profile_enabled=capture_previous_main;game.combat.profile_enabled=capture_previous_combat
	var timings=capture_rows.map(func(row):return row.frame_ms);timings.sort()
	var total=0.0
	for value in timings:total+=value
	var report={"version":1,"scope":"Normal gameplay F3 diagnostic. Main/combat microseconds are instrumentation; real frame intervals include rendering and engine waits. Not a controlled before/after benchmark.",
		"captured_at":Time.get_datetime_string_from_system(),"runtime":OS.get_executable_path(),"project":ProjectSettings.globalize_path("res://"),
		"debug_build":OS.is_debug_build(),"viewport":[game.get_viewport_rect().size.x,game.get_viewport_rect().size.y],"window_size":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],
		"vsync_mode":DisplayServer.window_get_vsync_mode(),"character":game.player.character_id,
		"frames":capture_rows.size(),"average_frame_ms":total/maxi(1,timings.size()),
		"p95_frame_ms":timings[mini(timings.size()-1,int(timings.size()*.95))] if not timings.is_empty() else 0,
		"source_main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),"rows":capture_rows}
	report.source_combat_sha256=FileAccess.get_sha256("res://scripts/combat.gd")
	report.source_terrain_sha256=FileAccess.get_sha256("res://scripts/cave_world.gd")
	report.mission=game.run.mission.get("name","") if game.run!=null else ""
	report.run_elapsed=game.run.elapsed if game.run!=null else 0
	report.player_position=[game.player.head.x,game.player.head.y]
	report.loadout=game.player.parts.map(func(part):return {"core":part.id,"fusion_level":part.get("fusion_level",1)})
	capture_path=("res://artifacts/" if OS.has_feature("editor") else "user://")+capture_filename.validate_filename()
	var file=FileAccess.open(capture_path,FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(report,"\t"));file.close();capture_notice.text="性能采样已保存"
		print("PERFORMANCE_CAPTURE=",ProjectSettings.globalize_path(capture_path))
	else:capture_notice.text="性能采样未能保存"
	capture_notice_until=now+4000000

func make_label(parent: Node, font_size: int) -> Label:
	var value = Label.new(); value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_override("font", game.font)
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", Color("efede4"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(value)
	return value

func reset_samples():
	previous_usec = 0; window_start_usec = 0; window_frames = 0
	recent.clear(); current_fps = 0; average_ms = 0; peak_ms = 0
	draw_calls = 0
	refresh_readings()

func refresh_readings():
	var timing = "%.0f FPS   %.1f ms" % [current_fps, average_ms] if current_fps > 0 else "-- FPS   -- ms"
	var detail = "1s MAX %.1f ms · DC %d" % [peak_ms, draw_calls] if current_fps > 0 else "1s MAX -- ms · DC --"
	reading.text = timing + "   ·   " + detail if compact else timing
	peak_reading.text = detail

func set_compact(value: bool):
	if compact == value: return
	compact = value
	# Menu action buttons reach the lower corners. Keep diagnostics in the
	# free bottom margin as one line, instead of covering their labels.
	reading.add_theme_font_size_override("font_size", 14 if compact else 17)
	peak_reading.visible = not compact
	var skin = plate.get_theme_stylebox("panel")
	skin.content_margin_top = 2 if compact else 4
	skin.content_margin_bottom = 2 if compact else 4
	refresh_readings()
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM if compact else Control.PRESET_BOTTOM_RIGHT)
	plate.offset_left = -220 if compact else -238
	plate.offset_right = 220 if compact else -16
	plate.offset_top = -30 if compact else -64
	plate.offset_bottom = -4 if compact else -12

func _process(_dt: float):
	if game == null or display == null: return
	var active = game.screen in ["game", "pause", "build", "rewards", "result"]
	var now = Time.get_ticks_usec()
	if capture_active:capture_frame(now,maxi(0,now-previous_usec) if previous_usec>0 else 0)
	capture_notice.visible = game.screen == "game" and (capture_active or now < capture_notice_until)
	set_compact(game.screen != "game")
	if display.visible != active:
		display.visible = active; reset_samples()
	if not active: return
	if previous_usec == 0:
		previous_usec = now; window_start_usec = now; return
	var elapsed = now - previous_usec; previous_usec = now
	if elapsed <= 0: return
	window_frames += 1
	recent.append(Vector2(float(now) / 1000000.0, float(elapsed) / 1000.0))
	var span = now - window_start_usec
	if span < REFRESH_USEC: return
	current_fps = float(window_frames) * 1000000.0 / float(span)
	average_ms = float(span) / (1000.0 * float(window_frames))
	var cutoff = float(now) / 1000000.0 - 1.0
	var first = 0
	while first < recent.size() and recent[first].x < cutoff: first += 1
	if first > 0: recent = recent.slice(first)
	peak_ms = 0
	for sample in recent: peak_ms = maxf(peak_ms, sample.y)
	draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	refresh_readings()
	var tint = Color("efede4") if current_fps >= 50 else (Color("edc47c") if current_fps >= 30 else Color("ff8b9d"))
	if reading.get_theme_color("font_color") != tint: reading.add_theme_color_override("font_color", tint)
	window_start_usec = now; window_frames = 0
