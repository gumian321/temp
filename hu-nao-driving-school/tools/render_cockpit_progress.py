import bpy
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(R/'source/Santana_Refined.blend'),load_ui=False,use_scripts=False)
s=bpy.context.scene
d=bpy.data.cameras.new('Cockpit_Review');o=bpy.data.objects.new('Cockpit_Review',d);s.collection.objects.link(o);s.camera=o
o.location=(-.33,.03,1.16);o.rotation_euler=(Vector((.13,-.76,.87))-o.location).to_track_quat('-Z','Y').to_euler();d.lens=23;d.clip_start=.01
s.render.engine='BLENDER_WORKBENCH';s.render.resolution_x=1280;s.render.resolution_y=800;s.render.resolution_percentage=100
s.display.shading.light='STUDIO';s.display.shading.color_type='TEXTURE';s.display.shading.show_cavity=True;s.display.shading.cavity_type='BOTH';s.display.shading.show_shadows=False
s.display.shading.curvature_ridge_factor=1.2;s.display.shading.curvature_valley_factor=1.1
s.view_settings.view_transform='Standard';s.view_settings.look='Medium High Contrast'
s.render.filepath=str(R/'previews/Santana_Cockpit_Progress_Blender.png');bpy.ops.render.render(write_still=True)
