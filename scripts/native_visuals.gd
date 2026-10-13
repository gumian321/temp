extends RefCounted
var db
var definitions:Dictionary={}
var textures:Dictionary={}
var tesla:Dictionary={}
func setup(source,fx):
 db=source;definitions=db.read_json('native_visuals')
 for id in definitions:
  for definition in definitions[id]:
   definition['_gradient']=fx.source_gradient(definition.parameters.get('colorGradient',{}))
   definition['_width']=fx.source_curve({'maxCurve':definition.parameters.get('widthCurve',{})})
   for path in definition.frames+[definition.texture]:
    if path!='' and not textures.has(path):textures[path]=load(path)
   if 'Projectile_Line_Tesla' in db.prefabs[id].source:tesla=definition
func trail(canvas,entity:Dictionary,prefab,elapsed:float,zoom:float):
 var id:String=db.pool.get(str(prefab),'')
 for definition in definitions.get(id,[]):
  if definition.kind!='TrailRenderer':continue
  var duration=float(definition.duration)
  if not entity.has('_trail'):entity._trail=[]
  var points:Array=entity._trail
  if points.is_empty() or Vector2(points[-1].position).distance_to(entity.position)>2:points.append({'position':entity.position,'time':elapsed})
  while not points.is_empty() and elapsed-float(points[0].time)>duration:points.pop_front()
  for i in range(1,points.size()):
   var normalized=clampf((elapsed-float(points[i].time))/maxf(.001,duration),0,1)
   var width=float(definition.parameters.get('widthMultiplier',1))*float(definition._width.sample(normalized))*48*zoom
   var color=definition._gradient.sample(normalized)
   var texture=textures.get(definition.texture)
   var start=canvas.world(points[i-1].position);var end=canvas.world(points[i].position)
   if texture!=null:canvas.art(texture,(start+end)*.5,Vector2(start.distance_to(end),maxf(.1,width)),(end-start).angle(),color,true)
   else:canvas.draw_line(start,end,color,maxf(0.1,width),true)
func beam(canvas,effect:Dictionary,elapsed:float,zoom:float):
 if tesla.is_empty():return
 if not effect.has('_visual_birth'):effect._visual_birth=elapsed
 var frames:Array=tesla.frames;var path:String=tesla.texture
 if not frames.is_empty():path=frames[int((elapsed-float(effect._visual_birth))/maxf(.001,float(tesla.frame_duration)))%frames.size()]
 var texture=textures.get(path)
 if texture==null:return
 var start=canvas.world(effect.position);var end=canvas.world(effect.end)
 var width=float(tesla.parameters.get('widthMultiplier',1))*48*zoom
 canvas.art(texture,(start+end)*.5,Vector2(start.distance_to(end),width),(end-start).angle(),tesla._gradient.sample(0.0),true)
