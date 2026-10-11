import bpy,math,sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
views=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
bpy.ops.wm.open_mainfile(filepath=str(R/'source/Santana_Refined.blend'),load_ui=False,use_scripts=False)
s=bpy.context.scene
env=R/'environment/SchoolCorner.glb'
if env.exists():bpy.ops.import_scene.gltf(filepath=str(env))
else:
 bpy.ops.mesh.primitive_plane_add(size=100);floor=bpy.context.object;mat=bpy.data.materials.new('Preview_Ground');mat.diffuse_color=(.19,.23,.24,1);floor.data.materials.append(mat)
if not s.world:s.world=bpy.data.worlds.new('Soft_Outdoor_Environment')
s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.46,.58,.67,1);s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.50
def light(name,kind,loc,energy,size,target=(0,0,.7)):
 data=bpy.data.lights.new(name,kind);data.energy=energy
 if kind=='AREA':data.shape='DISK';data.size=size
 if kind=='SUN':data.angle=math.radians(14)
 ob=bpy.data.objects.new(name,data);s.collection.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob
sun=light('Warm_Clear_Afternoon','SUN',(-4,-6,9),2.0,1);sun.data.color=(1,.89,.73)
light('Soft_Sky_Fill','AREA',(4,-2,6),500,6)
light('Broad_Paint_Highlight','AREA',(-3,1,5),400,5)
camd=bpy.data.cameras.new('Art_Slice_Camera');cam=bpy.data.objects.new('Art_Slice_Camera',camd);s.collection.objects.link(cam);s.camera=cam;camd.clip_start=.01;camd.clip_end=180
s.render.engine='CYCLES';s.cycles.samples=96;s.cycles.use_denoising=False
s.render.resolution_x=1280;s.render.resolution_y=800;s.render.resolution_percentage=100
s.cycles.max_bounces=4;s.cycles.diffuse_bounces=2;s.cycles.glossy_bounces=2;s.cycles.transparent_max_bounces=6
for m in bpy.data.materials:
 if m.name=='windowglass':m.surface_render_method='BLENDED'
s.render.image_settings.file_format='PNG';s.render.film_transparent=False
s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.view_settings.exposure=-.45
def render(name,loc,target,lens):
 cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();camd.lens=lens
 s.render.filepath=str(R/'previews'/name);bpy.ops.render.render(write_still=True)
fill=light('Cabin_Bounce','AREA',(-.35,-.15,1.20),11,.7,(.12,-.75,.82));fill.data.color=(.85,.93,1.0)
if not views or 'cockpit' in views:render('Santana_Cockpit_Blender_Preview.png',(-.33,.03,1.16),(.13,-.76,.87),23)
if not views or 'detail' in views:render('Santana_Interior_Detail_Blender_Preview.png',(.015,-.21,1.13),(.20,-.70,.84),32)
fill.hide_render=True
if not views or 'exterior' in views:render('Santana_Exterior_Blender_Preview.png',(6.0,-8.6,2.6),(0,.6,.92),46)
if not views or 'tire' in views:render('Santana_Tire_Blender_Preview.png',(1.78,-2.13,.66),(.70,-1.37,.32),61)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(R/'source/Santana_Art_Slice.blend'))
