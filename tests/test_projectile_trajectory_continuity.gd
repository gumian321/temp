extends SceneTree
## Production fire/step path plus isolated high-resolution integration invariants.
const Motion=preload("res://scripts/viscous_projectile_motion.gd")
const Art=preload("res://scripts/insect_projectiles.gd")
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/grid_centipede.gd")
const Combat=preload("res://scripts/combat.gd")
const FAMILIES=["gatling","shotgun","cannon","flame","flak","nuke","mine","rocket","drone","rail","tesla","sonic","emp","blackhole"]
class BodyCanvas extends RefCounted:
	var headings:Array=[]
	var textures=0
	func world(at:Vector2)->Vector2:return at
	func draw_set_transform(at:Vector2,heading:float=0.0):
		if at!=Vector2.ZERO:headings.append(heading)
	func draw_texture_rect(_texture,_rect,_tile,_modulate):textures+=1
	func draw_colored_polygon(_points,_color):pass
var checks:Array=[]
var scenarios:Array=[]
func check(ok:bool,title:String):
	checks.append({"name":title,"passed":ok})
	if not ok:printerr("FAIL: ",title)
func _initialize():call_deferred("execute")
func execute():
	# Former failure boundaries: first 0.125 s, 12/900 speed thresholds,
	# instantaneous homing-target retarget, and changing render timestep.
	for key in FAMILIES:
		for friendly in [true,false]:
			var max_error=0.0
			var max_heading_error=0.0
			for serial in 17:
				var shot={"position":Vector2.ZERO,"previous":Vector2.ZERO,"velocity":Vector2.ZERO,"age":0.0,"friendly":friendly,"fx_family":key,"damage":7.0,"shield_damage":3.0,"radius":4.0,"life":3.0,"pierce":2}
				Motion.initialize(shot,serial)
				for frame in 180:
					var dt=[1.0/30,1.0/60,1.0/120,0.1][frame%4]
					var speed=[0.0,11.9,12.0,12.1,80.0,480.0,899.9,900.0,900.1,1600.0][frame%10]
					shot.velocity=Vector2.from_angle(sin(frame*.13)*1.2)*speed
					shot.previous=shot.position;shot.age+=dt
					var before=shot.duplicate(true)
					Motion.advance(shot,dt)
					var delta=Vector2(shot.position)-Vector2(before.position)
					max_error=maxf(max_error,delta.distance_to(Vector2(before.velocity)*dt))
					if delta.length()>0.01:max_heading_error=maxf(max_heading_error,absf(delta.angle_to(shot.velocity)))
					if shot.damage!=7.0 or shot.shield_damage!=3.0 or shot.radius!=4.0 or shot.life!=3.0 or shot.pierce!=2:max_error=INF
			check(max_error<0.001 and max_heading_error<0.001,"%s friendly=%s: 17 phases and variable timesteps have no lateral correction or heading jump"%[key,friendly])
	# All catalog weapon cores, both factions, source turn/delay/speed semantics.
	var db=DB.new()
	var core_count=0
	var sources:Array=[]
	var covered_projectiles:Dictionary={}
	for source in db.catalog.values():
		if not source.has("coreProjectile"):continue
		sources.append(source);covered_projectiles[source.coreProjectile]=true;core_count+=1
	# Attack drones call the same fire({coreProjectile:...}) production entrypoint;
	# chip shrapnel has no gun core, so include its data through that same path.
	var auxiliary_count=0
	for data in db.catalog.values():
		if not str(data.get("class","")).ends_with("Projectile") or not data.has("projectileDamage") or covered_projectiles.has(data.id):continue
		sources.append({"name":data.name,"coreProjectile":data.id});auxiliary_count+=1
	for core in sources:
		var data=db.asset(core.coreProjectile)
		for hz in [30,60,120]:
			for friendly in [true,false]:
				var body=Body.new(db);var battle=Combat.new(db,body)
				var target=battle.spawn(db.pool["250"],Vector2(3000,1600))
				target.guns=[];target.hp=100000;target.max_hp=100000;target.kind="Asteroid";target.unit={};target.radius=5.0
				var origin=Vector2.ZERO if friendly else Vector2(-1800,-1000)
				if data.get("class")=="ContinuousProjectile":battle.special.continuous(core,origin,Vector2.RIGHT,friendly,{},0,1.0/hz)
				else:battle.fire(core,origin,Vector2.RIGHT,friendly,{})
				var emitted=battle.bullets.size()+battle.effects.size()+battle.barrages.size()>0
				var max_error=0.0;var max_turn=0.0;var steps=0
				var immutable=true;var heading_ok=true;var no_early_turn=true
				for frame in int(hz*.9):
					var snapshots:Array=[]
					for b in battle.bullets:snapshots.append({"shot":b,"position":b.position,"velocity":b.velocity,"damage":b.damage,"shield_damage":b.shield_damage,"pierce":b.pierce,"radius":b.radius,"direction":b.direction})
					battle.step(1.0/hz,Vector2(3000,1600),false,false)
					for snapshot in snapshots:
						var b:Dictionary=snapshot.shot
						var delta=Vector2(b.position)-Vector2(snapshot.position)
						max_error=maxf(max_error,delta.distance_to(Vector2(b.velocity)/hz))
						immutable=immutable and b.damage==snapshot.damage and b.shield_damage==snapshot.shield_damage and b.pierce==snapshot.pierce
						if data.get("class")!="SonicBasicProjectile":immutable=immutable and b.radius==snapshot.radius
						if delta.length()>0.02:heading_ok=heading_ok and absf(delta.angle_to(b.velocity))<.002 and absf(wrapf(Art.angle(b)-Vector2(b.velocity).angle(),-PI,PI))<.00001
						if data.get("class") in ["HomingProjectile","AreaHomingProjectile"]:
							var turn=absf(Vector2(snapshot.direction).angle_to(b.direction));max_turn=maxf(max_turn,turn)
							if float(b.age)<float(data.projectileTargetDelay):no_early_turn=no_early_turn and turn<.00001
						else:heading_ok=heading_ok and Vector2(b.velocity).distance_to(snapshot.velocity)<.0001
						steps+=1
				var bounded_turn=max_turn<=deg_to_rad(float(data.get("maxRotSpeed",0)))/hz+.00001
				var passed=emitted and max_error<.002 and immutable and heading_ok and bounded_turn and no_early_turn
				check(passed,"%s %dHz friendly=%s uses continuous source trajectory"%[core.name,hz,friendly])
				scenarios.append({"core":core.name,"family":Art.family({"data":data}),"projectile":str(data.get("name","")),"projectile_class":data.get("class"),"hz":hz,"friendly":friendly,"emitted":emitted,"ballistic_samples":steps,"max_position_error":max_error,"max_turn_degrees":rad_to_deg(max_turn),"passed":passed})
	# Exercise the real body painter: generated animation must not rotate the body
	# independently from its velocity / tail, or use extra primitive decorations.
	for key in FAMILIES:
		var canvas=BodyCanvas.new()
		var shot={"position":Vector2(200,100),"origin":Vector2.ZERO,"velocity":Vector2.from_angle(.43)*480,"friendly":true,"fx_family":key,"radius":4.0}
		Motion.initialize(shot,4)
		for frame in 120:Art.paint(canvas,shot,1.0,frame/60.0)
		check(canvas.headings.size()==120 and canvas.headings.all(func(angle):return absf(angle-.43)<.00001) and canvas.textures==120,key+" body stays on velocity heading with one generated-texture draw")
	# Generated-body deformation is continuous and axial across old thresholds.
	for kind in ["mucus","egg","larva","tongue"]:
		var shot={"position":Vector2.ZERO,"origin":Vector2.ZERO,"organic_phase":0.4,"velocity":Vector2.ZERO}
		var prior=Vector2.ZERO;var smooth=true
		for speed in range(0,1801):
			shot.velocity=Vector2.RIGHT*speed
			var pose=Art.wet_pose(shot,kind,.32)
			smooth=smooth and pose.is_finite() and pose.x>0 and pose.y>0
			if speed>0:smooth=smooth and pose.distance_to(prior)<.004
			prior=pose
		check(smooth,kind+" body deformation has no speed-threshold discontinuity")
	var mucus={"position":Vector2.ZERO,"origin":Vector2.ZERO,"velocity":Vector2(900,0)}
	var spray=Art.wet_pose(mucus,"mucus",0.0)
	check(spray.x>1.65 and spray.y<.75,"Fast mucus uses a front-heavy stretched jet silhouette")
	var report={"passed":checks.all(func(c):return c.passed),"scope":"14 art families, 17 deterministic phases and variable timesteps; actual fire/step of every catalog projectile core plus drone/shrapnel source data for both factions at 30/60/120 Hz. No-contact fixture isolates trajectory; collision and chip damage covered by viscous_integration and weapon_catalog.","core_count":core_count,"auxiliary_source_count":auxiliary_count,"scenario_count":scenarios.size(),"checks":checks,"scenarios":scenarios}
	FileAccess.open("res://artifacts/projectile-trajectory-continuity-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TRAJECTORY_CONTINUITY ",JSON.stringify({"passed":report.passed,"cores":core_count,"auxiliary_sources":auxiliary_count,"scenarios":scenarios.size(),"checks":checks.size()}));quit(0 if report.passed else 1)
