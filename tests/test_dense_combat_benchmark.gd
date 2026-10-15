extends SceneTree
# Deterministic CPU workload. No rendering, frame pacing, or GPU claims.
const FIXTURE_SEED = 20261014
const DT = 1.0 / 60.0
const WARMUP = 90
const TICKS = 360
func _initialize():
 call_deferred("execute")
func quantiles(values: Array) -> Dictionary:
 var ordered = values.duplicate()
 ordered.sort()
 var total = 0.0
 for value in ordered: total += float(value)
 return {"p50":ordered[ordered.size()/2], "p95":ordered[mini(ordered.size()-1,int(ordered.size()*0.95))], "mean":total/ordered.size(), "max":ordered[-1]}
func execute():
 var db = load("res://scripts/source_db.gd").new()
 var results = []
 for config in [{"name":"low","parts":13,"enemies":32,"bullets":64},{"name":"medium","parts":31,"enemies":128,"bullets":256},{"name":"high","parts":61,"enemies":384,"bullets":768}]:
  seed(FIXTURE_SEED)
  var player = load("res://scripts/centipede.gd").new(db)
  var battle = load("res://scripts/combat.gd").new(db,player)
  battle.profile_enabled = true
  var gun = db.named("Core_Gun_Gatling")
  var cells = []
  for y in range(-5,6):
   for x in range(-5,6): cells.append(Vector2i(x,y))
  cells.sort_custom(func(a,b): return a.length_squared()<b.length_squared())
  for cell in cells:
   player.add_piece(gun.id,cell)
   if player.parts.size() == config.parts: break
  assert(player.parts.size() == config.parts)
  for part in player.parts:
   part.hp = 10000000.0
   part.max_hp = 10000000.0
  for i in range(config.enemies):
   var angle = TAU * float(i) / config.enemies
   var enemy = battle.spawn(db.pool["256" if i%4 == 0 else "255"],Vector2.from_angle(angle)*(350.0+float(i%9)*75.0))
   enemy.hp = 10000000.0
   enemy.max_hp = 10000000.0
  var times = []; var player_times = []; var combat_times = []; var counts = []
  var phases = {}; var injection_total = 0
  for tick in range(WARMUP+TICKS):
   # Use the production fire path to sustain pressure without hand-made bullet structs.
   # Injection and upkeep are explicitly outside timed simulation; all resulting AI,
   # targeting, collision, damage, cleanup, and generated effects run normally.
   var missing = maxi(0,config.bullets-battle.bullets.size())
   for i in range(missing):
    var angle = float(tick*17+i)*2.39996323
    var friendly = i%2==0
    var at = player.head + Vector2.from_angle(angle)*(60.0 if friendly else 800.0)
    var direction = Vector2.from_angle(angle) * (1.0 if friendly else -1.0)
    battle.fire(gun,at,direction,friendly,{},0.0,true)
    injection_total += 1
   if tick == WARMUP: battle.phase_times.clear()
   var before_phases = battle.phase_times.duplicate()
   var start = Time.get_ticks_usec()
   player.step(DT,Vector2.from_angle(tick*0.011),false)
   var split = Time.get_ticks_usec()
   battle.step(DT,player.head+Vector2.RIGHT*600,true)
   var end = Time.get_ticks_usec()
   if tick >= WARMUP:
    times.append((end-start)/1000.0)
    player_times.append((split-start)/1000.0)
    combat_times.append((end-split)/1000.0)
    counts.append({"enemies":battle.enemies.size(),"bullets":battle.bullets.size(),"parts":player.parts.size(),"effects":battle.effects.size()})
    for key in battle.phase_times:
     if not phases.has(key): phases[key] = []
     phases[key].append((int(battle.phase_times[key])-int(before_phases.get(key,0)))/1000.0)
   battle.audio_events.clear()
   player.feedback_events.clear()
  var phase_summary = {}
  for key in phases: phase_summary[key] = quantiles(phases[key])
  var count_summary = {}
  for key in ["enemies","bullets","parts","effects"]:
   var values = []
   for sample in counts: values.append(sample[key])
   count_summary[key] = quantiles(values)
  var enemy_hp = 0.0
  for enemy in battle.enemies: enemy_hp += enemy.hp
  var result = {"config":config,"step_ms":quantiles(times),"player_ms":quantiles(player_times),"combat_ms":quantiles(combat_times),"phases_ms":phase_summary,"entities":count_summary,"injected_shots":injection_total,"signature":{"enemies":battle.enemies.size(),"bullets":battle.bullets.size(),"enemy_hp_sum":enemy_hp,"head":[player.head.x,player.head.y],"kills":battle.kills,"rng_state":str(battle.rng.state)}}
  results.append(result)
  print("DENSE_SCENARIO ",JSON.stringify(result))
 var report = {"fixture_version":1,"seed":FIXTURE_SEED,"warmup_ticks":WARMUP,"measured_ticks":TICKS,"dt":DT,"engine":Engine.get_version_info().string,"revision":OS.get_environment("RBPEW_REVISION"),"scope":"Headless fixed-step CPU only, production player/combat methods; durable actors and production-fired projectile floor; no renderer, mission director, audio playback, or UI. Sustaining injection is untimed. Effects are retained and expire normally.","results":results}
 var output = OS.get_environment("RBPEW_DENSE_OUTPUT")
 if output.is_empty(): output = "res://artifacts/dense-combat-benchmark.json"
 var file = FileAccess.open(output,FileAccess.WRITE)
 if file == null:
  push_error("Cannot write benchmark report: "+output)
  quit(1)
  return
 file.store_string(JSON.stringify(report,"\t"))
 file.close()
 print("DENSE_REPORT ",output)
 quit()
