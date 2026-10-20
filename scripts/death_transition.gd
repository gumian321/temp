extends RefCounted
## Real-time presentation of the fatal impact, after the result is recorded once.
## No global Engine.time_scale: menus and the next run never inherit slow motion.
const DURATION=1.15
const Motion=preload("res://scripts/viscous_projectile_motion.gd")
const Soft=preload("res://scripts/soft_insect.gd")
var active=false
var elapsed=0.0
var base_zoom=1.0
var previous:Dictionary={}
var velocities:Dictionary={}
var particle_speeds:Array=[]

func observe(enemies:Array,dt:float):
	var retained:Dictionary={}
	velocities.clear()
	for e in enemies:
		if dt>0 and previous.has(e.uid):velocities[e.uid]=(Vector2(e.position)-Vector2(previous[e.uid]))/dt
		retained[e.uid]=e.position
	previous=retained

func begin(game):
	if active:return
	active=true;elapsed=0;base_zoom=game.zoom
	game.radar_mode=false;game.camera_focus.clear()
	particle_speeds.clear()
	for node in game.particle_effects.get_children():
		if node is GPUParticles2D or node is CPUParticles2D:
			particle_speeds.append({"node":weakref(node),"speed":node.speed_scale});node.speed_scale*=.14

func reset(game):
	if active:game.zoom=base_zoom
	active=false;elapsed=0;previous.clear();velocities.clear()
	for item in particle_speeds:
		var node=item.node.get_ref()
		if is_instance_valid(node):node.speed_scale=item.speed
	particle_speeds.clear()

func advance(game,real_dt:float)->bool:
	elapsed+=maxf(0,real_dt)
	var progress=clampf(elapsed/DURATION,0,1)
	var dt=minf(real_dt,.1)*lerpf(.22,.055,progress)
	# Visual aftermath only: no new attacks, rewards, spawning or score changes.
	game.player.step(dt,Vector2.ZERO,false)
	game.player_legs.step(game.player,dt)
	for e in game.combat.enemies:
		var desired=Vector2(e.position)+Vector2(velocities.get(e.uid,Vector2.ZERO)).limit_length(700)*dt
		e.position=game.combat.terrain.move(e.position,desired,float(e.get("ground_radius",e.radius))) if game.combat.terrain!=null else desired
		e.feedback_left=maxf(0,float(e.get("feedback_left",0))-dt)
		Soft.step(e,dt)
	for b in game.combat.bullets:
		b.previous=b.position;b.position+=Vector2(b.velocity)*dt;b.life-=dt;b.age+=dt
	game.combat.bullets=game.combat.bullets.filter(func(b):return b.life>0)
	for effect in game.combat.effects:
		effect.life-=dt
		if effect.kind in ["viscous_contact","egg_burst"]:Motion.advance_contact(effect,dt)
	game.combat.effects=game.combat.effects.filter(func(e):return e.life>0)
	for burst in game.combat.death_splatters:burst.life-=dt
	game.combat.death_splatters=game.combat.death_splatters.filter(func(e):return e.life>0)
	game.test_time+=dt
	game.zoom=lerpf(base_zoom,base_zoom*1.045,smoothstep(0,1,progress))
	game.camera=game.camera.lerp(game.player.head,1-exp(-3*real_dt))
	game.sync_camera_layers();game.insect_layer.sync(game,dt);game.queue_redraw()
	if elapsed<DURATION:return false
	reset(game)
	return true

func paint(game):
	if not active:return
	var progress=clampf(elapsed/DURATION,0,1)
	var size:Vector2=game.get_viewport_rect().size
	game.draw_rect(Rect2(Vector2.ZERO,size),Color(.10,.015,.035,smoothstep(.35,1,progress)*.24))
	var edge=smoothstep(0,.8,progress)*24
	game.draw_rect(Rect2(0,0,size.x,edge),Color("080808"))
	game.draw_rect(Rect2(0,size.y-edge,size.x,edge),Color("080808"))
