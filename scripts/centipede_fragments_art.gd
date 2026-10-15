extends Node2D
## Grounded, recoverable creatures, never pickup icons. This renderer only reads
## detached snapshots: no combat emitters, collision bodies or simulation writes.
const Art = preload("res://scripts/centipede_art.gd")
const SoftOrgans = preload("res://scripts/soft_organ_art.gd")
const STAGES = 12
const MAX_VISIBLE_PARTS = 60
const PIGMENT_SHADER = """
shader_type canvas_item;
render_mode unshaded;
uniform float activation = 0.0;
uniform float clock = 0.0;
varying vec2 tissue_position;
void vertex(){tissue_position=VERTEX;}
void fragment(){
 vec4 source=COLOR;
 float grey=dot(source.rgb,vec3(0.24,0.58,0.18));
 vec3 resting=mix(source.rgb,vec3(grey)*vec3(0.78,0.86,0.95),0.60)*0.77;
 vec2 p=tissue_position;
 float vessel=1.0-smoothstep(0.10,0.48,abs(sin(p.y*0.28+sin(p.x*0.18)*1.8-clock*4.6)));
 float wave=0.5+0.5*sin(p.x*0.13-clock*6.0+sin(p.y*0.2));
 float pulse=sin(activation*3.14159265)*0.72+activation*0.13;
 vec3 awake=mix(resting,source.rgb,smoothstep(0.0,0.74,activation));
 // Moist gold-green nerves brighten within the original alpha silhouette only.
 vec3 sap=vec3(0.70,0.94,0.67);
 awake=mix(awake,sap,(0.12+vessel*0.55)*pulse*(0.40+wave*0.60));
 COLOR=vec4(awake,source.a*mix(0.88,1.0,activation));
}
"""
const GLOW_SHADER = """
shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
void fragment(){
 vec2 p=UV*2.0-1.0;
 float angle=atan(p.y,p.x);
 float ripple=0.05*sin(angle*5.0-clock*3.0)+0.035*sin(angle*9.0+clock*2.1);
 float radius=length(p*vec2(0.93,1.08));
 float haze=exp(-radius*radius*4.7)*(1.0-smoothstep(0.57+ripple,1.0,radius));
 COLOR=vec4(COLOR.rgb,COLOR.a*haze);
}
"""

class BodyBatch extends Node2D:
	var entries: Array = []
	var organs
	func _draw():
		for entry in entries:
			if entry.tail: Art.tail(self,entry.at,entry.angle,entry.zoom)
			Art.segment(self,entry.at,entry.angle,entry.zoom,entry.phase,false,false,false,0.0,entry.clock,entry.legs)
			if entry.fused:
				Art.Flagella.paint(self,entry.feelers,entry.at,entry.angle,entry.zoom,true)
			organs.paint(self,entry.key,entry.texture,entry.at,Vector2.ONE*56.0*entry.zoom,entry.organ_angle,entry.family,entry.clock,entry.pulse,Color.WHITE,entry.seed,entry.activation)

class GroundBatch extends Node2D:
	var entries: Array = []
	static func connector_profile(gap:float)->Dictionary:
		var stretch=smoothstep(62.0,100.0,gap)
		return {"width":lerpf(19.0,2.4,stretch),"alpha":lerpf(1.0,0.28,stretch),"bend":minf(12.0,maxf(0.0,gap-58.0)*0.18),"stretch":stretch}
	func draw_connector(entry:Dictionary):
		var delta: Vector2 = entry.previous-entry.at
		var profile=connector_profile(delta.length()/maxf(0.01,entry.zoom))
		var tint=Color("456079").lerp(Color("61a69a"),entry.activation)
		tint.a=profile.alpha
		if profile.stretch<=0.0:
			draw_line(entry.at,entry.previous,tint,profile.width*entry.zoom,true)
			return
		# A stretched joining membrane narrows and bows, instead of becoming a
		# rigid full-width bar while independently waking segments converge.
		var normal=delta.orthogonal().normalized()
		var previous: Vector2 = entry.at
		for step in range(1,13):
			var t=float(step)/12.0
			var next: Vector2 = entry.at+delta*t+normal*sin(t*PI)*profile.bend*entry.zoom
			var taper=1.0-sin((t-1.0/24.0)*PI)*0.42*profile.stretch
			draw_line(previous,next,tint,profile.width*taper*entry.zoom,true)
			previous=next
	func _draw():
		for entry in entries:
			draw_set_transform(entry.at+Vector2(0,4)*entry.zoom,entry.angle,Vector2(1.0,0.67))
			draw_circle(Vector2.ZERO,32*entry.zoom,Color(0.06,0.14,0.24,0.11),true,-1,true)
			draw_set_transform(Vector2.ZERO)
			if entry.has("previous"):
				draw_connector(entry)

class GlowBatch extends Node2D:
	var entries: Array = []
	func _draw():
		for entry in entries:
			if entry.activation<=0.0: continue
			var strength=sin(entry.activation*PI)*0.27+entry.activation*0.045
			draw_set_transform(entry.at,entry.angle)
			draw_rect(Rect2(-Vector2(49,55)*entry.zoom,Vector2(98,110)*entry.zoom),Color(0.40,0.82,0.65,strength))
		draw_set_transform(Vector2.ZERO)

var organs = SoftOrgans.new()
var batches: Array = []
var ground: GroundBatch
var glow: GlowBatch
var source
var visible_parts: int = 0
var materials: Array = []
var active_snapshots: Dictionary = {}
var frozen_snapshots: Dictionary = {}
var player_identity: int = 0
var reset_serial: int = -1
var was_rendering: bool = false

func attach(game):
	if source!=null: return
	source=game
	name="DormantCentipedeFragments"
	# Below the live creature and enemies, above the separate paper ground layer.
	z_index=-2
	game.add_child(self)
	ground=GroundBatch.new();add_child(ground)
	glow=GlowBatch.new()
	var glow_shader=Shader.new();glow_shader.code=GLOW_SHADER
	var glow_material=ShaderMaterial.new();glow_material.shader=glow_shader
	glow.material=glow_material;add_child(glow)
	var pigment=Shader.new();pigment.code=PIGMENT_SHADER
	for stage in range(STAGES+1):
		var batch=BodyBatch.new();batch.organs=organs
		var material=ShaderMaterial.new();material.shader=pigment
		material.set_shader_parameter("activation",float(stage)/STAGES)
		batch.material=material;materials.append(material);batches.append(batch);add_child(batch)

static func activation_for(fragment:Dictionary,pose:Dictionary,index:int)->float:
	if fragment.get("state","dormant")!="waking": return 0.0
	if pose.has("activation"): return clampf(float(pose.activation),0.0,1.0)
	return smoothstep(0.0,0.55,maxf(0.0,float(fragment.get("wake_age",0.0))-index*0.085))

static func leg_pose(frozen:Array,seed:float,wake_clock:float,activation:float)->Array:
	var resting: Array = Art.Legs.resting(seed) if frozen.is_empty() else frozen
	if activation<=0.0: return resting
	var moving: Array = Art.Legs.resting(seed+wake_clock*8.5)
	var result: Array = []
	var flex=smoothstep(0.08,0.72,activation)
	for i in resting.size():
		var old: Dictionary = resting[i]
		var target: Dictionary = moving[i%moving.size()]
		var root: Vector2 = old.root
		result.append(Art.Legs.solve(root,Vector2(old.foot).lerp(target.foot,flex),int(old.side)))
	return result

static func feeler_pose(frozen:Array,count:int,clock:float,activation:float)->Array:
	if activation<=0.0 and frozen.size()==count: return frozen
	var result: Array = []
	for n in count:
		var natural: PackedVector2Array = Art.Flagella.natural_pose(n,false,clock)
		if n<frozen.size():
			var old: PackedVector2Array = frozen[n]
			for i in mini(old.size(),natural.size()): natural[i]=old[i].lerp(natural[i],smoothstep(0.0,0.8,activation))
		result.append(natural)
	return result

func paint(game):
	if source==null: attach(game)
	var identity=game.player.get_instance_id() if game.player!=null else 0
	var serial=int(game.player.character_reset_serial) if game.player!=null else -1
	if identity!=player_identity or serial!=reset_serial:
		active_snapshots.clear();frozen_snapshots.clear()
		organs.meshes.clear();organs.surfaces.clear();organs.used.clear()
		player_identity=identity;reset_serial=serial
	var retained_snapshots: Dictionary = {}
	organs.begin_frame()
	visible_parts=0
	ground.entries.clear();glow.entries.clear()
	for batch in batches: batch.entries.clear()
	var enabled=game.player!=null and game.screen in ["game","pause","result","rewards"] and not game.radar_mode
	if game.player!=null:
		var fragments=game.player.get("detached_fragments")
		if fragments is Array:
			var viewport: Rect2 = game.get_viewport_rect().grow(100)
			for fragment in fragments:
				var parts: Array = fragment.get("parts",[])
				var poses: Array = fragment.get("poses",[])
				for index in range(mini(parts.size(),poses.size())-1,-1,-1):
					if visible_parts>=MAX_VISIBLE_PARTS: break
					var part: Dictionary = parts[index]
					var pose: Dictionary = poses[index]
					var uid=int(part.get("feedback_uid",index+1))
					var key="fragment:%s:%s"%[fragment.get("uid",0),uid]
					if not frozen_snapshots.has(key):
						var initial: Dictionary = active_snapshots.get(uid,{"legs":pose.get("legs",[]),"clock":fragment.get("visual_clock",0.0),"feelers":[]})
						if initial.legs.is_empty(): initial.legs=Art.Legs.resting(-float(uid)*0.8)
						if initial.feelers.is_empty() and int(part.get("fusion_level",1))>1:
							initial.feelers=feeler_pose([],int(part.fusion_level),float(initial.clock),0.0)
						frozen_snapshots[key]=initial
					retained_snapshots[key]=frozen_snapshots[key]
					var at: Vector2 = game.world(Vector2(pose.point))
					if not enabled or not viewport.has_point(at): continue
					var activation=activation_for(fragment,pose,index)
					var wake_clock=maxf(0.0,float(fragment.get("wake_age",0.0))-index*0.085) if activation>0.0 else 0.0
					var seed=float(uid)
					var snapshot: Dictionary = frozen_snapshots[key]
					var frozen_clock=float(snapshot.clock)
					var clock=frozen_clock+wake_clock*smoothstep(0.12,0.9,activation)
					var angle=Vector2(pose.direction).angle()
					var core: Dictionary = game.db.asset(part.id)
					var level=int(part.get("fusion_level",1))
					var entry={
						"key":key,"at":at,"angle":angle,"zoom":game.zoom,"tail":index==parts.size()-1,
						"seed":seed,"phase":-seed*0.8,"clock":clock,"activation":activation,
						"pulse":maxf(0.0,0.16-wake_clock)*activation,
						"legs":leg_pose(snapshot.legs,-seed*0.8,wake_clock,activation),
						"texture":game.db.core_sprite(core),"family":game.db.Armaments.variant(game.db,core),
						"organ_angle":float(part.get("angle",angle))+PI*0.5+angle-float(part.get("body_angle",angle)),
						"fused":level>1,"feelers":feeler_pose(snapshot.feelers,level,clock,activation) if level>1 else []
					}
					if index>0: entry.previous=game.world(Vector2(poses[index-1].point))
					ground.entries.append(entry);glow.entries.append(entry)
					batches[clampi(roundi(activation*STAGES),0,STAGES)].entries.append(entry)
					visible_parts+=1
	frozen_snapshots=retained_snapshots
	active_snapshots.clear()
	if enabled:
		for part in game.player.parts.slice(1):
			active_snapshots[int(part.feedback_uid)]={"legs":game.player_legs.poses(int(part.segment)).duplicate(true),"clock":game.test_time,"feelers":game.player.flagella.poses(int(part.feedback_uid)).duplicate(true)}
	visible=visible_parts>0
	# Most frames have no salvage. After clearing once, keep the 15 retained
	# CanvasItems asleep and avoid 14 redundant material uniform updates.
	if visible_parts==0 and not was_rendering: return
	was_rendering=visible_parts>0
	if visible_parts>0:
		var clock=float(game.player.motion.elapsed) if game.player!=null else 0.0
		for material in materials: material.set_shader_parameter("clock",clock)
		glow.material.set_shader_parameter("clock",clock)
	ground.queue_redraw();glow.queue_redraw()
	# One mesh per visible original module, shared across material stages. Hidden
	# CanvasItems do not draw, so release their cached surfaces explicitly.
	if visible_parts==0:
		organs.meshes.clear();organs.surfaces.clear();organs.used.clear()
	for batch in batches: batch.queue_redraw()

func stats()->Dictionary:
	var meshes=organs.meshes.size()
	return {"materials":materials.size()+1,"batches":batches.size()+2,"visible_parts":visible_parts,"meshes":meshes,"max_visible_parts":MAX_VISIBLE_PARTS,"frozen_snapshots":frozen_snapshots.size(),"active_snapshots":active_snapshots.size()}
