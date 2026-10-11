extends Node3D
## Small, bounded, seat-local prop theatre. No actor skeleton, microphone or speech model.
const Rules = preload("res://game/rules.gd")
var vent: Node3D
var lever: Node3D
var glove: Node3D
var tissue: Node3D
var bag: Node3D
var recorder: Node3D
var led: MeshInstance3D
var reels: Array[Node3D] = []
var cloud_positions:Array[Vector3]=[]
var clouds: MultiMeshInstance3D
var caption: Label3D
var synth: AudioStreamPlayer
var clips := {}
var played := {}
var last_epoch := -1
var time := 0.0
var font = preload("res://assets/fonts/chinese.otf")
const DRIVER := Vector3(.32, 1.0, .39)
const COACH := Vector3(-.32, 1.0, .39)

func _ready() -> void:
 vent = Node3D.new(); add_child(vent)
 box(vent, Vector3.ZERO, Vector3(.19,.09,.07), Color("768b8d"))
 for x in range(5): box(vent, Vector3((x-2)*.027,0,-.04), Vector3(.009,.07,.014), Color("263b3e"))
 lever = Node3D.new(); vent.add_child(lever)
 box(lever, Vector3(0,0,-.065), Vector3(.07,.024,.025), Color("f1b549"))
 vent.position = Vector3(0,.97,.58)
 glove = Node3D.new(); add_child(glove)
 sphere(glove, Vector3.ZERO, .047, Color("eee8ca"))
 for i in range(3): sphere(glove, Vector3((i-1)*.025,.024,.023), .021, Color("eee8ca"))
 box(glove, Vector3(0,-.044,0), Vector3(.07,.04,.065), Color("d27646"))
 tissue = Node3D.new(); add_child(tissue)
 for i in range(3):
  var sheet := box(tissue, Vector3((i-1)*.028,0,0), Vector3(.075,.018,.14), Color("f5f0d6"))
  sheet.rotation_degrees = Vector3(i*9, i*17, i*13)
 var slime := CylinderMesh.new()
 slime.top_radius = .006; slime.bottom_radius = .009; slime.height = .16; slime.radial_segments = 8
 mesh(tissue, slime, Vector3(.02,-.06,.02), mat(Color("a5c452")))
 sphere(tissue, Vector3(.02,-.145,.02), .015, Color("b4ce58"))
 bag = Node3D.new(); add_child(bag)
 var sack := CylinderMesh.new()
 sack.top_radius = .115; sack.bottom_radius = .07; sack.height = .19; sack.radial_segments = 12
 mesh(bag, sack, Vector3.ZERO, mat(Color("344b53")))
 var opening := CylinderMesh.new()
 opening.top_radius = .105; opening.bottom_radius = .105; opening.height = .004; opening.radial_segments = 12
 mesh(bag, opening, Vector3(0,.097,0), mat(Color("102426")))
 label(bag, "垃圾\n专用", Vector3(0,0,-.105), 28, .0012)
 recorder = Node3D.new(); add_child(recorder)
 box(recorder, Vector3.ZERO, Vector3(.25,.16,.085), Color("e9ad48"))
 box(recorder, Vector3(0,-.002,-.047), Vector3(.2,.095,.012), Color("35494c"))
 for side in [-1,1]:
  var reel := Node3D.new(); recorder.add_child(reel); reels.append(reel)
  reel.position = Vector3(side*.055,.006,-.057)
  var disc := CylinderMesh.new(); disc.top_radius=.029; disc.bottom_radius=.029; disc.height=.01; disc.radial_segments=16
  var disk := mesh(reel,disc,Vector3.ZERO,mat(Color("d9e4d5")));disk.rotation.x=PI/2
  box(reel,Vector3(0,0,-.008),Vector3(.008,.05,.01),Color("59615b"))
 led=sphere(recorder,Vector3(-.087,.059,-.055),.012,Color("ff3939"))
 var light_mat := led.material_override as StandardMaterial3D
 light_mat.emission_enabled=true;light_mat.emission=Color("ff2525");light_mat.emission_energy_multiplier=.6
 label(recorder,"胡闹牌",Vector3(.025,.058,-.055),20,.0009)
 for i in range(3):box(recorder,Vector3((i-1)*.05,.084,0),Vector3(.032,.018,.033),Color("684b3c"))
 var cloud_mesh := SphereMesh.new();cloud_mesh.radius=.045;cloud_mesh.height=.09;cloud_mesh.radial_segments=8;cloud_mesh.rings=4
 var multi := MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=cloud_mesh;multi.instance_count=10
 cloud_positions.resize(10)
 clouds=MultiMeshInstance3D.new();clouds.multimesh=multi
 var cloud_mat := mat(Color(.49,.72,.24,.43));cloud_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 cloud_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;cloud_mat.no_depth_test=false
 clouds.material_override=cloud_mat;clouds.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(clouds)
 caption=label(self,"",Vector3(0,1.045,.58),32,.0011)
 caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 caption.no_depth_test=false
 synth=AudioStreamPlayer.new();synth.volume_db=-10;add_child(synth)
 for kind in range(3,6):
  for phase_name in ["windup","hit","counter","repair"]:
   clips[str(kind)+phase_name]=make_clip(kind,phase_name)
 _hide()

func mat(color: Color) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.75;return m
func mesh(parent: Node3D, shape: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
 var n:=MeshInstance3D.new();n.mesh=shape;n.material_override=material;n.position=pos
 n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(n);return n
func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
 var b:=BoxMesh.new();b.size=size;return mesh(parent,b,pos,mat(color))
func sphere(parent: Node3D,pos: Vector3,radius: float,color: Color) -> MeshInstance3D:
 var ball:=SphereMesh.new();ball.radius=radius;ball.height=radius*2;ball.radial_segments=12;ball.rings=6
 return mesh(parent,ball,pos,mat(color))
func label(parent: Node3D,text: String,pos: Vector3,size: int,pixel: float) -> Label3D:
 var l:=Label3D.new();l.text=text;l.position=pos;l.rotation.y=PI;l.font=font;l.font_size=size;l.pixel_size=pixel
 l.modulate=Color("fff0c4");l.outline_size=5;l.outline_modulate=Color("233d40");parent.add_child(l);return l
func _hide() -> void:
 for node in [vent,glove,tissue,bag,recorder,clouds,caption]:node.visible=false

func update_effects(s: Dictionary, dt: float) -> void:
 time += dt
 if last_epoch != int(s.epoch):
  played.clear();synth.stop();last_epoch=s.epoch
 _hide()
 if s.phase != "playing" and s.phase != "ended":return
 var kind:=int(s.act_kind)
 var phase_name:=String(s.act_phase)
 var target:=String(s.act_target)
 if phase_name=="idle" or kind<3:
  kind=-1
  for i in [3,5,4]:
   if s.effects[i]>0:kind=i;target="coach"
   if s.backlash[i]>0:kind=i;target="driver"
  if kind<3:return
  phase_name="lingering"
 var progress:=clampf(1.0-float(s.act_left)/maxf(.01,float(s.act_duration)),0,1)
 var destination:=DRIVER if target=="driver" else COACH
 var windup:=phase_name=="windup"
 var bounced:=phase_name=="counter"
 var key:="%s:%s" % [s.epoch,s.act_serial]
 if phase_name!="lingering" and not played.has(key):
  played[key]=true
  if played.size()>64:played.erase(played.keys()[0])
  synth.stream=clips.get(str(kind)+phase_name)
  if synth.stream:synth.play()
 caption.visible=true
 caption.position=Vector3(0,1.055,.63)
 if windup:caption.text=["咕噜…悄悄拨风口","噗——教练，纸给您！","滴、滴！胡闹牌试音中"][kind-3]
 elif bounced:caption.text=["风口还你！\n学员：真不是我…","垃圾袋接住，原路奉还！","倒带中：我错了！我错了！"][kind-3]
 elif phase_name=="repair":caption.text="擦干净…假装什么都没发生。"
 else:caption.text=["学员：这味儿肯定是车的问题！","学员：我这不是献殷勤嘛…","教练别紧张！这车比我还稳！"][kind-3]
 if kind==3:
  vent.visible=true;glove.visible=windup or bounced
  glove.position=DRIVER.lerp(Vector3(0,.97,.51),minf(1,progress*2)) if windup else COACH.lerp(Vector3(0,.97,.51),minf(1,progress*3))
  lever.rotation.z=(1 if bounced else -1)*progress*.8
  clouds.visible=not windup or progress>.62
  var start:=Vector3(0,.96,.43)
  var endpoint:=DRIVER if bounced or target=="driver" else COACH
  for i in range(10):
   var flow:=fmod(time*.45+i*.1,1.0)
   var pos:=start.lerp(endpoint,flow)+Vector3(0,sin(time*3+i)*.025,cos(time*2+i)*.018)
   # All puffs stay at seat/chest height, behind dashboard and below road sightline.
   pos.y=clampf(pos.y,.91,1.055);pos.z=clampf(pos.z,.32,.49)
   cloud_positions[i]=pos
   var scale_factor:=.5+sin(flow*PI)*.8
   clouds.multimesh.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ONE*scale_factor),pos))
 elif kind==4:
  tissue.visible=true;glove.visible=windup or bounced
  if windup:
   tissue.position=DRIVER.lerp(COACH,progress*.8)+Vector3(0,sin(progress*PI)*.055,0)
  elif bounced:
   tissue.position=COACH.lerp(DRIVER,clampf((progress-.2)*2,0,1))+Vector3(0,sin(progress*PI)*.08,0)
  else:tissue.position=destination+Vector3(0,-.045,0)
  tissue.rotation=Vector3(.15,sin(time*3)*.1, sin(time*6)*.08 if windup else .2)
  glove.position=tissue.position+Vector3(.025,-.06,0)
  bag.visible=bounced or phase_name=="repair"
  bag.position=COACH+Vector3(0,-.06,-.035)
  bag.rotation.z=sin(progress*PI)*.25
 elif kind==5:
  recorder.visible=true;glove.visible=windup or bounced
  recorder.position=DRIVER.lerp(COACH,progress*.8) if windup else destination
  recorder.rotation.z=sin(time*(18 if bounced else 7))*.06
  glove.position=recorder.position+Vector3(0,-.09,0)
  led.visible=fmod(time*(8 if windup else 3),1)<.55
  for reel in reels:reel.rotation.z=time*(-18 if bounced else 9)
  if not windup and not bounced:
   var lines:=[["教练别紧张！","这车比我还稳！","我只是脚有自己的想法。"],["报告教练！","我开得很有礼貌！","就是路不太配合。"],["莫慌，问题不大！","车有四个轮子。","总有一个认识路！"]]
   caption.text=lines[int(s.act_variant)][int(float(s.tick)/60.0*1.5)%3]
 if phase_name=="repair":
  tissue.scale=Vector3.ONE*maxf(.01,1-progress)
 else:tissue.scale=Vector3.ONE

static func make_clip(kind: int, phase_name: String) -> AudioStreamWAV:
 var rate:=22050
 var length:=.85 if phase_name!="repair" else .3
 var bytes:=PackedByteArray();bytes.resize(int(rate*length)*2)
 var rng:=RandomNumberGenerator.new();rng.seed=kind*971+phase_name.length()
 var filtered:=0.0
 for i in range(bytes.size()/2):
  var t:=float(i)/rate
  filtered=lerpf(filtered,rng.randf_range(-1,1),.15)
  var sample:=0.0
  if kind==3:
   sample=sin(TAU*(65*t+3*sin(t*18)))*(.5+.5*sin(t*41))* .5+filtered*.35
  elif kind==4:
   sample=filtered*(.35+.65*absf(sin(t*21)))+sin(t*TAU*(260-140*t))*.15
  else:
   var pitch:=330+int(t*10)%4*110
   sample=sin(TAU*pitch*t)*(.5 if fmod(t,.16)<.1 else .05)
  if phase_name=="counter":sample+=sin(TAU*(900*t-380*t*t))*.3
  var envelope:=minf(1,t/.015)*minf(1,(length-t)/.07)
  var value:=int(clampf(sample*envelope,-1,1)*15000)
  bytes[i*2]=value&255;bytes[i*2+1]=(value>>8)&255
 if kind==5 and phase_name=="counter":
  var count:=bytes.size()/2
  for i in range(count/2):
   var opposite:=(count-1-i)*2
   for channel in range(2):
    var saved:=bytes[i*2+channel]
    bytes[i*2+channel]=bytes[opposite+channel]
    bytes[opposite+channel]=saved
 var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=bytes
 return stream
