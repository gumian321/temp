extends SceneTree
const Layer=preload("res://scripts/attack_shader_layer.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const Controls=preload("res://scripts/insect_attack_fx.gd")
class Board extends Node2D:
 func world(at):return at
var checks:Array=[]
func check(ok:bool,label:String):
 checks.append({"name":label,"passed":ok})
 if not ok:push_error(label)
func _initialize():call_deferred("run")
func run():
 var board=Board.new();root.add_child(board)
 var layer=Layer.new();layer.trace_commands=true;layer.attach(board)
 var fx=FX.new()
 var initial=layer.stats()
 check(initial.materials==Layer.MODES.size(),"One shared ordered material per family")
 check(initial.batches==Layer.MODES.size()*2+1,"Fixed friendly/hostile ordered batches plus foreground")
 for key in Layer.MODES:
  layer.begin_frame(0.25)
  var painter=Layer.route(board,key)
  check(painter.shader_family==key and painter.batch.material.shader==Layer.SHADER,"Bound runtime shader: "+key)
  if key in ["silk","tendril"]:
   Controls.paint(board,[{"kind":key,"origin":Vector2(100,100),"target":{"position":Vector2(260,130),"hp":100,"radius":20},"duration":0.8,"life":0.7,"friendly":true}],1.0)
  elif key in ["repair_drone","scrap_drone"]:
   painter.draw_circle(Vector2(100,100),12,Color.WHITE)
  else:
   var bullet={"fx_family":key,"position":Vector2(230,180),"previous":Vector2(200,180),"origin":Vector2(100,180),"velocity":Vector2(600,0),"radius":5,"friendly":true}
   fx.paint_projectile(board,bullet,0.25,1.0)
  check(painter.batch.commands.size()+painter.texture_batch.commands.size()>1,"Actual family drawing enqueued: "+key)
 layer.begin_frame(0.5)
 var ordered=Layer.route(board,"tesla")
 ordered.draw_line(Vector2.ZERO,Vector2.ONE,Color.WHITE)
 ordered.draw_texture_rect(FX.new().halo_texture,Rect2(0,0,10,10),false)
 ordered.draw_line(Vector2.ZERO,Vector2.ONE,Color.WHITE)
 var methods=ordered.batch.commands.map(func(command):return command[0])
 check(ordered.texture_batch==ordered.batch and methods.find("draw_texture_rect")>methods.find("draw_line") and methods[-1]=="draw_line","Geometry and art preserve caller order in the same batch")
 var effect={"kind":"chain","fx_family":"tesla","position":Vector2(100,100),"end":Vector2(300,100),"life":0.15,"fx_duration":0.22,"friendly":true}
 fx.paint_effect(board,effect,1.0)
 check(layer.batches["teslafalse"].texture_batch.commands.size()>0,"Friendly tongue early-return uses electric texture shader")
 var before=effect.duplicate(true)
 for frame in 12:
  layer.begin_frame(frame/60.0)
  fx.paint_effect(board,effect,1.0)
 check(effect==before,"Rendering preserves all attack lifecycle/simulation data")
 check(layer.stats().materials==initial.materials and layer.stats().batches==initial.batches,"Twelve frames never allocate new materials or nodes")
 layer.begin_frame(1.0)
 check(layer.stats().commands==0,"Every frame clears all old attack commands")
 var friendly=Layer.route(board,"gatling");var hostile=Layer.route(board,"gatling",true)
 check(hostile.batch.z_index>friendly.batch.z_index,"Incoming hazards render over friendly effects")
 check(Layer.foreground(board).batch.z_index>friendly.batch.z_index and Layer.foreground(board).batch.z_index<hostile.batch.z_index,"Loot remains above friendly effects and below incoming hazards")
 var hot_board=Board.new();root.add_child(hot_board)
 var hot_layer=Layer.new();hot_layer.attach(hot_board);hot_layer.begin_frame(0.0)
 var hot_painter=Layer.route(hot_board,"gatling")
 hot_painter.draw_line(Vector2.ZERO,Vector2.ONE,Color.WHITE)
 check(hot_painter.batch.commands.is_empty() and hot_layer.stats().commands==1,"Production submits native commands without allocating replay arrays")
 hot_layer.begin_frame(0.1)
 check(hot_layer.stats().commands==0,"Native command counts clear on the next frame")
 if DisplayServer.get_name()!="headless":await verify_material_pixels(board,layer)
 var report={"checks":checks,"passed":checks.all(func(c):return c.passed),"stats":initial}
 FileAccess.open("res://artifacts/attack-shader-materials-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report));quit(0 if report.passed else 1)

func verify_material_pixels(board:Node2D,layer):
 root.size=Vector2i(1440,900)
 root.content_scale_size=Vector2i(1440,900)
 var backdrop=ColorRect.new();backdrop.color=Color("f5f1e5");backdrop.size=Vector2(1440,900);backdrop.z_index=-1;board.add_child(backdrop)
 var patch=Image.create(80,56,false,Image.FORMAT_RGBA8);patch.fill(Color.TRANSPARENT)
 patch.fill_rect(Rect2i(2,2,20,20),Color("152449"))
 patch.fill_rect(Rect2i(28,2,20,20),Color("d82746"))
 patch.fill_rect(Rect2i(54,2,20,20),Color("fffaf0"))
 patch.fill_rect(Rect2i(2,30,72,20),Color("9cb671"))
 var texture=ImageTexture.create_from_image(patch)
 layer.begin_frame(0.0)
 var points=[]
 for i in Layer.MODES.size():
  var key=Layer.MODES.keys()[i]
  var at=Vector2(24+(i%5)*205,44+int(i/5)*180);points.append(at)
  var painter=Layer.route(board,key,i%2==1)
  painter.draw_texture_rect(texture,Rect2(at,Vector2(160,112)),false)
  var label=Label.new();label.text=key;label.position=at-Vector2(0,28);label.add_theme_color_override("font_color",Color("213b6e"));board.add_child(label)
 var pictures=[]
 for clock in [0.0,0.63]:
  for material in layer.materials.values():material.set_shader_parameter("clock",clock)
  await process_frame
  await RenderingServer.frame_post_draw
  pictures.append(root.get_texture().get_image())
 pictures[1].save_png("res://artifacts/attack-material-pigments.png")
 var checksums=[]
 for i in points.size():
  var key=Layer.MODES.keys()[i];var at:Vector2=points[i]
  var first:Image=pictures[0];var second:Image=pictures[1]
  var ink=second.get_pixelv(Vector2i(at+Vector2(20,20)))
  var ivory=second.get_pixelv(Vector2i(at+Vector2(125,20)))
  var clear=second.get_pixelv(Vector2i(at+Vector2(157,108)))
  check(color_difference(ink,Color("152449"))<0.018,key+" preserves dark illustrated ink")
  check(color_difference(ivory,Color("fffaf0"))<0.025,key+" preserves ivory hazard separator")
  check(color_difference(clear,backdrop.color)<0.018,key+" preserves transparent atlas margins")
  var changed=0;var red_safe=true;var dark_folds=0;var wet_lips=0;var checksum=0.0
  for y in range(64,94):
   for x in range(8,140):
    var pos=Vector2i(at+Vector2(x,y));var pixel=second.get_pixelv(pos)
    if color_difference(first.get_pixelv(pos),pixel)>0.012:changed+=1
    if pixel.g<0.62:dark_folds+=1
    if pixel.r>0.68:wet_lips+=1
    checksum+=pixel.r+pixel.g*2.0+pixel.b*3.0
  for y in range(8,38):
   for x in range(60,90):
    var pixel=second.get_pixelv(Vector2i(at+Vector2(x,y)))
    red_safe=red_safe and pixel.r>0.72 and pixel.r>pixel.g*2.5 and pixel.r>pixel.b*2.0
  checksums.append(checksum)
  check(red_safe,key+" keeps hostile crimson unmistakably red")
  check(changed>90,key+" animated membrane changes native pixels with frozen geometry")
  check(dark_folds>15 and wet_lips>15,key+" produces both dark tissue folds and wet highlights")
 check(checksums.max()-checksums.min()>50.0,"Material families have distinct tissue structure")

func color_difference(a:Color,b:Color)->float:
 return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
