extends RefCounted
## One immutable analytic burst per corpse. Reuses the generated wet atlas;
## no emitter nodes, gameplay RNG, raycasts, or per-frame particle arrays.
const Art=preload("res://scripts/viscous_projectiles.gd")
const Brood=preload("res://scripts/brood_theme.gd")
const AttackShaders=preload("res://scripts/attack_shader_layer.gd")
const Ribbon=preload("res://scripts/fluid_ribbon.gd")
const MAX_BURSTS=512
const MAX_DETAILED=32

static func eligible(e:Dictionary)->bool:
	return Brood.eligible(e) and not e.get("despawn",false)

static func make_effect(e:Dictionary)->Dictionary:
	var boss=str(e.get("kind",""))=="AIBossUnit"
	var radius=clampf(float(e.get("radius",18))*1.8,26,100 if boss else 65)
	var duration=2.0 if boss else 1.25
	var direction=Vector2(e.get("last_death_direction",Vector2.ZERO))
	if direction.length_squared()<0.0001:direction=Vector2.from_angle(float(e.get("angle",0)))
	return {"kind":"death_splatter","position":Vector2(e.position),"radius":radius,"life":duration,"fx_duration":duration,"direction":direction.normalized(),"seed":int(e.get("uid",0))%97,"boss":boss,"friendly":true}

static func paint(canvas,effect:Dictionary,zoom:float,detail:bool=true):
	canvas=AttackShaders.route(canvas,"gatling")
	var age=maxf(0,float(effect.fx_duration)-float(effect.life))
	var center:Vector2=canvas.world(effect.position)
	var radius=float(effect.radius)*zoom
	var heading:float=Vector2(effect.direction).angle()
	var fade=clampf(float(effect.life)/0.45,0,1)
	# Readable heavy puddle is mandatory even when simultaneous deaths exhaust
	# the spray budget. Fast expansion, long wet hold, then quiet evaporation.
	var open=clampf(age/0.13,0,1)
	var spread=1.0-pow(1.0-open,3)
	Art.stamp(canvas,"mucus_splat",center,Vector2(2.8,2.0)*radius*(0.24+spread*0.76),heading,fade*0.93)
	if not detail:return
	if age<0.055:
		Art.stamp(canvas,"mucus",center,Vector2(1.7,1.3)*radius*(1.0+age*5),heading,0.85)
	var membranes=Ribbon.Batch.new()
	# Three heavy, coherent jets, not a radial flower or an egg-shell explosion.
	# Their head moves outward while the neck thins and finally breaks.
	if age>=0.035 and age<0.27:
		var jet_time=clampf((age-0.035)/0.235,0,1)
		var jet_reach=1.0-pow(1.0-jet_time,2)
		for jet in 3:
			var axis=Vector2.from_angle(heading+(float(jet)-1.0)*0.46)
			var length=radius*(1.4+jet_reach*2.0)*(1.0 if jet==1 else 0.78)
			var width=radius*(0.46-jet_time*0.24)
			var alpha=clampf((0.27-age)/0.075,0,1)
			membranes.add(canvas,Ribbon.line(center,center+axis*length,7),width,age,float(effect.seed)*.13+jet,Ribbon.JET,alpha,true)
	# Pressure jets travel fastest at rupture, then flatten into landed blobs.
	var flight=clampf((age-0.035)/0.32,0,1)
	var reach=1.0-pow(1.0-flight,3)
	var count=11 if effect.boss else 7
	var beads:Array=[]
	for i in count:
		var angle=heading+float(i)*2.399963+float(effect.seed)*0.13
		var radial=Vector2.from_angle(angle)
		var direction=(radial+Vector2(effect.direction)*0.85).normalized()
		var distance=radius*(1.0+float((i*17+int(effect.seed))%11)*0.12)
		var point=center+direction*distance*reach
		point.y-=sin(flight*PI)*radius*(0.35+float(i%3)*0.13)
		var size=radius*(0.22+float(i%3)*0.085)
		if flight<1.0:
			if i<3 and flight>0.02:
				var path=PackedVector2Array()
				for sample in 6:
					var past=maxf(.035,age-float(sample)*.018)
					var fraction=clampf((past-.035)/.32,0,1)
					var prior=center+direction*distance*(1.0-pow(1.0-fraction,3))
					prior.y-=sin(fraction*PI)*radius*(.35+float(i%3)*.13)
					path.append(prior)
				membranes.add(canvas,path,size*.55,age,float(effect.seed)*.13+i,Ribbon.TAIL,fade*(1.0-flight)*.85,true)
			beads.append({"at":point,"size":Vector2(size*(1.8-flight*.8),size*(.7+flight*.3)),"heading":direction.angle(),"alpha":fade})
		else:
			beads.append({"at":point,"size":Vector2(size*1.9,size*1.15),"heading":angle,"alpha":fade*.78})
	# Every pressure neck and flying droplet trail shares one indexed submission.
	membranes.flush(canvas)
	for bead in beads:Art.stamp(canvas,"goo_bead",bead.at,bead.size,bead.heading,bead.alpha)
