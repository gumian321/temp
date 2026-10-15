extends RefCounted
## Constant node/material budget: six batched instanced quads, no per-frame resources.
const SHADER=preload("res://shaders/living_passive.gdshader")
const KEYS=["shield","armor","repair","chip","boost","cloak"]
const LIMITS=[32,96,48,48,48,96]
var nodes:Array=[]
var counts:Array=[0,0,0,0,0,0]
var material_count=0
var instance_count=0

func setup(owner:Node,textures:Dictionary):
 for mode in KEYS.size():
  var node=MultiMeshInstance2D.new()
  node.name="LivingPassive_"+KEYS[mode]
  node.z_index=2
  node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
  var mesh=QuadMesh.new();mesh.size=Vector2.ONE
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_2D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=LIMITS[mode];mm.visible_instance_count=0
  node.multimesh=mm
  var material=ShaderMaterial.new();material.shader=SHADER;material.set_shader_parameter("effect_mode",mode)
  if textures.has(KEYS[mode]):
   var texture:AtlasTexture=textures[KEYS[mode]]
   node.texture=texture.atlas
   var size=texture.atlas.get_size();var rect=texture.region
   material.set_shader_parameter("atlas_rect",Vector4(rect.position.x/size.x,rect.position.y/size.y,rect.size.x/size.x,rect.size.y/size.y))
  node.material=material;owner.add_child(node);nodes.append(node);material_count+=1

func begin(time:float):
 instance_count=0
 for i in nodes.size():
  counts[i]=0
  nodes[i].material.set_shader_parameter("sim_time",time)

func add(mode:int,at:Vector2,extent:Vector2,angle:float,state:Color,event:Color=Color(0,0,0,0))->bool:
 if mode>=nodes.size() or counts[mode]>=LIMITS[mode]:return false
 var index:int=counts[mode];counts[mode]+=1;instance_count+=1
 var mm:MultiMesh=nodes[mode].multimesh
 mm.set_instance_transform_2d(index,Transform2D(angle,extent,0.0,at))
 mm.set_instance_color(index,state);mm.set_instance_custom_data(index,event)
 return true

func finish():
 for i in nodes.size():nodes[i].multimesh.visible_instance_count=counts[i]

func hide():
 for node in nodes:node.multimesh.visible_instance_count=0

func set_viewport(size:Vector2):
 for node in nodes:node.material.set_shader_parameter("viewport_size",size)
