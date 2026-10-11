import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(R/'source/Santana_Refined.blend'),load_ui=False,use_scripts=False)
derived={}
for o in bpy.context.scene.objects:
 if o.type=='MESH' and o.name.startswith('desirefx_me_'):
  o.data.calc_loop_triangles()
  derived[o.name]={'vertices':[tuple(o.matrix_world@v.co) for v in o.data.vertices],'triangles':len(o.data.loop_triangles)}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=str(R/'source/original/Volkswagen_Santana_CN-spec_1985.obj'),forward_axis='Y',up_axis='Z')
max_error=0.;count=0
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 o.data.calc_loop_triangles();d=derived[o.name]
 assert len(o.data.vertices)==len(d['vertices']),o.name
 assert len(o.data.loop_triangles)==d['triangles'],o.name
 for v,co in zip(o.data.vertices,d['vertices']):
  p=(o.matrix_world@v.co)*.01
  max_error=max(max_error,max(abs(p[i]-co[i]) for i in range(3)))
 count+=1
assert count==90 and max_error<1e-5
result={'original_meshes_preserved':count,'vertex_and_triangle_counts_match':True,'maximum_position_difference_m':max_error,'original_tire_geometry_preserved':True,'note':'Two original distributor licence-plate objects retained in authoring source but hidden in derivative render/export; training plates added.'}
(R/'source/geometry_verification.json').write_text(json.dumps(result,indent=2))
print('GEOMETRY_VERIFIED',json.dumps(result))
