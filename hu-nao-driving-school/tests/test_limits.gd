extends SceneTree
const Net = preload("res://game/network.gd")
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var net = Net.new()
 root.add_child(net)
 net.latency_ms = 10000
 for i in range(256): net._schedule("input", [i, net.ZERO, 0, 0])
 assert(net.queue.size() == 256)
 net._schedule("input", [257, net.ZERO, 0, 0])
 assert(net.queue.is_empty() and net.state.phase == "room")
 assert(net.queue_peak == 256)
 print("QUEUE_LIMIT_PASS: overflow clears queue and returns to room")
 net.free()
 quit()
