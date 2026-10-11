extends Node3D
const Net = preload("res://game/network.gd")
var net: Node
var world: Node3D
var room: PanelContainer
var hud: PanelContainer
var result: PanelContainer
var status: Label
var role_label: Label
var stats: Label
var warning: Label
var instructions: Label
var result_label: Label
var anger: ProgressBar
var resource: ProgressBar
var ip: LineEdit
var host_choice: OptionButton
var start_button: Button
var light_toggle: CheckButton
var room_message := "同一局域网 · 一辆桑塔纳 · 两个座位"
var ui_elapsed := 0.0
var capture_path := ""
var benchmark := false
var bench_frames: Array = []
var bench_start := 0
var audio_player: AudioStreamPlayer
var bench_previous := 0
var bench_count := 0
var last_hits := 0
var last_counters := 0

func _ready() -> void:
 net = Net.new()
 net.name = "Network"
 add_child(net)
 net.status_changed.connect(func(message: String): room_message = message)
 world = preload("res://game/world.gd").new()
 add_child(world)
 _ui()
 _audio()
 for arg in OS.get_cmdline_user_args():
  if arg == "--demo": net.start_demo()
  if arg == "--low": world.set_low(true); light_toggle.button_pressed = true
  if arg == "--chase": world.view_mode = 1
  if arg == "--coach": net.role = "coach"
  if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
  if arg == "--benchmark": benchmark = true; bench_start = Time.get_ticks_msec()

func _panel(parent: Node, pos: Vector2, size: Vector2) -> PanelContainer:
 var panel := PanelContainer.new()
 panel.position = pos
 panel.custom_minimum_size = size
 var style := StyleBoxFlat.new()
 style.bg_color = Color("172e32", .94)
 style.corner_radius_top_left = 14
 style.corner_radius_top_right = 14
 style.corner_radius_bottom_left = 14
 style.corner_radius_bottom_right = 14
 style.content_margin_left = 22
 style.content_margin_right = 22
 style.content_margin_top = 16
 style.content_margin_bottom = 16
 panel.add_theme_stylebox_override("panel", style)
 parent.add_child(panel)
 return panel

func _column(parent: Node) -> VBoxContainer:
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation", 10)
 parent.add_child(column)
 return column

func _label(parent: Node, caption: String, size: int = 18, color: Color = Color("edf0df")) -> Label:
 var label := Label.new()
 label.text = caption
 label.add_theme_font_size_override("font_size", size)
 label.add_theme_color_override("font_color", color)
 parent.add_child(label)
 return label

func _button(parent: Node, caption: String, callback: Callable) -> Button:
 var button := Button.new()
 button.text = caption
 button.custom_minimum_size.y = 42
 button.add_theme_font_size_override("font_size", 18)
 button.pressed.connect(callback)
 parent.add_child(button)
 return button

func _bar(parent: Node, color: Color) -> ProgressBar:
 var bar := ProgressBar.new()
 bar.custom_minimum_size = Vector2(280, 18)
 bar.show_percentage = false
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.corner_radius_top_left = 5
 style.corner_radius_top_right = 5
 style.corner_radius_bottom_left = 5
 style.corner_radius_bottom_right = 5
 bar.add_theme_stylebox_override("fill", style)
 parent.add_child(bar)
 return bar

func _ui() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 var title := _label(layer, "胡闹驾校", 38)
 title.position = Vector2(30, 22)
 title.add_theme_color_override("font_shadow_color", Color("192c2e"))
 title.add_theme_constant_override("shadow_offset_x", 2)
 title.add_theme_constant_override("shadow_offset_y", 2)
 var subtitle := _label(layer, "1985  /  双人局域网试驾", 16)
 subtitle.position = Vector2(32, 75)
 room = _panel(layer, Vector2(30, 120), Vector2(438, 500))
 var col := _column(room)
 _label(col, "今天谁坐副驾？", 26, Color("f4c97b"))
 _label(col, "学员把怒气加到 100 获胜\n教练反制整蛊，撑过 5 分钟获胜", 18)
 status = _label(col, "", 15, Color("b8d8d3"))
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 status.custom_minimum_size.x = 390
 host_choice = OptionButton.new()
 host_choice.add_item("房主：教练（右座）")
 host_choice.add_item("房主：学员（左座）")
 host_choice.custom_minimum_size.y = 38
 col.add_child(host_choice)
 _button(col, "建房 · 等待同伴", func(): net.host("coach" if host_choice.selected == 0 else "driver"))
 ip = LineEdit.new()
 ip.placeholder_text = "输入房主内网 IP，如 192.168.1.20"
 ip.custom_minimum_size.y = 40
 col.add_child(ip)
 _button(col, "加入房间", func():
  if ip.text.strip_edges().is_empty(): room_message = "请先填写房主的内网 IP"
  else: net.join(ip.text))
 start_button = _button(col, "两人就座 · 开始", func(): net.start_match())
 _button(col, "单机演示 · Tab 切换角色", func(): net.start_demo())
 _label(col, "内网地址：" + _addresses() + "\n端口 UDP 27850 · 无互联网匹配", 14, Color("b8c7bf"))
 hud = _panel(layer, Vector2(30, 120), Vector2(335, 225))
 var h := _column(hud)
 role_label = _label(h, "", 24, Color("f4c97b"))
 stats = _label(h, "", 17)
 anger = _bar(h, Color("ef765a"))
 resource = _bar(h, Color("64c9b6"))
 warning = _label(h, "", 17, Color("ffd18b"))
 warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 warning.custom_minimum_size.x = 286
 var foot := _panel(layer, Vector2(30, 641), Vector2(1220, 130))
 var f := _column(foot)
 instructions = _label(f, "", 17)
 var opts := HBoxContainer.new()
 opts.add_theme_constant_override("separation", 16)
 f.add_child(opts)
 light_toggle = CheckButton.new()
 light_toggle.text = "轻量：65% 3D 分辨率 / 无阴影"
 light_toggle.toggled.connect(func(on: bool): world.set_low(on))
 opts.add_child(light_toggle)
 _button(opts, "V  座位 / 追车", func(): world.view_mode = 1 - world.view_mode)
 _button(opts, "Esc  返回房间", func(): net.leave())
 result = _panel(layer, Vector2(430, 238), Vector2(470, 225))
 var end := _column(result)
 result_label = _label(end, "", 26, Color("f4c97b"))
 _label(end, "房主可重新开局，双方保持原座位。", 17)
 _button(end, "房主重新开局", func(): net.start_match())
 _button(end, "离开 · 返回房间", func(): net.leave())

func _addresses() -> String:
 var addresses: Array[String] = []
 for address in IP.get_local_addresses():
  if ":" not in address and address != "127.0.0.1": addresses.append(address)
 return ", ".join(addresses)

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode == KEY_ESCAPE: net.leave(); return
 if event.keycode == KEY_V: world.view_mode = 1 - world.view_mode
 if event.keycode == KEY_TAB and net.demo:
  net.role = "coach" if net.role == "driver" else "driver"
  net.local_input = net.ZERO.duplicate()
 if net.state.phase != "playing": return
 if event.keycode in [KEY_1, KEY_2, KEY_3]:
  net.action("prank" if net.role == "driver" else "counter", event.keycode - KEY_1)

func _physics_process(_dt: float) -> void:
 if net.state.phase != "playing": return
 var steer := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
 var throttle := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
 net.local_input = [throttle, steer, Input.is_physical_key_pressed(KEY_SPACE), Input.is_physical_key_pressed(KEY_R)]
 if not DisplayServer.window_is_focused(): net.local_input = net.ZERO.duplicate()

func _process(dt: float) -> void:
 world.update_view(net.visual_state(), net.role, dt)
 ui_elapsed += dt
 if ui_elapsed >= .1:
  ui_elapsed = 0
  _update_hud()
 if net.state.hits != last_hits or net.state.counters != last_counters:
  audio_player.pitch_scale = .75 if net.state.hits != last_hits else 1.5
  audio_player.play()
  last_hits = net.state.hits
  last_counters = net.state.counters
 if benchmark:
  var now := Time.get_ticks_usec()
  bench_count += 1
  if bench_count > 5 and bench_previous > 0: bench_frames.append(float(now - bench_previous) / 1000.0)
  bench_previous = now
  if bench_frames.size() >= 30 or Time.get_ticks_msec() - bench_start > 120000: _finish_benchmark()
 elif not capture_path.is_empty() and Time.get_ticks_msec() > 7000:
  var path := capture_path
  capture_path = ""
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(path)

func _update_hud() -> void:
 var s: Dictionary = net.state
 room.visible = s.phase == "room"
 hud.visible = s.phase != "room"
 result.visible = s.phase == "ended"
 status.text = room_message
 start_button.disabled = not net.hosting or net.guest == 0
 role_label.text = ("学员 · 左侧驾驶位" if net.role == "driver" else "教练 · 固定右侧副驾")
 if net.demo: role_label.text += " [演示]"
 stats.text = "%02d:%02d  |  %.0f km/h\n怒气 %.0f / 100  ·  灵感 %.0f / 100" % [int(s.left) / 60, int(s.left) % 60, absf(s.speed) * 3.6, s.anger, s.resource]
 anger.value = s.anger
 resource.value = s.resource
 if s.prank >= 0:
  warning.text = ["汽水即将喷出 · 按 1 接住", "纸飞机起飞前 · 按 2 拦截", "后视镜要歪了 · 按 3 护镜"][s.prank] + "\n反制窗口 %.1f 秒" % s.windup
 elif s.repair > 0:
  warning.text = "修复中… %.0f%%" % (s.repair / 1.5 * 100)
 elif s.notice_left > 0:
  warning.text = s.notice
 else:
  warning.text = "整蛊冷却 %.1fs  |  %s" % [s.cooldown, "副刹生效" if s.brake else "副刹余量 %.1fs" % s.brake_charge]
 if s.effects[0] > 0: warning.text += "\n汽水弄脏衣服，R 清理"
 if s.effects[1] > 0: warning.text += "\n纸飞机卡住，R 清理"
 if s.effects[2] > 0: warning.text += "\n镜面歪斜，R 复位"
 instructions.text = ("学员：W/S 前进倒车 · A/D 转向 · 空格刹车  |  1 汽水 / 2 纸飞机 / 3 掰镜（各 20 灵感）" if net.role == "driver" else "教练：空格副刹（3秒，松开恢复） · 1 接汽水 / 2 拦飞机 / 3 护镜（前摇内按对应键） · 按住 R 1.5 秒修复")
 instructions.text += "\n" + ("单机演示，Tab 切换座位 · " if net.demo else "") + "V 切换视角 · 镜面为装饰环境色，非实时后视 · "
 instructions.text += "%.0f FPS / %.0f ms RTT" % [Engine.get_frames_per_second(), net.rtt_ms]
 if s.phase == "ended": result_label.text = "学员获胜！怒气爆表" if s.winner == "driver" else "教练获胜！顺利下课"

func _audio() -> void:
 var bytes := PackedByteArray()
 var rate := 22050
 for i in range(4400):
  var t := float(i) / rate
  var value := int(sin(t * TAU * 520) * (1.0 - float(i) / 4400) * 7000)
  bytes.append(value & 255)
  bytes.append((value >> 8) & 255)
 var stream := AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = rate
 stream.data = bytes
 audio_player = AudioStreamPlayer.new()
 audio_player.stream = stream
 add_child(audio_player)

func _finish_benchmark() -> void:
 benchmark = false
 bench_frames.sort()
 var total := 0.0
 for value in bench_frames: total += value
 var report := {"adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
 "low": world.low, "frames": bench_frames.size(), "mean_ms": total / max(1, bench_frames.size()),
 "p95_ms": bench_frames[int(bench_frames.size() * .95)] if not bench_frames.is_empty() else 0,
 "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
 "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
 "note": "Graphical frame timing, separate from headless rule/network tests. Software renderer is not GPU evidence."}
 print("BENCHMARK ", JSON.stringify(report))
 if not capture_path.is_empty():
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(capture_path)
  FileAccess.open(capture_path + ".json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
 get_tree().quit()
