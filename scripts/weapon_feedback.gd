extends RefCounted
## Visual/audio identity only: these profiles never change damage or hit geometry.
const PROFILES = {
	"toxin": {"label":"毒囊", "color":Color("9de84b"), "accent":Color("668b2e"), "weight":0.75, "recoil":4.0, "kick":0.4, "pause":0.0, "trail":30.0, "pitch":0.86},
	"boneblade": {"label":"回旋骨刃", "color":Color("eee0b5"), "accent":Color("b58ef0"), "weight":1.0, "recoil":5.0, "kick":0.8, "pause":0.0, "trail":38.0, "pitch":1.08},
	"parasite": {"label":"寄生荚", "color":Color("f395bf"), "accent":Color("a94d85"), "weight":0.8, "recoil":4.5, "kick":0.5, "pause":0.0, "trail":30.0, "pitch":0.93},
	"gatling": {"label":"蜂尾针簇", "color":Color("ffc34f"), "accent":Color("ff6b45"), "weight":0.55, "recoil":3.2, "kick":0.35, "pause":0.0, "trail":38.0, "pitch":1.05},
	"shotgun": {"label":"裂颚", "color":Color("ff9e51"), "accent":Color("f25475"), "weight":1.1, "recoil":7.0, "kick":1.15, "pause":0.014, "trail":28.0, "pitch":0.90},
	"cannon": {"label":"爆腹", "color":Color("ffb43c"), "accent":Color("ec5b42"), "weight":1.55, "recoil":9.0, "kick":2.2, "pause":0.023, "trail":68.0, "pitch":0.86},
	"flak": {"label":"刺冠", "color":Color("f4d958"), "accent":Color("eb7950"), "weight":1.15, "recoil":6.0, "kick":1.1, "pause":0.012, "trail":48.0, "pitch":0.93},
	"rail": {"label":"穿喙", "color":Color("54d6e9"), "accent":Color("7276f2"), "weight":1.8, "recoil":10.0, "kick":2.8, "pause":0.032, "trail":180.0, "pitch":0.88},
	"tesla": {"label":"雷须", "color":Color("51d7ff"), "accent":Color("b172f3"), "weight":1.0, "recoil":2.5, "kick":0.65, "pause":0.0, "trail":50.0, "pitch":1.03},
	"emp": {"label":"缄鸣", "color":Color("46ded5"), "accent":Color("788cf2"), "weight":1.3, "recoil":5.0, "kick":1.0, "pause":0.014, "trail":58.0, "pitch":0.92},
	"flame": {"label":"炽嗉", "color":Color("ffb43d"), "accent":Color("f15849"), "weight":0.7, "recoil":1.0, "kick":0.15, "pause":0.0, "trail":30.0, "pitch":0.95},
	"rocket": {"label":"追蛹", "color":Color("ff9150"), "accent":Color("f25064"), "weight":1.2, "recoil":5.5, "kick":1.3, "pause":0.016, "trail":100.0, "pitch":0.94},
	"nuke": {"label":"王卵", "color":Color("ffe680"), "accent":Color("fa6956"), "weight":2.7, "recoil":11.0, "kick":4.5, "pause":0.045, "trail":140.0, "pitch":0.80},
	"sonic": {"label":"振翅", "color":Color("96a0ff"), "accent":Color("e079db"), "weight":1.15, "recoil":4.0, "kick":0.9, "pause":0.015, "trail":66.0, "pitch":0.89},
	"blackhole": {"label":"螳涡", "color":Color("ac81f5"), "accent":Color("ffb763"), "weight":1.65, "recoil":5.0, "kick":1.1, "pause":0.018, "trail":74.0, "pitch":0.86},
	"mine": {"label":"裂卵", "color":Color("ffd165"), "accent":Color("f06576"), "weight":1.6, "recoil":0.0, "kick":2.0, "pause":0.022, "trail":25.0, "pitch":0.90},
	"drone": {"label":"猎蜂", "color":Color("65dfc0"), "accent":Color("f1d472"), "weight":0.55, "recoil":2.0, "kick":0.25, "pause":0.0, "trail":36.0, "pitch":1.10},
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

## Bounded, monotonic world-space extent from the damage carried by this hit.
## No family multiplier: a buffed weak gun must grow too, and huge damage caps.
static func impact_size(damage: float) -> float:
	return clampf(3.5 + sqrt(maxf(0.0,damage))*1.65,3.5,24.0)

## Earliest swept-circle contact, projected back onto the target surface.
## This is presentation only; it deliberately does not change collision ordering.
static func surface_contact(center: Vector2, radius: float, shot: Dictionary, projectile_radius: float = -1.0) -> Dictionary:
	var start=Vector2(shot.get("previous",shot.get("position",center)))
	var finish=Vector2(shot.get("position",center))
	var axis=Vector2(shot.get("velocity",shot.get("direction",Vector2.RIGHT))).normalized()
	if axis.length_squared()<0.001:axis=Vector2.RIGHT
	# Hitscan, chain beams and continuous emitters have no travelled segment yet.
	if start.distance_squared_to(finish)<0.001:
		finish=center
		if start.distance_squared_to(center)>0.001:axis=start.direction_to(center)
	var delta=finish-start
	var expanded=maxf(0.1,radius)+maxf(0.0,float(shot.get("radius",0.0)) if projectile_radius<0 else projectile_radius)
	var offset=start-center
	var a=delta.length_squared()
	var on_path=Geometry2D.get_closest_point_to_segment(center,start,finish)
	if a>0.0001:
		var half_b=offset.dot(delta)
		var disc=half_b*half_b-a*(offset.length_squared()-expanded*expanded)
		if disc>=0:
			var entry=(-half_b-sqrt(disc))/a
			if entry>=0 and entry<=1:on_path=start+delta*entry
	var normal=(on_path-center).normalized()
	if normal.length_squared()<0.001:normal=-axis
	return {"position":center+normal*maxf(0.1,radius),"normal":normal,"direction":axis}


static func shield_contact(center: Vector2, radius: float, shot: Dictionary) -> Dictionary:
	var path=shot.duplicate()
	# Hull collision may be several frames beyond the shield edge already.
	path.previous=shot.get("origin",shot.get("previous",shot.get("position",center)))
	return surface_contact(center,radius,path,0.0)
