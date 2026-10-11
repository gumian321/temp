import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
results=[]
for filename in ['Santana_Refined.blend','Santana_Art_Slice.blend']:
 path=R/'source'/filename
 bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False,use_scripts=False)
 bpy.ops.file.pack_all()
 images=[i for i in bpy.data.images if i.source=='FILE']
 assert all(i.packed_file for i in images),filename
 bpy.ops.wm.save_as_mainfile(filepath=str(path))
 results.append({'file':filename,'file_images':len(images),'all_images_embedded':True})
(R/'source/packed_image_verification.json').write_text(json.dumps(results,indent=2))
print('AUTHORING_IMAGES_PACKED',json.dumps(results))
