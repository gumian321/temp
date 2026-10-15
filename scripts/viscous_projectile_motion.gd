extends RefCounted
## Bounded organic motion and contact presentation. No damage, RNG or actor searches.
const MAX_CONTACTS = 24
const FAST_SPEED = 900.0
const MAX_SWAY = 3.0
const EGG_LIFE = 0.72
const EGG_BURST = 0.18

static func family(weapon: String) -> String:
	if weapon in ["gatling", "shotgun", "cannon", "flame"]: return "mucus"
	if weapon in ["flak", "nuke", "mine"]: return "egg"
	if weapon in ["rocket", "drone"]: return "larva"
	if weapon in ["rail", "tesla", "sonic"]: return "tongue"
	return ""

static func initialize(shot: Dictionary, serial: int = 0):
	shot.organic_family = family(str(shot.get("fx_family", "")))
	shot.organic_motion_enabled = bool(shot.get("friendly", false)) and shot.organic_family in ["mucus", "egg", "larva"]
	shot.organic_phase = float(serial % 17) * 0.37
	shot.organic_offset = Vector2.ZERO

static func advance(shot: Dictionary, dt: float):
	# Velocity is the original simulation velocity, never modified by cosmetics.
	# Difference of bounded offsets avoids accumulating lateral drift over time.
	if not bool(shot.get("friendly", false)):
		shot.position += Vector2(shot.velocity) * dt
		return
	if not shot.has("organic_family"): initialize(shot)
	if not bool(shot.get("organic_motion_enabled", false)):
		shot.position += Vector2(shot.velocity) * dt
		return
	var previous_offset = Vector2(shot.get("organic_offset", Vector2.ZERO))
	var offset = Vector2.ZERO
	var speed = Vector2(shot.velocity).length()
	var organic = str(shot.organic_family)
	if speed > 12.0 and speed < FAST_SPEED:
		var age = float(shot.get("age", 0.0))
		var phase = float(shot.get("organic_phase", 0.0))
		var amplitude = 2.6 if organic == "larva" else (2.1 if organic == "egg" else 1.4)
		var frequency = 15.0 if organic == "larva" else 8.0
		var swell = minf(1.0, age * 8.0)
		var wave = sin(age * frequency + phase) * swell
		offset = Vector2(shot.velocity).normalized().orthogonal() * amplitude * wave
	shot.position += Vector2(shot.velocity) * dt + offset - previous_offset
	shot.organic_offset = offset

static func add_contact(effects: Array, target: Dictionary, contact: Dictionary, weapon: String, friendly: bool, radius: float, remaining_slots: int) -> bool:
	var organic = family(weapon)
	if organic.is_empty() or remaining_slots <= 0: return false
	var duration = EGG_LIFE if organic == "egg" else 0.34
	var angle = float(target.get("angle", 0.0))
	effects.append({"kind":"viscous_contact", "organic_family":organic, "fx_family":weapon,
		"friendly":friendly, "position":contact.position, "direction":contact.direction,
		"normal":contact.normal, "radius":clampf(radius * 0.52, 2.5, 10.0),
		"age":0.0, "life":duration, "fx_duration":duration, "follow":target,
		"contact_offset":(Vector2(contact.position) - Vector2(target.position)).rotated(-angle),
		"contact_normal":Vector2(contact.normal).rotated(-angle)})
	return true

static func advance_contact(effect: Dictionary, dt: float):
	if effect.get("kind", "") not in ["viscous_contact", "egg_burst"]: return
	effect.age = float(effect.get("age", 0.0)) + dt
	# Direct retained reference only; do not search enemies for a cosmetic attachment.
	var target: Dictionary = effect.get("follow", {})
	if not target.is_empty():
		if float(target.get("hp", 0.0)) <= 0.0 or bool(target.get("despawn", false)):
			effect.erase("follow")
		else:
			var angle = float(target.get("angle", 0.0))
			effect.position = Vector2(target.position) + Vector2(effect.contact_offset).rotated(angle)
			effect.normal = Vector2(effect.contact_normal).rotated(angle)
	if effect.organic_family == "egg" and float(effect.life) <= EGG_BURST:
		effect.kind = "egg_burst"
		effect.erase("follow")
