extends SceneTree
const Art=preload("res://scripts/insect_projectiles.gd")
const FX=preload("res://scripts/weapon_fx.gd")
var failures=0
class Canvas extends RefCounted:
 func world(at):return at
 func get_viewport_rect():return Rect2(0,0,1920,1080)
func check(ok:bool,label:String):
 if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func run():
 var anchors=PackedVector2Array([Vector2(.57,0),Vector2(.19,-.49),Vector2(-.32,-.42),Vector2(-.52,0),Vector2(-.32,.42),Vector2(.19,.49)])
 for size in [Vector2(22,14),Vector2(41,34),Vector2(73.412,38.777)]:
  var shape=Art.hostile_shell(size);var original=PackedVector2Array()
  for i in anchors.size():
   for step in 4:original.append(anchors[i].cubic_interpolate(anchors[(i+1)%6],anchors[(i+5)%6],anchors[(i+2)%6],step/4.0)*size)
  check(shape.shell==original,"Cached contour exactly preserves all original vertices")
  check(shape.border.size()==25 and shape.border[24]==original[0],"Closed outline retains original shape")
  check(Art.hostile_shell(size)==shape,"Warm-cache contour is unchanged")
 for i in 300:Art.hostile_shell(Vector2(22+i*.1,14))
 check(Art.hostile_shells.size()<=Art.MAX_SHELL_CACHE,"Zoom-dependent shell cache stays bounded")
 var fx=FX.new();var effects=[]
 for i in 240:
  effects.append({"id":i,"kind":["hit","chain","flame","explosion","hole_birth","emp"][i%6],"friendly":i%3!=0})
 var hazards=effects.filter(func(e):return not e.get("friendly",true) and e.kind in ["chain","flame"])
 var original_order=hazards+effects.filter(func(e):return e.kind in FX.MAJOR_EFFECTS and e not in hazards)+effects.filter(func(e):return e.kind not in FX.MAJOR_EFFECTS and e not in hazards)
 fx.order_effects(effects)
 check(fx.hazard_effects+fx.major_effects+fx.minor_effects==original_order,"Priority and stable within-priority ordering are unchanged")
 fx.order_effects([])
 check(fx.hazard_effects.is_empty() and fx.major_effects.is_empty() and fx.minor_effects.is_empty(),"Cleared effects leave no stale references")
 check(fx.visible(Canvas.new(),Vector2(1850,1030),0),"Wide/tall viewports do not cull visible bullets")
 check(not fx.visible(Canvas.new(),Vector2(2100,1200),0),"Offscreen points are culled against actual viewport")
 check(Art.family({"fx_family":"rocket","data":{"name":"gatling"}})=="rocket","Explicit visual family wins")
 check(Art.family({"data":{"name":"Core_Gun_Cannon"}})=="cannon","Uncached fallback family resolves")
 print("RENDER_HOTPATH_REGRESSIONS "+("PASS" if failures==0 else "FAIL"));quit(0 if failures==0 else 1)
