extends Node
## Channels: 0 controls (unreliable ordered), 1 snapshots (unreliable ordered),
## 2 commands/room messages (reliable). Host never waits for a client frame.
const Rules = preload("res://game/rules.gd")
const PORT := 27850
const ZERO := [0.0, 0.0, false, false]
const MAX_QUEUE := 256
signal status_changed(message: String)
var rules = Rules.new()
var state: Dictionary
var peer: ENetMultiplayerPeer
var hosting := false
var online := false
var guest := 0
var host_role := "coach"
var role := "coach"
var local_input := ZERO.duplicate()
var remote_input := ZERO.duplicate()
var remote_last := 0
var seq := 0
var ack := 0
var event_seq := 0
var last_event := 0
var accepted_events := 0
var duplicate_events := 0
var last_snapshot_tick := -1
var snapshot_epoch := -1
var pending: Array = []
var samples: Array = []
var queue: Array = []
var predicted: Dictionary = {}
var latency_ms := 0
var jitter_ms := 0
var loss := 0.0
var sent := 0
var dropped := 0
var queue_peak := 0
var correction_max := 0.0
var snapshot_count := 0
var last_receive := 0
var rtt_ms := 0.0
var demo := false
var remote_ping := 0
var remote_repair := false
var sent_repair := false
var input_count := 0
var stage_events: Array = []
var last_stage_sent := ""
var last_stage_received := -1
var stage_epoch := -1
var rejected := {"raw": 0, "seq": 0, "epoch": 0, "type": 0}

func _ready() -> void:
 state = rules.s.duplicate(true)
 multiplayer.peer_connected.connect(_peer_joined)
 multiplayer.peer_disconnected.connect(_peer_left)
 multiplayer.connected_to_server.connect(_connected)
 multiplayer.connection_failed.connect(func(): leave("连接失败，请检查内网 IP 与 UDP 27850"))
 multiplayer.server_disconnected.connect(func(): leave("房主已断线，已返回房间"))

func host(as_role: String = "coach", port: int = PORT) -> Error:
 leave("")
 peer = ENetMultiplayerPeer.new()
 var error := peer.create_server(port, 1, 3)
 if error != OK:
  status_changed.emit("建房失败：%s" % error_string(error))
  return error
 hosting = true
 online = true
 host_role = as_role
 role = as_role
 multiplayer.multiplayer_peer = peer
 status_changed.emit("房间已建好，等待另一人加入 · UDP %d" % port)
 return OK

func join(address: String, port: int = PORT) -> Error:
 leave("")
 peer = ENetMultiplayerPeer.new()
 var error := peer.create_client(address.strip_edges(), port, 3)
 if error != OK:
  status_changed.emit("加入失败：%s" % error_string(error))
  return error
 multiplayer.multiplayer_peer = peer
 last_receive = Time.get_ticks_msec()
 status_changed.emit("正在连接 %s…" % address)
 return OK

func start_demo() -> void:
 leave("")
 demo = true
 hosting = true
 role = "driver"
 rules.reset(rules.s.epoch + 1)
 rules.start()
 state = rules.s.duplicate(true)
 status_changed.emit("单机演示（不联网），Tab 切换角色")

func leave(message: String = "已返回房间") -> void:
 if peer: peer.close()
 multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
 peer = null
 online = false
 hosting = false
 demo = false
 guest = 0
 seq = 0
 ack = 0
 event_seq = 0
 last_event = 0
 snapshot_epoch = -1
 last_snapshot_tick = -1
 pending.clear()
 stage_events.clear()
 last_stage_sent = ""
 last_stage_received = -1
 stage_epoch = -1
 samples.clear()
 queue.clear()
 predicted.clear()
 local_input = ZERO.duplicate()
 remote_input = ZERO.duplicate()
 remote_repair = false
 sent_repair = false
 rules.reset(rules.s.epoch + 1)
 state = rules.s.duplicate(true)
 if not message.is_empty(): status_changed.emit(message)

func _tune_peer(id: int) -> void:
 # Two-player LAN: fixed application cadence and bounded queues control traffic.
 # RTT jitter must not drive ENet's probabilistic unreliable throttle to zero.
 var packet_peer := peer.get_peer(id)
 if packet_peer:
  packet_peer.throttle_configure(1000, 32, 0)
  packet_peer.ping_interval(250)

func _connected() -> void:
 _tune_peer(1)
 online = true
 last_receive = Time.get_ticks_msec()
 status_changed.emit("已连接，等待房主开始")

func _peer_joined(id: int) -> void:
 if hosting:
  _tune_peer(id)
  guest = id
  last_event = 0
  ack = 0
  remote_last = Time.get_ticks_msec()
  _welcome.rpc_id(id, host_role)
  status_changed.emit("两人已就座，房主可开始")

func _peer_left(id: int) -> void:
 if hosting and id == guest:
  guest = 0
  rules.reset(rules.s.epoch + 1)
  state = rules.s.duplicate(true)
  remote_input = ZERO.duplicate()
  remote_repair = false
  queue.clear()
  status_changed.emit("对方已断线，返回房间等待重新加入")

@rpc("authority", "call_remote", "reliable", 2)
func _welcome(server_role: String) -> void:
 host_role = server_role
 role = "driver" if host_role == "coach" else "coach"

func start_match() -> void:
 if not hosting or (guest == 0 and not demo): return
 rules.reset(rules.s.epoch + 1)
 rules.start()
 remote_input = ZERO.duplicate()
 remote_repair = false
 local_input = ZERO.duplicate()
 state = rules.s.duplicate(true)

func action(action_name: String, value: int = -1) -> void:
 if hosting:
  rules.event(role, action_name, value)
 elif online:
  event_seq += 1
  _schedule("event", [event_seq, int(state.epoch), action_name, value], true)

func _schedule(kind: String, data: Array, reliable: bool = false) -> void:
 sent += 1
 if not reliable and randf() < loss:
  dropped += 1
  return
 if queue.size() >= MAX_QUEUE:
  # Disconnect a stalled peer rather than growing indefinitely or pausing the host.
  if hosting and guest != 0:
   peer.disconnect_peer(guest)
   _peer_left(guest)
  else: leave("网络积压，已返回房间")
  return
 var due := Time.get_ticks_msec() + maxi(0, latency_ms + randi_range(-jitter_ms, jitter_ms))
 queue.append({"due": due, "kind": kind, "data": data})
 queue_peak = maxi(queue_peak, queue.size())

func _flush() -> void:
 var now := Time.get_ticks_msec()
 var ready: Array = []
 for i in range(queue.size() - 1, -1, -1):
  if queue[i].due <= now: ready.push_front(queue.pop_at(i))
 for item in ready:
  if not online: break
  match item.kind:
   "input": _input_packet.rpc_id(1, item.data[0], item.data[1], item.data[2], item.data[3])
   "snapshot":
    if guest != 0: _snapshot.rpc_id(guest, item.data[0], item.data[1], item.data[2])
   "stage":
    if guest != 0: _stage_notice.rpc_id(guest, item.data[0], item.data[1], item.data[2])
   "event": _command.rpc_id(1, item.data[0], item.data[1], item.data[2], item.data[3])

@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func _input_packet(number: int, controls: Array, epoch: int, stamp: int) -> void:
 if not hosting or multiplayer.get_remote_sender_id() != guest: return
 rejected.raw += 1
 if number <= ack:
  rejected.seq += 1
  return
 if controls.size() != 4 or epoch != rules.s.epoch:
  rejected.epoch += 1
  return
 for i in range(2):
  if not (controls[i] is float or controls[i] is int) or not is_finite(float(controls[i])):
   rejected.type += 1
   return
 if not controls[2] is bool or not controls[3] is bool:
  rejected.type += 1
  return
 ack = number
 input_count += 1
 remote_input = [clampf(controls[0], -1, 1), clampf(controls[1], -1, 1), controls[2], remote_repair]
 remote_last = Time.get_ticks_msec()
 remote_ping = stamp

@rpc("any_peer", "call_remote", "reliable", 2)
func _command(number: int, epoch: int, command: String, value: int) -> void:
 if not hosting or multiplayer.get_remote_sender_id() != guest: return
 if number <= last_event:
  duplicate_events += 1
  return
 last_event = number
 if epoch != rules.s.epoch or command.length() > 16: return
 var remote_role := "driver" if host_role == "coach" else "coach"
 if command == "repair_hold" and value in [0, 1]:
  remote_repair = value == 1
  return
 if rules.event(remote_role, command, value): accepted_events += 1

@rpc("authority", "call_remote", "reliable", 2)
func _stage_notice(data: Dictionary, acknowledged: int, echo: int) -> void:
 if int(data.epoch) < stage_epoch: return
 if int(data.epoch) != stage_epoch:
  stage_epoch = data.epoch
  last_stage_received = -1
 if int(data.act_serial) <= last_stage_received: return
 last_stage_received = data.act_serial
 stage_events.append({"epoch": data.epoch, "serial": data.act_serial, "kind": data.act_kind, "phase": data.act_phase, "target": data.act_target})
 if stage_events.size() > 64: stage_events.pop_front()
 _snapshot(data, acknowledged, echo)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _snapshot(data: Dictionary, acknowledged: int, echo: int) -> void:
 if hosting: return
 if int(data.epoch) < snapshot_epoch: return
 if int(data.epoch) == snapshot_epoch and int(data.tick) <= last_snapshot_tick: return
 if int(data.epoch) != snapshot_epoch:
  pending.clear()
  sent_repair = false
  samples.clear()
  predicted.clear()
 snapshot_epoch = data.epoch
 last_snapshot_tick = data.tick
 state = data
 last_receive = Time.get_ticks_msec()
 snapshot_count += 1
 if echo > 0: rtt_ms = lerpf(rtt_ms, float(last_receive - echo), .12)
 samples.append({"time": last_receive, "s": data.duplicate(true)})
 if samples.size() > 16: samples.pop_front()
 while not pending.is_empty() and pending[0].seq <= acknowledged: pending.pop_front()
 var replay := data.duplicate(true)
 # Limited prediction of kinematic motion; never replay game rules or external rigid bodies.
 if role == "driver" and data.phase == "playing":
  for frame in pending: Rules.drive(replay, frame.input, bool(data.brake), Rules.DT)
 if role == "driver" and not predicted.is_empty():
  correction_max = maxf(correction_max, Vector2(predicted.x - replay.x, predicted.z - replay.z).length())
 predicted = replay

func visual_state() -> Dictionary:
 if hosting or not online: return state
 if role == "driver" and not predicted.is_empty(): return predicted
 if samples.size() < 2: return state
 var target := Time.get_ticks_msec() - 100
 var a: Dictionary = samples[0]
 var b: Dictionary = samples[-1]
 for i in range(1, samples.size()):
  if samples[i].time >= target:
   a = samples[i - 1]
   b = samples[i]
   break
 var factor := clampf(float(target - a.time) / maxf(1.0, b.time - a.time), 0.0, 1.0)
 var v: Dictionary = b.s.duplicate(true)
 v.x = lerpf(a.s.x, b.s.x, factor)
 v.z = lerpf(a.s.z, b.s.z, factor)
 v.yaw = lerp_angle(a.s.yaw, b.s.yaw, factor)
 return v

func _physics_process(_dt: float) -> void:
 _flush()
 if hosting:
  if online and guest != 0 and Time.get_ticks_msec() - remote_last > 8000:
   var stale := guest
   peer.disconnect_peer(stale)
   _peer_left(stale)
  if Time.get_ticks_msec() - remote_last > 350: remote_input = ZERO.duplicate()
  remote_input[3] = remote_repair
  var driver: Array = local_input if role == "driver" else remote_input
  var coach: Array = local_input if role == "coach" else remote_input
  rules.step(driver, coach)
  state = rules.s.duplicate(true)
  var stage_key := "%s:%s" % [state.epoch, state.act_serial]
  if guest != 0 and stage_key != last_stage_sent:
   last_stage_sent = stage_key
   _schedule("stage", [state.duplicate(true), ack, remote_ping], true)
  if guest != 0 and int(state.tick) % 2 == 0:
   _schedule("snapshot", [state.duplicate(true), ack, remote_ping])
 elif online:
  if bool(local_input[3]) != sent_repair:
   sent_repair = bool(local_input[3])
   action("repair_hold", 1 if sent_repair else 0)
  if Time.get_ticks_msec() - last_receive > 8000:
   leave("房主响应超时，已返回房间")
   return
  seq += 1
  _schedule("input", [seq, local_input.duplicate(), int(state.epoch), Time.get_ticks_msec()])
  if role == "driver" and state.phase == "playing":
   if predicted.is_empty(): predicted = state.duplicate(true)
   Rules.drive(predicted, local_input, bool(state.brake), Rules.DT)
   pending.append({"seq": seq, "input": local_input.duplicate()})
   if pending.size() > 120: pending.pop_front()
 elif peer and Time.get_ticks_msec() - last_receive > 8000:
  leave("连接超时，已返回房间")
