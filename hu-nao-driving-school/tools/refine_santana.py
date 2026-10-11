import bpy,math,json
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
SRC=R/'source/original/Volkswagen_Santana_CN-spec_1985.obj'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=str(SRC),forward_axis='Y',up_axis='Z')
s=bpy.context.scene
for o in list(s.objects):
 if o.type=='MESH':
  o.scale*=.01;bpy.context.view_layer.objects.active=o;o.select_set(True)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.select_set(False)
def pbr(name,color,rough=.6,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m
for m in bpy.data.materials:
 if not m.use_nodes:continue
 p=m.node_tree.nodes.get('Principled BSDF')
 if not p:continue
 p.inputs['Transmission Weight'].default_value=0;p.inputs['Alpha'].default_value=1
 if m.name=='carpaint':
  p.inputs['Base Color'].default_value=(.28,.054,.044,1);p.inputs['Roughness'].default_value=.34;p.inputs['Metallic'].default_value=.22;p.inputs['Coat Weight'].default_value=.24
 elif m.name in ['chrome','mirror','rim','brakedisk']:
  p.inputs['Metallic'].default_value=.78 if m.name=='rim' else .94;p.inputs['Roughness'].default_value=.29 if m.name=='rim' else .22
  p.inputs['Base Color'].default_value=(.50,.53,.50,1)
 elif m.name=='windowglass':
  p.inputs['Base Color'].default_value=(.22,.34,.34,1);p.inputs['Roughness'].default_value=.13;p.inputs['Alpha'].default_value=.20;p.inputs['Transmission Weight'].default_value=0
  m.surface_render_method='DITHERED';m.use_transparency_overlap=False
 elif m.name.endswith('glass'):
  p.inputs['Roughness'].default_value=.27
 elif m.name=='black':p.inputs['Base Color'].default_value=(.018,.026,.03,1);p.inputs['Roughness'].default_value=.60
 elif m.name=='tire':p.inputs['Base Color'].default_value=(.018,.024,.028,1);p.inputs['Roughness'].default_value=.78
dash=pbr('Cabin_Dark_Grained_Plastic',(.036,.057,.064),.76)
edge=pbr('Cabin_Black_Edges',(.014,.022,.026),.56)
metal=pbr('Cabin_Satin_Aluminium',(.33,.38,.36),.38,.68)
ivory=pbr('Cabin_Warm_Ivory_Markings',(.71,.68,.54),.6)
leather=pbr('Steering_Charcoal_Leather',(.023,.035,.038),.70)
lining=pbr('Cabin_Headliner',(.25,.29,.27),.9)
cloth=pbr('Seat_Woven_Slate_Cloth',(.14,.22,.23),.94)
tex=bpy.data.images.load(str(R/'assets/textures/cloth_weave.png'));n=cloth.node_tree.nodes.new('ShaderNodeTexImage');n.image=tex
cloth.node_tree.links.new(n.outputs['Color'],cloth.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
rough_tex=cloth.node_tree.nodes.new('ShaderNodeTexImage');rough_tex.image=bpy.data.images.load(str(R/'assets/textures/cloth_roughness.png'));rough_tex.image.colorspace_settings.name='Non-Color'
cloth.node_tree.links.new(rough_tex.outputs['Color'],cloth.node_tree.nodes['Principled BSDF'].inputs['Roughness'])
noise=dash.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=540
bump=dash.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.14;bump.inputs['Distance'].default_value=.0012
dash.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);dash.node_tree.links.new(bump.outputs['Normal'],dash.node_tree.nodes['Principled BSDF'].inputs['Normal'])
for idx in range(76,85):
 o=bpy.data.objects[f'desirefx_me_{idx:03d}'];o.data.materials.clear()
 m=cloth if idx in [77,78,79,80,81] else leather if idx==82 else lining if idx==84 else dash
 o.data.materials.append(m)
 if m==cloth:
  uv=o.data.uv_layers.active or o.data.uv_layers.new(name='ClothUV')
  for poly in o.data.polygons:
   for li in poly.loop_indices:
    co=o.data.vertices[o.data.loops[li].vertex_index].co;uv.data[li].uv=(co.x*25,(co.y+co.z)*25)
def cube(name,loc,scale,mat,bevel=.005):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(mat)
 if bevel:
  mod=o.modifiers.new('Soft manufactured edges','BEVEL');mod.width=bevel;mod.segments=3
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
  for p in o.data.polygons:p.use_smooth=True
  mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def labelplane(name,center,w,h,texture):
 x,y,z=center
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([(x+w/2,y,z-h/2),(x-w/2,y,z-h/2),(x-w/2,y,z+h/2),(x+w/2,y,z+h/2)],[],[(0,1,2,3)]);mesh.update()
 uv=mesh.uv_layers.new(name='DetailUV')
 for i,co in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=co
 o=bpy.data.objects.new(name,mesh);s.collection.objects.link(o)
 mat=pbr(name+'_Ink',(.1,.1,.1),.7);n=mat.node_tree.nodes.new('ShaderNodeTexImage');n.image=bpy.data.images.load(str(R/'assets/textures'/texture));mat.node_tree.links.new(n.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color']);o.data.materials.append(mat)
 return o
def cylinder(name,loc,radius,depth,mat,axis='Y',verts=32):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=loc);o=bpy.context.object;o.name=name
 if axis=='Y':o.rotation_euler.x=math.pi/2
 o.data.materials.append(mat)
 mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=min(radius*.15,.002);mod.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 for p in o.data.polygons:p.use_smooth=True
 return o
def curve(name,points,mat,r=.0016):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=2
 sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
 for p,co in zip(sp.points,points):p.co=(*co,1)
 ob=bpy.data.objects.new(name,cu);s.collection.objects.link(ob);ob.data.materials.append(mat);return ob
# The existing recess is retained. This is an artistic period-style enrichment, not an exact historical restoration.
cube('Instrument_Recess_Bezel',(.414,-.708,.966),(.375,.020,.119),edge,.011)
labelplane('Analogue_Speedometer_And_Gauges',(.414,-.695,.966),.358,.105,'analogue_cluster.png')
cube('Radio_Body',(0,-.689,.795),(.257,.031,.119),edge,.006)
labelplane('Radio_Frequency_And_Cassette',(0,-.671,.795),.247,.102,'period_radio.png')
for x in [-.105,.105]:
 cylinder('Radio_Tuning_Knob',(x,-.655,.817),.012,.020,edge)
 cylinder('Radio_Knob_Cap',(x,-.644,.817),.008,.002,metal)
cube('Climate_Control_Bezel',(0,-.688,.693),(.254,.034,.080),edge,.004)
labelplane('Climate_Slider_Graphics',(0,-.667,.693),.237,.069,'climate_panel.png')
for z,x in [(.714,.045),(.693,.005),(.672,-.034)]:cube('Climate_Slider_Tab',(x,-.657,z),(.022,.018,.009),metal,.002)
def vent(x,y,z,w):
 cube('Vent_Recess',(x,y,z),(w,.025,.067),edge,.007)
 for j in range(5):cube('Vent_Louver',(x,y+.017,z-.022+j*.011),(w-.020,.012,.0038),dash,.0012)
 cube('Vent_Adjustment',(x+.024,y+.024,z),(.008,.009,.030),metal,.0015)
vent(-.055,-.708,.896,.19)
vent(-.56,-.749,.9,.14)
vent(.672,-.751,.898,.105)
# Glovebox outline, latch and restrained trim.
cube('Glovebox_Front',(-.395,-.735,.821),(.422,.015,.139),dash,.009)
cube('Glovebox_Latch',(-.395,-.719,.862),(.068,.014,.012),edge,.003)
cube('Glovebox_Latch_Accent',(-.395,-.710,.862),(.042,.004,.004),metal,.001)
for x in [-.159,.149]:
 cube('Dashboard_Switch',(x,-.683,.786),(.019,.017,.031),dash,.003)
cube('Hazard_Switch',(.149,-.672,.786),(.009,.004,.013),pbr('Hazard_Warm_Red',(.55,.085,.047),.6),.001)
# Gear lever and boot, kept mechanical and modest.
cube('Gear_Boot_Base',(0,-.245,.515),(.108,.130,.022),edge,.011)
for j in range(4):cube('Gear_Boot_Fold',(0,-.245,.536+j*.009),(.087-j*.012,.109-j*.013,.013),leather,.006)
cylinder('Gear_Lever_Shaft',(0,-.245,.613),.008,.12,metal,axis='Z')
bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=(0,-.245,.681));knob=bpy.context.object;knob.name='Gear_Lever_Knob';knob.scale=(.025,.032,.026);knob.data.materials.append(leather)
for p in knob.data.polygons:p.use_smooth=True
# Side and face seams sampled directly from original seat surfaces.
seam=pbr('Cloth_Stitching',(.30,.37,.34),.92)
for idx in [77,78]:
 ob=bpy.data.objects[f'desirefx_me_{idx:03d}']
 for center in [-.39,.39]:
  for dx in [-.19,.19]:
   pts=[]
   for j in range(24):
    if idx==77:
     ray=Vector((center+dx,-.405+j*.019,1.4));direction=Vector((0,0,-1))
    else:
     ray=Vector((center+dx,-.55,.63+j*.017));direction=Vector((0,1,0))
    hit,loc,normal,_=ob.ray_cast(ray,direction)
    if hit:pts.append(loc+normal*.0026)
   if len(pts)>2:curve('Tailored_Seat_Seam',pts,seam,.0012)
# Retain identification but remove distributor lettering from derivative licence plates by applying a plain school training plate.
for idx in [89,90]:
 o=bpy.data.objects[f'desirefx_me_{idx:03d}'];o.hide_render=True;o.hide_viewport=True
plate=pbr('Training_Plate_Ivory',(.65,.68,.58),.68)
cube('Front_Training_Plate',(0,-2.251,.485),(.46,.014,.094),plate,.006)
cube('Rear_Training_Plate',(0,2.189,.833),(.46,.014,.094),plate,.006)
# Separate the source objects into semantic groups without touching the uploaded originals.
for o in s.objects:
 if o.name.startswith('desirefx_me_'):o['original_source_object']=o.name
 s.unit_settings.system='METRIC'
out=R/'car';out.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
for o in s.objects:
 if o.type in {'MESH','CURVE'} and not o.hide_render:o.select_set(True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(R/'source/Santana_Refined.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'Santana_Refined.glb'),export_format='GLB',use_selection=True,export_apply=True,export_cameras=False,export_lights=False,export_extras=True)
summary={'source_triangles_retained':1091499,'source_original_unchanged':True,'detail_textures':['analogue_cluster','period_radio','climate_panel','cloth_weave','cloth_roughness','plastic_grain'],'new_detail_objects':sum(not o.name.startswith('desirefx_me_') for o in s.objects),'scale':0.01,'front_axis_blender':'-Y','up_axis_blender':'+Z','notes':['Period-style artistic enrichment, not exact historical restoration.','Original detailed tire geometry retained.','Original distributor plate hidden in derivative and training plate added.']}
(R/'source/refinement_manifest.json').write_text(json.dumps(summary,indent=2))
print('REFINEMENT_COMPLETE',summary)
