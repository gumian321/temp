extends RefCounted
## Visual/audio identity only: these profiles never change damage or hit geometry.
const PROFILES = {
	"gatling": {"label":"机枪", "color":Color("ffc34f"), "accent":Color("ff6b45"), "weight":0.55, "recoil":3.2, "kick":0.35, "pause":0.0, "trail":38.0, "pitch":1.05},
	"shotgun": {"label":"霰弹", "color":Color("ff9e51"), "accent":Color("f25475"), "weight":1.1, "recoil":7.0, "kick":1.15, "pause":0.014, "trail":28.0, "pitch":0.90},
	"cannon": {"label":"加农炮", "color":Color("ffb43c"), "accent":Color("ec5b42"), "weight":1.55, "recoil":9.0, "kick":2.2, "pause":0.023, "trail":68.0, "pitch":0.86},
	"flak": {"label":"高射炮", "color":Color("f4d958"), "accent":Color("eb7950"), "weight":1.15, "recoil":6.0, "kick":1.1, "pause":0.012, "trail":48.0, "pitch":0.93},
	"rail": {"label":"轨道炮", "color":Color("54d6e9"), "accent":Color("7276f2"), "weight":1.8, "recoil":10.0, "kick":2.8, "pause":0.032, "trail":180.0, "pitch":0.88},
	"tesla": {"label":"特斯拉", "color":Color("51d7ff"), "accent":Color("b172f3"), "weight":1.0, "recoil":2.5, "kick":0.65, "pause":0.0, "trail":50.0, "pitch":1.03},
	"emp": {"label":"EMP", "color":Color("46ded5"), "accent":Color("788cf2"), "weight":1.3, "recoil":5.0, "kick":1.0, "pause":0.014, "trail":58.0, "pitch":0.92},
	"flame": {"label":"火焰", "color":Color("ffb43d"), "accent":Color("f15849"), "weight":0.7, "recoil":1.0, "kick":0.15, "pause":0.0, "trail":30.0, "pitch":0.95},
	"rocket": {"label":"火箭", "color":Color("ff9150"), "accent":Color("f25064"), "weight":1.2, "recoil":5.5, "kick":1.3, "pause":0.016, "trail":100.0, "pitch":0.94},
	"nuke": {"label":"核弹", "color":Color("ffe680"), "accent":Color("fa6956"), "weight":2.7, "recoil":11.0, "kick":4.5, "pause":0.045, "trail":140.0, "pitch":0.80},
	"sonic": {"label":"声波", "color":Color("96a0ff"), "accent":Color("e079db"), "weight":1.15, "recoil":4.0, "kick":0.9, "pause":0.015, "trail":66.0, "pitch":0.89},
	"blackhole": {"label":"黑洞", "color":Color("ac81f5"), "accent":Color("ffb763"), "weight":1.65, "recoil":5.0, "kick":1.1, "pause":0.018, "trail":74.0, "pitch":0.86},
	"mine": {"label":"地雷", "color":Color("ffd165"), "accent":Color("f06576"), "weight":1.6, "recoil":0.0, "kick":2.0, "pause":0.022, "trail":25.0, "pitch":0.90},
	"drone": {"label":"攻击无人机", "color":Color("65dfc0"), "accent":Color("f1d472"), "weight":0.55, "recoil":2.0, "kick":0.25, "pause":0.0, "trail":36.0, "pitch":1.10},
	"impact": {"label":"击破", "color":Color("ffa954"), "accent":Color("779de0"), "weight":1.4, "recoil":0.0, "kick":1.8, "pause":0.0, "trail":40.0, "pitch":0.92},
}

static func family(data: Dictionary) -> String:
	if data.has("fx_family"): return str(data.fx_family)
	var name = str(data.get("name", "")).to_lower()
	for pair in [["blackhol", "blackhole"], ["sniper", "rail"], ["rail", "rail"], ["sonic", "sonic"], ["gatling", "gatling"], ["shotgun", "shotgun"], ["cannon", "cannon"], ["flak", "flak"], ["tesla", "tesla"], ["emp", "emp"], ["flame", "flame"], ["rocket", "rocket"], ["nuke", "nuke"], ["mine", "mine"], ["drone", "drone"]]:
		if pair[0] in name: return pair[1]
	return {"BlackHoleProjectile":"blackhole", "ContinuousProjectile":"flame", "EMPBasicProjectile":"emp", "SonicBasicProjectile":"sonic", "HomingProjectile":"rocket", "AreaHomingProjectile":"nuke", "AreaBasicProjectile":"cannon", "Mine":"mine"}.get(data.get("class", ""), "gatling")

static func profile(key: String) -> Dictionary:
	return PROFILES.get(key, PROFILES.impact)

static func combat_delta(dt: float, pause_left: float) -> float:
	# Integrate partial frames too: a 14ms impact must still register at 60Hz.
	return dt-minf(maxf(pause_left,0.0),dt)*0.82

static func decorate(event: Dictionary, key: String, friendly: bool = true) -> Dictionary:
	event.fx_family = key
	event.friendly = friendly
	event.fx_duration = float(event.life)
	return event

static func shot_sound(key: String, serial: int) -> Dictionary:
	return {"pitch": profile(key).pitch * (1.0 + sin(serial * 2.39996) * 0.035), "gain": 1.05 if key in ["cannon", "rail", "shotgun", "nuke"] else 0.95}
