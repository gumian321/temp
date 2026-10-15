extends Node2D
var definitions:Dictionary
var textures:Dictionary={}
const PARTICLE_SHADER = preload('res://shaders/source_particle.gdshader')
var followers:Array=[]
var engines:Dictionary={}
var flames:Dictionary={}
var engine_definitions:Dictionary={}
func setup(db):
 definitions=db.read_json('particles');engine_definitions=db.read_json('engines')
 for effect_type in definitions:
  for data in definitions[effect_type]:
   data['_size_curve']=source_curve(data.size.get('curve',{}))
   data['_color_ramp']=source_gradient(data.color.get('gradient',{}).get('maxGradient',{}))
   data['_lifetime']=scalar_range(data.initial.startLifetime)
   data['_speed']=scalar_range(data.initial.startSpeed)
   data['_extent']=scalar_range(data.initial.startSize)
   data['_rotation']=scalar_range(data.initial.get('startRotation',{}))
   var bursts:Array=data.emission.get('m_Bursts',[])
   var rate=float(data.emission.rateOverTime.scalar);var count=0
   for burst in bursts:count+=int(burst.countCurve.scalar)
   data['_rate']=rate
   data['_amount']=maxi(1,mini(int(data.initial.get('maxNumParticles',1000)),maxi(count,ceili(rate*maxf(0.01,data._lifetime.y)))))
   data['_delay']=float(data.delay.get('scalar',0))+(float(bursts[0].time) if not bursts.is_empty() else 0)
   var color=rgba(data.initial.startColor.get('maxColor',{}))
   if int(data.get('shader_ref',{}).get('fileID',0))==202:color*=rgba(data.material.get('m_Colors',{}).get('_TintColor',{'r':.5,'g':.5,'b':.5,'a':.5}))*2
   var floats:Dictionary=data.material.get('m_Floats',{})
   var hdr=lerpf(1,float(floats.get('_HdrMultiply',1)),float(floats.get('_HdrBoost',0)))
   data['_color']=Color(color.r*hdr,color.g*hdr,color.b*hdr,color.a)
   # These curves depend only on the source preset, never on an individual
   # emission's radius, position, duration or target. Share the immutable resources.
   var lifetime=maxf(0.01,scalar_range(data.initial.startLifetime).y)
   var damping:Dictionary=data.get('clamp',{})
   var dampen=float(damping.get('dampen',0))
   if damping.get('enabled',false) and dampen>0 and dampen<1:
    var decay=-log(1-dampen)*60
    var decay_curve=Curve.new()
    for i in 65:decay_curve.add_point(Vector2(float(i)/64,exp(-decay*lifetime*float(i)/64)))
    data['_decay']=decay;data['_damping_curve']=decay_curve
   if data.velocity.get('enabled',false):
    var modifier:Dictionary=data.velocity.get('speedModifier',{})
    var modifier_curve=source_curve(modifier)
    data['_initial_modifier']=float(modifier.get('scalar',1))*(modifier_curve.sample(0) if int(modifier.get('minMaxState',0))==1 else 1)
    if int(modifier.get('minMaxState',0))==1:
     var acceleration_curve=Curve.new();acceleration_curve.min_value=-10;acceleration_curve.max_value=10
     for i in 65:
      var t=float(i)/64;var a=maxf(0,t-.002);var b=minf(1,t+.002)
      acceleration_curve.add_point(Vector2(t,(modifier_curve.sample(b)-modifier_curve.sample(a))/maxf(.0001,b-a)))
     data['_acceleration_curve']=acceleration_curve
   if data.rotation.get('enabled',false) and int(data.rotation.get('curve',{}).get('minMaxState',0))==1:
    data['_angular_velocity_curve']=source_curve(data.rotation.curve)
   if 'Procedural Glow' in data.get('shader',''):
    var glow=GradientTexture2D.new();glow.width=64;glow.height=64;glow.fill=GradientTexture2D.FILL_RADIAL;glow.fill_from=Vector2(0.5,0.5);glow.fill_to=Vector2(1,0.5)
    var gradient=Gradient.new();gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)]);glow.gradient=gradient
    data['_texture']=glow
   elif data.texture!='':
    if not textures.has(data.texture):textures[data.texture]=load(data.texture)
    data['_texture']=textures[data.texture]
   if data.uv.get('enabled',false) and int(data.uv.get('animationType',0))==1 and data.has('_texture'):
    var atlas=AtlasTexture.new();atlas.atlas=data._texture
    var rows=maxi(1,int(data.uv.tilesY));atlas.region=Rect2(0,float(data.uv.get('rowIndex',0))*atlas.atlas.get_height()/rows,atlas.atlas.get_width(),atlas.atlas.get_height()/rows)
    data['_texture']=atlas
   var additive=int(data.material.get('m_Floats',{}).get('_DstBlend',10))==1 or int(data.get('shader_ref',{}).get('fileID',0))==202
   data['_additive']=additive
   var material=ShaderMaterial.new();material.shader=PARTICLE_SHADER
   # Ability colors retain the source coverage mask, preventing black quads.
   material.set_shader_parameter('blue_ink',str(effect_type) not in ['302','307','308','flame'])
   material.set_shader_parameter('single_channel',float(data.material.get('m_Floats',{}).get('_SingleChannel',0))>0.5)
   material.set_shader_parameter('burst_flash',float(data.material.get('m_Floats',{}).get('_SingleChannel',0))>0.5 and int(data.get('renderer',{}).get('m_RenderMode',0))==4)
   material.set_shader_parameter('additive_source',additive)
   if data.uv.get('enabled',false):
    material.set_shader_parameter('frames',Vector2(maxi(1,int(data.uv.tilesX)),1 if int(data.uv.get('animationType',0))==1 else maxi(1,int(data.uv.tilesY))))
   data['_material']=material
   if int(data.get('renderer',{}).get('m_RenderMode',0))==1:
    material.set_shader_parameter('length_scale',float(data.renderer.get('m_LengthScale',1)));material.set_shader_parameter('velocity_scale',float(data.renderer.get('m_VelocityScale',0)))
    var speed=scalar_range(data.initial.startSpeed);var size=scalar_range(data.initial.startSize)
    material.set_shader_parameter('speed',(speed.x+speed.y)*.5);material.set_shader_parameter('size',(size.x+size.y)*.5);material.set_shader_parameter('lifetime',scalar_range(data.initial.startLifetime).y)
    var clamp_data:Dictionary=data.get('clamp',{})
    if clamp_data.get('enabled',false) and float(clamp_data.get('dampen',0))>0 and float(clamp_data.get('dampen',0))<1:material.set_shader_parameter('decay',-log(1-float(clamp_data.dampen))*60)
   if data.uv.get('enabled',false) and int(data.uv.get('frameOverTime',{}).get('minMaxState',0))==1:
    var frame_curve=source_curve(data.uv.frameOverTime);var speed_curve=Curve.new();speed_curve.min_value=-10;speed_curve.max_value=10
    for i in 101:
     var t=float(i)/100;var a=maxf(0,t-0.002);var b=minf(1,t+0.002)
     speed_curve.add_point(Vector2(t,(frame_curve.sample(b)-frame_curve.sample(a))/maxf(.0001,b-a)))
    data['_frame_speed']=speed_curve
func scalar_range(value:Dictionary)->Vector2:
 var maximum=float(value.get('scalar',0));return Vector2(float(value.get('minScalar',maximum)) if int(value.get('minMaxState',0))==3 else maximum,maximum)
func source_curve(value:Dictionary)->Curve:
 var curve=Curve.new();var points:Array=value.get('maxCurve',{}).get('m_Curve',[])
 if points.is_empty():curve.add_point(Vector2(0,1));curve.add_point(Vector2(1,1));return curve
 var values=points.map(func(p):return float(p.value));curve.min_value=minf(0,values.min());curve.max_value=maxf(1,values.max())
 for point in points:curve.add_point(Vector2(float(point.time),float(point.value)),float(point.get('inSlope',0)),float(point.get('outSlope',0)))
 return curve
func rgba(value:Dictionary)->Color:return Color(value.get('r',1),value.get('g',1),value.get('b',1),value.get('a',1))
func source_gradient(value:Dictionary)->Gradient:
 var gradient=Gradient.new();var colors=PackedColorArray();var offsets=PackedFloat32Array()
 var count=int(value.get('m_NumColorKeys',0));var alpha_count=int(value.get('m_NumAlphaKeys',0));var times:Array=[0.0,1.0]
 for i in count:times.append(float(value.get('ctime'+str(i),0))/65535)
 for i in alpha_count:times.append(float(value.get('atime'+str(i),0))/65535)
 times.sort();var last=-1.0
 for time in times:
  if time==last:continue
  last=time;var color=Color.WHITE
  for i in range(maxi(1,count-1)):
   var begin=float(value.get('ctime'+str(i),0))/65535;var end=float(value.get('ctime'+str(i+1),65535))/65535
   if time>=begin:color=rgba(value.get('key'+str(i),{})).lerp(rgba(value.get('key'+str(mini(i+1,count-1)),{})),clampf((time-begin)/maxf(0.001,end-begin),0,1))
  for i in range(maxi(1,alpha_count-1)):
   var begin=float(value.get('atime'+str(i),0))/65535;var end=float(value.get('atime'+str(i+1),65535))/65535
   if time>=begin:color.a=lerpf(float(value.get('key'+str(i),{}).get('a',1)),float(value.get('key'+str(mini(i+1,alpha_count-1)),{}).get('a',1)),clampf((time-begin)/maxf(0.001,end-begin),0,1))
  offsets.append(time);colors.append(color)
 gradient.offsets=offsets;gradient.colors=colors;return gradient
func play(type,at:Vector2,radius:float=1,duration:float=0,follow:Dictionary={},orientation:float=0.0,hold:bool=false)->Array:
 var created:Array=[]
 for data in definitions.get(str(type),[]):
  var initial:Dictionary=data.initial
  var lifetime:Vector2=data._lifetime;var speed:Vector2=data._speed;var extent:Vector2=data._extent
  var particles=CPUParticles2D.new();particles.emitting=false;particles.local_coords=bool(data.get("local_space",true));particles.one_shot=true;particles.lifetime=maxf(0.01,lifetime.y);particles.lifetime_randomness=clampf(1-lifetime.x/maxf(0.01,lifetime.y),0,1);particles.position=at;particles.rotation=orientation+float(data.get("angle",0))
  var rate=float(data._rate)
  var active_duration=maxf(float(data.duration),duration)
  particles.amount=int(data._amount);particles.explosiveness=1.0 if rate<=0 else 0.0
  particles.one_shot=rate<=0
  particles.direction=Vector2.RIGHT;particles.spread=180;particles.gravity=Vector2(0,9.81*float(initial.get('gravityModifier',{}).get('scalar',0))*48)
  particles.initial_velocity_min=speed.x*48*radius;particles.initial_velocity_max=speed.y*48*radius
  var clamp_data:Dictionary=data.get('clamp',{})
  if clamp_data.get('enabled',false) and float(clamp_data.get('dampen',0))>=1:
   var limit=float(clamp_data.get('magnitude',{}).get('scalar',0))*48*radius
   particles.initial_velocity_min=clampf(particles.initial_velocity_min,-limit,limit);particles.initial_velocity_max=clampf(particles.initial_velocity_max,-limit,limit)
  if clamp_data.get('enabled',false) and float(clamp_data.get('dampen',0))>0 and float(clamp_data.get('dampen',0))<1:
   var limit=float(clamp_data.get('magnitude',{}).get('scalar',0))*48*radius
   var decay=float(data._decay)
   particles.damping_curve=data._damping_curve
   particles.damping_min=maxf(0,particles.initial_velocity_min-limit)*decay
   particles.damping_max=maxf(0,particles.initial_velocity_max-limit)*decay
  if data.velocity.get('enabled',false):
   var radial=float(data.velocity.get('radial',{}).get('scalar',0))*48*radius
   var modifier:Dictionary=data.velocity.get('speedModifier',{})
   var initial_modifier=float(data._initial_modifier)
   var total_min=particles.initial_velocity_min+radial;var total_max=particles.initial_velocity_max+radial
   particles.initial_velocity_min=total_min*initial_modifier;particles.initial_velocity_max=total_max*initial_modifier
   if int(modifier.get('minMaxState',0))==1:
    particles.radial_accel_min=minf(total_min,total_max)/particles.lifetime
    particles.radial_accel_max=maxf(total_min,total_max)/particles.lifetime;particles.radial_accel_curve=data._acceleration_curve
  var rotation:Vector2=data._rotation;particles.angle_min=rad_to_deg(rotation.x);particles.angle_max=rad_to_deg(rotation.y)
  var tex_size=1.0
  if data.has('_texture'):
   particles.texture=data._texture;tex_size=particles.texture.get_width()/maxi(1,int(data.uv.get('tilesX',1)))
  var shape:Dictionary=data.shape
  if shape.get('enabled',false):
   var shape_type=int(shape.type);var shape_radius=float(shape.radius.value)*48*radius
   particles.emission_sphere_radius=shape_radius
   if shape_type==4:
    particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles.emission_rect_extents=Vector2(float(shape.m_Scale.x),float(shape.m_Scale.y))*24*radius
   else:
    particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE if float(shape.get('radiusThickness',1))==0 else CPUParticles2D.EMISSION_SHAPE_SPHERE
   if shape_type in [2,12]:particles.spread=float(shape.angle);particles.direction=Vector2.UP
   particles.position+=Vector2(float(shape.m_Position.x),-float(shape.m_Position.y))*48*radius
  if data.rotation.get('enabled',false):
   var angular=scalar_range(data.rotation.get('curve',{}));particles.angular_velocity_min=rad_to_deg(angular.x);particles.angular_velocity_max=rad_to_deg(angular.y)
   if int(data.rotation.get('curve',{}).get('minMaxState',0))==1:particles.angular_velocity_curve=data._angular_velocity_curve
  particles.scale_amount_min=extent.x*48*radius/maxf(1,tex_size);particles.scale_amount_max=extent.y*48*radius/maxf(1,tex_size)
  if data.size.get('enabled',false):particles.scale_amount_curve=data._size_curve
  particles.color=data._color
  if data.color.get('enabled',false):particles.color_ramp=data._color_ramp
  if data.uv.get('enabled',false):
   var frame:Dictionary=data.uv.get('frameOverTime',{});var state=int(frame.get('minMaxState',0))
   particles.anim_speed_min=float(frame.get('scalar',1))/particles.lifetime if state==1 else 0.0;particles.anim_speed_max=particles.anim_speed_min
   if data.has('_frame_speed'):particles.anim_speed_curve=data._frame_speed
   var start=scalar_range(data.uv.get('startFrame',{}));particles.anim_offset_min=start.x;particles.anim_offset_max=start.y
   if state in [0,3]:
    var offset=scalar_range(frame);particles.anim_offset_min+=offset.x;particles.anim_offset_max+=offset.y
  particles.material=data._material
  particles.particle_flag_align_y=int(data.get('renderer',{}).get('m_RenderMode',0))==1
  add_child(particles);created.append(particles)
  if not follow.is_empty():followers.append({"node":weakref(particles),"target":follow})
  if hold:particles.one_shot=false;particles.emitting=false;continue
  var delay=float(data._delay)
  var tween=particles.create_tween();tween.tween_interval(maxf(0.001,delay));tween.tween_callback(func():particles.emitting=true)
  if rate>0:tween.tween_interval(active_duration);tween.tween_callback(func():particles.emitting=false)
  tween.tween_interval(particles.lifetime+0.25);tween.tween_callback(particles.queue_free)
 return created
func _process(_dt):
 # Most frames have no followers. Compact in place instead of allocating a
 # filtered Array and invoking a lambda for every entry on every frame.
 var live_count=0
 for entry in followers:
  var node=entry.node.get_ref()
  if node==null:continue
  node.position=entry.target.position
  followers[live_count]=entry;live_count+=1
 if live_count<followers.size():followers.resize(live_count)
func clear():
 followers.clear();engines.clear();flames.clear()
 for child in get_children():child.queue_free()

func sync_engines(requests:Array,dt:float):
 var alive={}
 for request in requests:
  var key:String=request.key;alive[key]=true
  var effect=str(request.get('effect','505'))
  if not engines.has(key):engines[key]={'nodes':play(effect,request.position,1,0,{},request.angle,true),'size':0.25}
  var entry:Dictionary=engines[key]
  entry.size=move_toward(float(entry.size),0.6 if request.boost else 0.25,dt*(0.6-0.25)/0.25)
  for i in entry.nodes.size():
   var node:CPUParticles2D=entry.nodes[i];var data:Dictionary=definitions[effect][i]
   node.position=request.position;node.rotation=request.angle+float(data.get('angle',0));node.emitting=request.active
   var pixel_size=maxf(1,node.texture.get_width()) if node.texture!=null else 1.0
   # Engine.SetEngineBoostState modifies the referenced primary ParticleSystem only.
   if i==0:node.scale_amount_min=float(entry.size)*48/pixel_size;node.scale_amount_max=node.scale_amount_min
 for key in engines.keys():
  if alive.has(key):continue
  for node in engines[key].nodes:node.queue_free()
  engines.erase(key)

func sync_flames(effects:Array):
 var active={}
 for effect in effects:
  if effect.kind=='flame':active[str(effect.get('owner',''))]=effect
 for key in active:
  var effect:Dictionary=active[key]
  if not flames.has(key):flames[key]=play('flame',effect.position,1,0,{},0,true)
  for i in flames[key].size():
   var node:CPUParticles2D=flames[key][i];var data:Dictionary=definitions.flame[i]
   node.position=effect.position;node.rotation=Vector2(effect.end-effect.position).angle()+PI/2+float(data.get('angle',0));node.emitting=true
 for key in flames.keys():
  if active.has(key):continue
  for node in flames[key]:node.queue_free()
  flames.erase(key)
