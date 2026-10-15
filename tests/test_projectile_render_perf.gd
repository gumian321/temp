extends SceneTree
const Art=preload("res://scripts/insect_projectiles.gd")
const FX=preload("res://scripts/weapon_fx.gd")
class Canvas extends RefCounted:
 var calls=0
 func world(at):return at
 func get_viewport_rect():return Rect2(0,0,1440,900)
 func draw_set_transform(_a,_b=0):calls+=1
 func draw_texture_rect(_a,_b,_c,_d):calls+=1
 func draw_line(_a,_b,_c,_d,_e=true):calls+=1
 func draw_circle(_a,_b,_c,_d=true,_e=-1,_f=false):calls+=1
 func draw_colored_polygon(_a,_b):calls+=1
 func draw_polyline(_a,_b,_c,_d=true):calls+=1
 func draw_arc(_a,_b,_c,_d,_e,_f,_g,_h):calls+=1
func _initialize():call_deferred("run")
func run():
 var canvas=Canvas.new();var fx=FX.new();var bullets=[];var effects=[]
 for i in 1200:
  bullets.append({"position":Vector2(200+i%900,200+i%500),"previous":Vector2(150,150),"origin":Vector2(100,100),"velocity":Vector2(600,0),"friendly":i%2==0,"fx_family":["gatling","cannon","rocket"][i%3],"radius":4,"data":{}})
  effects.append({"position":Vector2(200+i%900,200+i%500),"end":Vector2(350,350),"kind":"chain" if i%2==0 else "hit","life":.1,"fx_duration":.2,"fx_family":"tesla","friendly":i%2!=0,"radius":5})
 var battle={"effects":effects,"special":{"black_holes":[],"mines":[]}}
 for b in bullets:fx.paint_projectile(canvas,b,1,1)
 var start=Time.get_ticks_usec();canvas.calls=0
 for frame in 12:
  fx.draw_count=0
  for b in bullets:fx.paint_projectile(canvas,b,1,1)
 var projectile_us=Time.get_ticks_usec()-start;var projectile_calls=canvas.calls
 start=Time.get_ticks_usec();canvas.calls=0
 for frame in 12:fx.paint(canvas,battle,1,1)
 print(JSON.stringify({"projectiles_us":projectile_us,"projectile_calls":projectile_calls,"effects_us":Time.get_ticks_usec()-start,"effects_calls":canvas.calls,"note":"CPU draw-command construction with stub canvas; not GPU draw calls"}))
 quit()
