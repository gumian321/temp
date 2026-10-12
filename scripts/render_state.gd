extends RefCounted
static func instantiate(source:Array,key:int)->Array:
 var rng=RandomNumberGenerator.new();rng.seed=key
 var choices={};var result:Array=[]
 for original in source:
  var metadata:Dictionary=original.get('presentation',{})
  if not metadata.get('active',true):continue
  var include=true
  for choice in metadata.get('choices',[]):
   if not choices.has(choice.group):choices[choice.group]=rng.randi_range(0,int(choice.count)-1)
   if choices[choice.group]!=int(choice.index):include=false
  if not include:continue
  var renderer:Dictionary=original.duplicate()
  var sprites:Array=metadata.get('sprites',[])
  if not sprites.is_empty():renderer.sprite=sprites[rng.randi_range(0,sprites.size()-1)]
  if metadata.get('random_rotation',false):renderer.angle=rng.randf()*TAU
  result.append(renderer)
 return result
static func angle(renderer:Dictionary,elapsed:float)->float:
 return float(renderer.angle)-deg_to_rad(float(renderer.get('presentation',{}).get('rotation_speed',0)))*elapsed
static func color(renderer:Dictionary,elapsed:float,pulse:bool=false,hit_color:Color=Color.WHITE)->Color:
 var source:Dictionary=renderer.get('color',{});var result=Color(source.get('r',1),source.get('g',1),source.get('b',1),source.get('a',1))
 var metadata:Dictionary=renderer.get('presentation',{});var arrow:Dictionary=metadata.get('arrow',{})
 if not arrow.is_empty():
  var phase=fposmod(elapsed/float(arrow.duration)-int(arrow.index),int(arrow.count))
  result.a*=lerpf(0.25,1,phase) if phase<1 else (lerpf(1,0.25,phase-1) if phase<2 else 0.25)
 if pulse and not metadata.get('pulse',{}).is_empty():
  var config:Dictionary=metadata.pulse
  if config.get('useSetEffectColor',false):
   var c:Dictionary=config.effectColor;hit_color=Color(c.r,c.g,c.b,1)
  result=Color(hit_color.r,hit_color.g,hit_color.b,result.a)
 return result
