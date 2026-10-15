extends RefCounted
## Real displacement, integrated on the combat clock; never a render-only tween.
const MAX_SPEED = 520.0
const FORCE_TO_SPEED = 96.0
const DRAG = 5.5
const STOP_SPEED = 2.0
const MAX_STEP = 0.1

static func movable(actor: Dictionary) -> bool:
	return float(actor.get("hp",0))>0 and float(actor.get("warp",0))<=0 and not actor.get("despawn",false) and int(actor.get("parent",0))==0 and not actor.get("mission_controlled",false) and str(actor.get("kind","")) in ["AISwarmingUnit","AIFollowingUnit","AIPatrolUnit","TraderUnit"]

static func add_impulse(state: Dictionary, direction: Vector2, force: float):
	if force<=0 or direction.is_zero_approx() or float(state.get("hp",0))<=0:return
	var velocity=Vector2(state.get("knockback_velocity",Vector2.ZERO))
	state.knockback_velocity=(velocity+direction.normalized()*minf(force*FORCE_TO_SPEED,MAX_SPEED)).limit_length(MAX_SPEED)

static func take_displacement(state: Dictionary, dt: float) -> Vector2:
	if not state.has("knockback_velocity"):return Vector2.ZERO
	if float(state.get("hp",0))<=0:
		state.erase("knockback_velocity")
		return Vector2.ZERO
	var velocity=Vector2(state.knockback_velocity)
	var speed=velocity.length()
	if speed<=STOP_SPEED:
		state.erase("knockback_velocity")
		return Vector2.ZERO
	if dt<=0:return Vector2.ZERO
	# Integrate drag analytically for identical travel at 30/60/120 Hz. Bounded
	# catch-up prevents a stalled frame from replaying the whole push at once.
	var until_stop=log(speed/STOP_SPEED)/DRAG
	var step=minf(clampf(dt,0,MAX_STEP),until_stop)
	var decay=exp(-DRAG*step)
	var displacement=velocity*((1.0-decay)/DRAG)
	if step>=until_stop:state.erase("knockback_velocity")
	else:state.knockback_velocity=velocity*decay
	return displacement

static func drive_factor(actor: Dictionary) -> float:
	# Recover the insect's own stride gradually as the shove loses momentum.
	var speed=Vector2(actor.get("knockback_velocity",Vector2.ZERO)).length()
	return 1.0-0.8*smoothstep(25.0,160.0,speed)
