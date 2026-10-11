import bpy,json
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath='/workspace/scratch/7ff431bdbeb7/user-assets/inspection/imported_santana_original.blend',load_ui=False,use_scripts=False)
for o in bpy.context.scene.objects: o.scale*=.01
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
for x in [-.6,-.3,0,.25,.4,.55]:
 for z in [.65,.75,.85,.95,1.03]:
  hit,loc,norm,ind,obj,_=bpy.context.scene.ray_cast(deps,Vector((x,.15,z)),Vector((0,-1,0)),distance=2)
  if hit: print('HIT',x,z,obj.name,[round(i,4) for i in loc],[round(i,3) for i in norm])
