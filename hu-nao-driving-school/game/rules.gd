extends RefCounted
## Pure, fixed-step authoritative rules. No scene physics or network dependencies.
const DT := 1.0 / 60.0
const COST := 20.0
const WINDUP := [1.6, 1.25, 1.8, 2.2, 2.4, 2.5]
const NAMES := ["汽水", "纸飞机", "掰镜", "放屁甩锅", "鼻涕纸献殷勤", "玩具复读机"]
const CUES := ["摇汽水！按 1 接住", "折纸飞机！按 2 拦截", "伸手掰镜！按 3 护镜", "肚子咕噜，风口偷转！按 1 拨回", "噗——擤鼻涕！按 2 张开垃圾袋", "红灯闪、试音中！按 3 倒带"]
const TAUNTS := ["学员：这风怎么有味儿？肯定不是我！", "学员：教练您辛苦了，纸给您！", "复读机：教练别紧张！这车比我还稳！"]
const RETORTS := ["教练：风口还你。学员：我突然不想呼吸了……", "教练：垃圾袋接住，原路奉还！学员：我自己留着……", "倒带：我错了我错了……学员：刚才那段不算！"]
const ANGER := [22.0, 27.0, 32.0, 24.0, 28.0, 25.0]
const OBSTACLES := [Vector2(0, 15), Vector2(12, 0), Vector2(-12, -12)]
var s: Dictionary

func _init() -> void:
 reset(0)

func reset(epoch: int) -> void:
 s = {"epoch": epoch, "tick": 0, "phase": "room", "winner": "", "x": 0.0, "z": 0.0,
 "yaw": 0.0, "speed": 0.0, "anger": 0.0, "resource": 40.0, "left": 300.0,
 "prank": -1, "windup": 0.0, "cooldown": 0.0, "counter_cd": 0.0,
 "uses": [0, 0, 0, 0, 0, 0], "effects": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "repair": 0.0,
 "backlash": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "driver_repair": 0.0, "backfires": 0, "driver_repairs": 0,
 "act_serial": 0, "act_kind": -1, "act_phase": "idle", "act_left": 0.0, "act_duration": 0.0,
 "act_target": "coach", "act_variant": 0,
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

func perform(kind: int, phase_name: String, duration: float, target: String = "coach") -> void:
 s.act_serial += 1
 s.act_kind = kind
 s.act_phase = phase_name
 s.act_left = duration
 s.act_duration = duration
 s.act_target = target
 s.act_variant = (s.act_serial + kind) % 3

func event(role: String, action: String, value: int = -1) -> bool:
 if s.phase != "playing": return false
 if role == "driver" and action == "prank" and value >= 0 and value < 6:
  if s.prank != -1 or s.cooldown > 0 or s.resource < COST: return false
  s.resource -= COST
  s.prank = value
  s.windup = WINDUP[value]
  s.cooldown = 8.0
  perform(value, "windup", WINDUP[value])
  notify(CUES[value])
  return true
 if role == "coach" and action == "counter" and value >= 0 and value < 6:
  if s.counter_cd > 0: return false
  s.counter_cd = .65
  if s.prank == value:
   s.prank = -1
   s.windup = 0.0
   s.counters += 1
   if value >= 3:
    s.backlash[value] = 6.0 if value != 4 else 999.0
    s.backfires += 1
    s.resource = maxf(0, s.resource - 5.0)
    perform(value, "counter", 3.0, "driver")
    notify(RETORTS[value - 3])
   else:
    perform(value, "counter", 1.5, "driver")
    notify("反制成功！这次没有增加怒气")
   return true
  notify("反制落空，稍等再试")
 return false

func step(driver: Array, coach: Array, dt: float = DT) -> void:
 s.tick += 1
 if s.phase != "playing": return
 s.left = maxf(0.0, s.left - dt)
 for key in ["cooldown", "counter_cd", "crash_cd", "notice_left", "act_left"]:
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
 for i in [0, 1, 3, 5]:
  s.effects[i] = maxf(0.0, s.effects[i] - dt)
  s.backlash[i] = maxf(0.0, s.backlash[i] - dt)
 _repair("coach", bool(coach[3]), dt)
 _repair("driver", bool(driver[3]), dt)
 if s.act_left <= 0 and s.prank < 0: s.act_phase = "idle"
 if s.prank >= 0:
  s.windup -= dt
  if s.windup <= 0:
   var i := int(s.prank)
   var gain: float = ANGER[i] / (1.0 + .5 * float(s.uses[i]))
   s.uses[i] += 1
   s.anger = minf(100.0, s.anger + gain)
   s.effects[i] = [6.0, 8.0, 999.0, 7.0, 999.0, 8.0][i]
   s.hits += 1
   s.prank = -1
   perform(i, "hit", 3.0)
   notify(TAUNTS[i - 3] if i >= 3 else "整蛊命中！怒气 +%.1f（重复收益递减）" % gain)
 if s.anger >= 100.0:
  s.phase = "ended"
  s.winner = "driver"
 elif s.left <= 0:
  s.phase = "ended"
  s.winner = "coach"

func _repair(role: String, held: bool, dt: float) -> void:
 var target: Array = s.effects if role == "coach" else s.backlash
 var key := "repair" if role == "coach" else "driver_repair"
 var dirty := false
 var kind := -1
 for i in range(target.size()):
  if target[i] > 0:
   dirty = true
   kind = i
 if held and dirty:
  s[key] += dt
  if s[key] >= 1.5:
   target.fill(0.0)
   s[key] = 0.0
   s["repairs" if role == "coach" else "driver_repairs"] += 1
   if s.prank < 0: perform(kind, "repair", 1.2, role)
   notify("教练：收拾干净，继续开。" if role == "coach" else "学员：我只是……自己擦一下。")
 else:
  s[key] = 0.0
