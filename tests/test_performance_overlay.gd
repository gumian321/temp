extends SceneTree
const Overlay = preload("res://scripts/performance_overlay.gd")
const UI = preload("res://scripts/game_ui.gd")
var checks: Array = []

func check(value: bool, title: String):
	checks.append({"name": title, "passed": value})
	if not value: printerr("FAIL: ", title)

func _initialize(): call_deferred("execute")

func wait_real_seconds(seconds: float):
	var until = Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < until: await process_frame

func execute():
	root.size = Vector2i(1440, 900)
	var owner_game = {"screen": "game", "font": UI.font()}
	var overlay = Overlay.new(); root.add_child(overlay); overlay.setup(owner_game)
	await wait_real_seconds(0.35)
	check(overlay.display.visible and overlay.current_fps > 0 and is_finite(overlay.current_fps), "Native frames produce a finite visible FPS reading")
	check(absf(overlay.current_fps * overlay.average_ms - 1000.0) < 0.01, "FPS and frame time describe the same real-time sample")
	check(overlay.peak_reading.text.contains("DC ") and overlay.draw_calls>=0,"The same diagnostics panel reports the engine's actual draw-call monitor")
	var bounds = overlay.plate.get_global_rect()
	var view_size = root.get_visible_rect().size
	check(Rect2(Vector2.ZERO, view_size).encloses(bounds) and bounds.position.y > view_size.y - 85 and bounds.end.x > view_size.x - 20, "Counter fits below the minimap in the bottom-right corner")
	check(overlay.display.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.plate.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.reading.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Counter does not intercept movement or aiming clicks")
	# The runner fixes simulation dt to 1/60. This real stall must still appear
	# in the display instead of being silently reported as a 16.7ms frame.
	OS.delay_msec(70)
	var deadline = Time.get_ticks_usec() + 800000
	while Time.get_ticks_usec() < deadline:
		await process_frame
		if overlay.peak_ms >= 60: break
	check(overlay.peak_ms >= 60, "A real 70ms stall is detected even with fixed simulation dt")
	owner_game.screen = "pause"
	await wait_real_seconds(0.3)
	check(overlay.display.visible and overlay.current_fps > 0, "Sampling remains live while gameplay is paused")
	root.size = Vector2i(1280, 720)
	await process_frame; await process_frame
	bounds = overlay.plate.get_global_rect()
	view_size = root.get_visible_rect().size
	check(Rect2(Vector2.ZERO, view_size).encloses(bounds) and bounds.end.y > view_size.y - 16, "Bottom-right placement follows viewport resizing")
	owner_game.screen = "menu"; await process_frame; await process_frame
	check(not overlay.display.visible, "Run diagnostics do not cover the main menu")
	var report = {"passed": checks.all(func(c): return c.passed), "checks": checks}
	FileAccess.open("res://artifacts/performance-overlay-report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report)); overlay.queue_free(); await process_frame
	quit(0 if report.passed else 1)
