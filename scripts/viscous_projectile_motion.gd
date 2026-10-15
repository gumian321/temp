extends RefCounted
## Ballistic integration and organic contact presentation. No damage, RNG or actor searches.
const MAX_CONTACTS = 24
const MAX_SWAY = 0.0
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
	shot.organic_motion_enabled = false
	shot.organic_phase = float(serial % 17) * 0.37
	shot.organic_offset = Vector2.ZERO

static func advance(shot: Dictionary, dt: float):
	# A projectile center must follow its gameplay velocity exactly. Formerly a
	# sine offset entered collision position, rotated with homing, and snapped to
	# zero at 900 units/s. Those cosmetic corrections produced visible corners.
	# Wetness belongs to the generated sprite's axial stretch, never its path.
	# Homing already changes velocity with the source weapon's bounded turn rate.
	shot.position += Vector2(shot.velocity) * dt

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
