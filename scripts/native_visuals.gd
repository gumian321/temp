extends RefCounted
const AttackShaders=preload("res://scripts/attack_shader_layer.gd")
const Trails=preload("res://scripts/projectile_trails.gd")
const FluidRibbon=preload("res://scripts/fluid_ribbon.gd")
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
func trail(canvas,entity:Dictionary,prefab,elapsed:float,zoom:float,hostile:bool=false):
 var state:Dictionary=entity.get('flight_trail',{})
 if state.is_empty():return
 var painter=AttackShaders.route(canvas,Trails.actor_family(entity),hostile)
 Trails.paint(painter,state,zoom,elapsed)
func beam(canvas,effect:Dictionary,elapsed:float,zoom:float):
 var start=canvas.world(effect.position);var end=canvas.world(effect.end)
 var friendly=bool(effect.get('friendly',true))
 FluidRibbon.paint(AttackShaders.route(canvas,'tesla',not friendly),FluidRibbon.line(start,end),6.0*zoom,elapsed,0.0,FluidRibbon.BEAM,1.0,friendly,Color('51d7ff'))
