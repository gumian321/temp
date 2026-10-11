extends SceneTree
const Net = preload("res://game/network.gd")
var net: Node
var host := false
var host_role := "coach"
var port := 27850
var output := "/tmp/peer.json"
var begin := 0
var round_start := 0
var observed_epoch := -1
var reports: Array = []
var seen := {}
var sent_actions := {}
var saw_brake := false
var saw_motion := false
var saw_repair := false
var saw_room_disconnect := false
var prev_phase := "room"
var started_rounds := 0
var disconnected := false
var reconnected := false
var max_pending := 0
var ticks := 0
var steps_usec: Array = []
var exit_at := 0
var physics_timeline := {}

func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg == "--host": host = true
  if arg == "--host-driver": host_role = "driver"
  if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
  if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
 net = Net.new()
 net.name = "Network"
 root.add_child.call_deferred(net)
 _launch.call_deferred()

func _launch() -> void:
 begin = Time.get_ticks_msec()
 if host: net.host(host_role, port)
 else: net.join("127.0.0.1", port)

func _process(_delta: float) -> bool:
 if begin == 0: return false
 var now := Time.get_ticks_msec()
 var elapsed := float(now - begin) / 1000
 var s: Dictionary = net.state
 ticks += 1
 physics_timeline[int(elapsed)] = int(s.tick)
 max_pending = maxi(max_pending, net.pending.size())
 if host and net.guest != 0 and s.phase == "room" and started_rounds == 0:
  net.start_match()
  started_rounds = 1
 if s.phase == "playing" and observed_epoch != int(s.epoch):
  observed_epoch = s.epoch
  round_start = now
  sent_actions.clear()
 var t := float(now - round_start) / 1000
 if s.phase == "playing":
  if net.role == "driver":
   net.local_input = [.45 if t < 9 else 0.0, 1.0, false, false]
   if reports.is_empty():
    _prank_at(t, 3, 0)
    _prank_at(t, 12, 1)
    _prank_at(t, 21, 2)
   else:
    _prank_at(t, 1, 2)
  else:
   net.local_input = [0.0, 0.0, t > 7 and t < 9, t > 23.5 and t < 28]
   if s.prank == 0 and not sent_actions.has("counter"):
    sent_actions.counter = true
    net.action("counter", 0)
  if absf(s.speed) > 2: saw_motion = true
  if s.brake and absf(s.speed) < 1: saw_brake = true
  if s.repairs > 0: saw_repair = true
  if host:
   # Explicit fixtures shorten only victory setup, never networking or event resolution.
   if t > 29 and reports.is_empty(): net.rules.s.left = minf(net.rules.s.left, .2)
   if not reports.is_empty() and t < .5: net.rules.s.anger = 90.0
   if t > 19 and reports.is_empty(): net.rules.s.resource = maxf(net.rules.s.resource, 25.0)
 if s.phase == "ended" and not seen.has(s.epoch):
  seen[s.epoch] = true
  var report := {}
  for key in ["winner", "anger", "hits", "counters", "repairs", "uses", "effects", "resource", "x", "z", "speed"]: report[key] = s[key]
  reports.append(report)
  print("CHECKPOINT ", JSON.stringify(report))
  if net.peer:
   var packet = net.peer.get_peer(net.guest if host else 1)
   print("TRANSPORT ", "inputs=",net.input_count," throttle=",packet.get_statistic(7)," limit=",packet.get_statistic(8)," deceleration=",packet.get_statistic(12))
  exit_at = now
 if host and s.phase == "ended" and now - exit_at > 2000 and reports.size() == 1:
  net.start_match()
  started_rounds += 1
 if reports.size() == 2 and not host and not disconnected and now - exit_at > 2000:
  net.leave("test client disconnect")
  disconnected = true
  saw_room_disconnect = net.state.phase == "room"
 if host and reports.size() == 2 and s.phase == "room" and net.guest == 0:
  saw_room_disconnect = true
 if not host and disconnected and not reconnected and now - exit_at > 4000:
  net.join("127.0.0.1", port)
  reconnected = true
 if host and saw_room_disconnect and net.guest != 0 and not reconnected:
  reconnected = true
  net.leave("test host disconnect")
 if not host and reconnected and not net.online and net.peer == null:
  saw_room_disconnect = true
 if elapsed > 44:
  var report := {"host": host, "host_role": host_role, "rounds": reports, "motion": saw_motion, "brake": saw_brake,
  "repair": saw_repair, "disconnect_room": saw_room_disconnect, "reconnected": reconnected,
  "snapshots": net.snapshot_count, "rtt_ms": net.rtt_ms, "max_correction_m": net.correction_max,
  "max_pending": max_pending, "queue_peak": net.queue_peak, "duplicate_events": net.duplicate_events,
  "input_count": net.input_count, "ticks": ticks, "elapsed": elapsed, "physics_timeline": physics_timeline}
  FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
  print("PEER_DONE ", JSON.stringify(report))
  net.leave("")
  quit()
 return false

func _prank_at(t: float, at: int, kind: int) -> void:
 if t >= at and not sent_actions.has(at) and net.state.cooldown <= 0 and net.state.resource >= 20:
  sent_actions[at] = true
  net.action("prank", kind)
  if not host and at == 3:
   # Deliberately duplicate one reliable command to verify receiver idempotency.
   net._command.rpc_id(1, net.event_seq, int(net.state.epoch), "prank", kind)
