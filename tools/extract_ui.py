"""Import actual source Canvas layouts, graphics, labels and persistent button calls."""
import json,re,yaml,shutil
from pathlib import Path
R=Path(__file__).resolve().parents[1];S=Path('/workspace/run-build-pew-source/UnityCore');g=json.load(open(R/'data/source_guids.json'))
out={}
for scene in (S/'Assets/Scenes').glob('*.unity'):
 t=scene.read_text();t=re.sub(r'^%.*\n','',t,flags=re.M);t=re.sub(r'^--- !u!\d+ &(-?\d+).*$',r'---\n__id: \1',t,flags=re.M)
 docs=list(yaml.load_all(t,Loader=yaml.CSafeLoader));gos={};ts={};gt={};cs={};native_ids={};canvases=set()
 for d in docs:
  if 'GameObject'in d:gos[d['__id']]=d['GameObject']
  for kind in ['Transform','RectTransform']:
   if kind in d:ts[d['__id']]=d[kind];gt[d[kind]['m_GameObject']['fileID']]=d['__id']
  if 'Canvas'in d:canvases.add(d['Canvas']['m_GameObject']['fileID'])
  if 'CanvasGroup'in d:native_ids.setdefault(d['CanvasGroup']['m_GameObject']['fileID'],[]).append(str(d['__id']))
  if 'MonoBehaviour'in d:
   v=d['MonoBehaviour'];v['_component_id']=str(d['__id']);cls=Path(g.get(v.get('m_Script',{}).get('guid',''),'')).stem;cs.setdefault(v['m_GameObject']['fileID'],[]).append((cls,v))
 def build(go,root=False):
  t=ts.get(gt.get(go),{});obj=gos[go]
  v={'id':str(go),'name':obj['m_Name'],'active':bool(obj.get('m_IsActive',1)),'rect':'m_AnchorMin'in t,'rotation':t.get('m_LocalRotation',{}),'position':t.get('m_LocalPosition',{}),'scale':t.get('m_LocalScale',{}),'anchor_min':t.get('m_AnchorMin',{}),'anchor_max':t.get('m_AnchorMax',{}),'size':t.get('m_SizeDelta',{}),'pivot':t.get('m_Pivot',{}),'anchored':t.get('m_AnchoredPosition',{}),'components':{},'ids':native_ids.get(go,[]).copy(),'children':[]}
  for cls,c in cs.get(go,[]):
   v['ids'].append(c['_component_id'])
   if cls not in ['UnityEngine.UI','Unity.TextMeshPro']:v['components'][cls]={k:a for k,a in c.items() if not k.startswith('m_')}
   if 'm_ShowMaskGraphic'in c:v['mask']={'show_graphic':bool(c['m_ShowMaskGraphic'])}
   if 'm_Softness'in c:v['mask']={'show_graphic':True}
   if 'm_IgnoreLayout'in c:v['layout_element']={k:a for k,a in c.items() if k.startswith('m_')}
   if 'm_Padding'in c:v['layout']={k:a for k,a in c.items() if k.startswith('m_')}
   if 'm_Sprite'in c:v['image']={'sprite':c['m_Sprite'].get('guid',''),'color':c.get('m_Color',{}),'type':c.get('m_Type',0),'fill_method':c.get('m_FillMethod',0),'fill_origin':c.get('m_FillOrigin',0),'fill_amount':c.get('m_FillAmount',1),'preserve_aspect':c.get('m_PreserveAspect',False)}
   if 'm_text'in c:v['text']={'content':c['m_text'],'font_size':c.get('m_fontSize',24),'font':g.get(c.get('m_fontAsset',{}).get('guid',''),''),'color':c.get('m_fontColor',{}),'alignment':c.get('m_HorizontalAlignment',2),'vertical':c.get('m_VerticalAlignment',512),'wrap':c.get('m_enableWordWrapping',True),'material':g.get(c.get('m_sharedMaterial',{}).get('guid',''),'')}
   if 'm_OnClick'in c:v['button']=c['m_OnClick'].get('m_PersistentCalls',{}).get('m_Calls',[])
   if 'm_OnValueChanged'in c and 'm_MinValue'in c:v['slider']={'min':c['m_MinValue'],'max':c['m_MaxValue'],'value':c['m_Value'],'calls':c['m_OnValueChanged'].get('m_PersistentCalls',{}).get('m_Calls',[])}
  for child in t.get('m_Children',[]):
   cgo=ts.get(child['fileID'],{}).get('m_GameObject',{}).get('fileID')
   if cgo in gos:v['children'].append(build(cgo))
  return v
 for go in canvases:
  # Nested canvases are included in their parents, but also independently selectable.
  out[scene.stem+'/'+gos[go]['m_Name']]=build(go,True)
(R/'data/ui_layouts.json').write_text(json.dumps(out,ensure_ascii=False,separators=(',',':')))
materials={}
for path in (S/'Assets/Material').glob('*.mat'):
 text=path.read_text();face=re.search(r'_FaceColor: (\{[^}]+\})',text);outline=re.search(r'_OutlineColor: (\{[^}]+\})',text);width=re.search(r'_OutlineWidth: ([\d.]+)',text)
 if face:materials[str(path.relative_to(S))]={'face':yaml.safe_load(face[1]),'outline':yaml.safe_load(outline[1]) if outline else {},'width':float(width[1]) if width else 0}
(R/'data/font_materials.json').write_text(json.dumps(materials))
for name in ['Perfect DOS VGA 437.ttf','LiberationSans.ttf']:shutil.copy2(S/'Assets/Font'/name,R/'assets/fonts'/name)
print('Imported source Canvases:',len(out))
