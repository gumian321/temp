extends RefCounted
## One ordered, live weapon-source scan for the frame's two shield painters.
## No simulation index: map jobs can replace guns after Combat finishes its tick.
var use_snapshot=OS.get_environment("RBPEW_LEGACY_SHIELD_PRESENTATION")!="1"
var sources:Array=[]
var battle_id=0
var process_frame=-1

func prepare(battle):
	sources.clear()
	battle_id=battle.get_instance_id() if battle!=null else 0
	process_frame=Engine.get_process_frames()
	if not use_snapshot or battle==null:return
	for enemy in battle.enemies:
		if enemy.hp<=0:continue
		for index in enemy.get("guns",[]).size():
			var gun:Dictionary=enemy.guns[index]
			var core:Dictionary=battle.db.asset(gun.id)
			if core.get("class")!="ShieldCore":continue
			sources.append({"enemy":enemy,"gun":gun,"core":core,"index":index})

func current(battle)->Array:
	if battle==null:prepare(null);return sources
	if battle_id!=battle.get_instance_id() or process_frame!=Engine.get_process_frames():prepare(battle)
	return sources

static func for_canvas(canvas,battle):
	if not canvas is Object or not canvas.has_meta(&"shield_presentation"):return null
	var snapshot=canvas.get_meta(&"shield_presentation")
	if snapshot==null or not snapshot.use_snapshot:return null
	return snapshot.current(battle)
