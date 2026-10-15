extends RefCounted
## Run-local combat rewards. Menus never tick this clock or alter permanent stats.
const CHAIN_WINDOW = 4.5
const BURST_KILLS = 18
const BURST_DURATION = 6.0
const BURST_COOLDOWN = 18.0
var enabled = false
var chain = 0
var best = 0
var remaining = 0.0
var burst_left = 0.0
var recovery = 0.0
var next_burst = BURST_KILLS
var bursts = 0
var notice = ""
var notice_left = 0.0

func step(dt: float):
	if not enabled: return
	remaining = maxf(0, remaining - dt)
	burst_left = maxf(0, burst_left - dt)
	recovery = maxf(0, recovery - dt)
	notice_left = maxf(0, notice_left - dt)
	if remaining <= 0:
		chain = 0
		next_burst = BURST_KILLS

func eligible(enemy: Dictionary) -> bool:
	return enabled and bool(enemy.get("last_friendly", false)) and not bool(enemy.get("self_destructed", false)) and not bool(enemy.get("despawn", false)) and enemy.get("role", "") != "friendly" and bool(enemy.get("damageable", false)) and str(enemy.get("kind", "")) in ["AISwarmingUnit", "AIFollowingUnit", "AIPatrolUnit", "AIBossPartController", "AIGuardUnitController"]

func on_kill(enemy: Dictionary, battle):
	if not eligible(enemy) or battle.player.parts[0].hp <= 0: return
	chain += 1
	best = maxi(best, chain)
	remaining = CHAIN_WINDOW
	var refund = 0.0
	if chain == 5: refund = 1.0
	if chain == 10: refund = 1.5
	if chain >= next_burst and recovery <= 0:
		burst_left = BURST_DURATION
		recovery = BURST_COOLDOWN
		next_burst = chain + BURST_KILLS
		bursts += 1
		refund = 2.0
		notice = battle.db.ui("OVERDRIVE · damage +25% / reload +35%", "狂热爆发 · 伤害 +25% / 装填 +35%")
		notice_left = BURST_DURATION
		battle.audio_events.append({"type": 50, "position": battle.player.head, "pitch": 1.2})
	elif refund > 0:
		notice = battle.db.ui("CHAIN %d · skill -%.1fs", "%d 连杀 · 技能冷却 -%.1f秒") % [chain, refund]
		notice_left = 1.8
	if refund > 0:
		battle.character_abilities.cooldown = maxf(0, battle.character_abilities.cooldown - refund)

func damage_multiplier() -> float:
	return 1.25 if enabled and burst_left > 0 else 1.0

func rate_multiplier() -> float:
	return 1.35 if enabled and burst_left > 0 else 1.0
