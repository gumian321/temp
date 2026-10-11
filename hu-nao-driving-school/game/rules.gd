extends RefCounted
## Pure, fixed-step authoritative rules. No scene physics or network dependencies.
const DT := 1.0 / 60.0
const COST := 20.0
const WINDUP := [1.6, 1.25, 1.8]
const ANGER := [22.0, 27.0, 32.0]
const OBSTACLES := [Vector2(0, 15), Vector2(12, 0), Vector2(-12, -12)]
var s: Dictionary

func _init() -> void:
 reset(0)

func reset(epoch: int) -> void:
 s = {"epoch": epoch, "tick": 0, "phase": "room", "winner": "", "x": 0.0, "z": 0.0,
 "yaw": 0.0, "speed": 0.0, "anger": 0.0, "resource": 40.0, "left": 300.0,
 "prank": -1, "windup": 0.0, "cooldown": 0.0, "counter_cd": 0.0,
 "uses": [0, 0, 0], "effects": [0.0, 0.0, 0.0], "repair": 0.0,
 "crash_cd": 0.0, "brake": false, "hits": 0, "counters": 0, "repairs": 0,
 "crashes": 0, "brake_charge": 3.0, "brake_locked": false, "notice": "两人就座后由房主开始", "notice_left": 3.0}

static func drive(v: Dictionary, input: Array, coach_brake: bool, dt: float) -> bool:
 var throttle := clampf(float(input[0]), -1, 1)
 var steering := clampf(float(input[1]), -1, 1)
 var braking := bool(input[2]) or coach_brake
 var speed := float(v.speed)
 if braking:
  speed = move_toward(speed, 0.0, 13.0 * dt)
 elif absf(throttle) > .05:
  speed = clampf(speed + throttle * 5.5 * dt, -5.0, 15.0)
 else:
  speed = move_toward(speed, 0.0, 1.3 * dt)
 v.yaw = wrapf(float(v.yaw) - steering * speed * .055 * dt, -PI, PI)
 var pos := Vector2(float(v.x), float(v.z))
 var next := pos + Vector2(sin(v.yaw), cos(v.yaw)) * speed * dt
 var crash := absf(next.x) > 37.0 or absf(next.y) > 37.0 or (next.y < -30.0 and absf(next.x) < 12.0)
 for obstacle in OBSTACLES:
  if next.distance_to(obstacle) < 2.4:
   crash = true
 if crash:
  speed = -speed * .15
 else:
  v.x = next.x
  v.z = next.y
 v.speed = speed
 return crash

func notify(message: String) -> void:
 s.notice = message
 s.notice_left = 3.0

func start() -> void:
 s.phase = "playing"
 notify("安全驾驶赚灵感，整蛊前摇可被反制！")

func event(role: String, action: String, value: int = -1) -> bool:
 if s.phase != "playing": return false
 if role == "driver" and action == "prank" and value >= 0 and value < 3:
  if s.prank != -1 or s.cooldown > 0 or s.resource < COST: return false
  s.resource -= COST
  s.prank = value
  s.windup = WINDUP[value]
  s.cooldown = 8.0
  notify(["正在摇汽水！教练按 1 接住", "正在折纸飞机！教练按 2 拦截", "正在掰后视镜！教练按 3 护镜"][value])
  return true
 if role == "coach" and action == "counter" and value >= 0 and value < 3:
  if s.counter_cd > 0: return false
  s.counter_cd = .65
  if s.prank == value:
   s.prank = -1
   s.windup = 0.0
   s.counters += 1
   notify("反制成功！这次没有增加怒气")
   return true
  notify("反制落空，稍等再试")
 return false

func step(driver: Array, coach: Array, dt: float = DT) -> void:
 s.tick += 1
 if s.phase != "playing": return
 s.left = maxf(0.0, s.left - dt)
 for key in ["cooldown", "counter_cd", "crash_cd", "notice_left"]:
  s[key] = maxf(0.0, float(s[key]) - dt)
 if not bool(coach[2]):
  s.brake_locked = false
  s.brake_charge = minf(3.0, s.brake_charge + dt)
 s.brake = bool(coach[2]) and not s.brake_locked and s.brake_charge > 0
 if s.brake:
  s.brake_charge = maxf(0, s.brake_charge - dt)
  if s.brake_charge <= 0: s.brake_locked = true
 var crash := drive(s, driver, s.brake, dt)
 if crash:
  if s.crash_cd <= 0:
   s.crashes += 1
   notify("碰撞：暂停灵感收益 3 秒，不增加怒气")
  s.crash_cd = 3.0
 if absf(s.speed) >= 2.0 and s.crash_cd <= 0:
  s.resource = minf(100.0, s.resource + dt * 4.0)
 for i in range(2): s.effects[i] = maxf(0.0, s.effects[i] - dt)
 if bool(coach[3]) and (s.effects[0] > 0 or s.effects[1] > 0 or s.effects[2] > 0):
  s.repair += dt
  if s.repair >= 1.5:
   s.effects = [0.0, 0.0, 0.0]
   s.repair = 0.0
   s.repairs += 1
   notify("清理／复位完成")
 else:
  s.repair = 0.0
 if s.prank >= 0:
  s.windup -= dt
  if s.windup <= 0:
   var i := int(s.prank)
   var gain: float = ANGER[i] / (1.0 + .5 * float(s.uses[i]))
   s.uses[i] += 1
   s.anger = minf(100.0, s.anger + gain)
   s.effects[i] = [6.0, 8.0, 999.0][i]
   s.hits += 1
   s.prank = -1
   notify("整蛊命中！怒气 +%.1f（重复收益递减）" % gain)
 if s.anger >= 100.0:
  s.phase = "ended"
  s.winner = "driver"
 elif s.left <= 0:
  s.phase = "ended"
  s.winner = "coach"
