extends SceneTree
func _initialize():
 var db=load('res://scripts/source_db.gd').new();var p=load('res://scripts/centipede.gd').new(db)
 var cells=[]
 for y in range(-5,6):
  for x in range(-5,6):cells.append(Vector2i(x,y))
 cells.sort_custom(func(a,b):return a.length_squared()<b.length_squared())
 for cell in cells:
  if p.parts.size()==61:break
  p.add_piece(db.named('Core_FuelTank' if p.parts.size()==1 else 'Core_Gun_Gatling').id,cell)
 var complete=p.parts.size()==61;var bounded=true;var maximum_step=0.0
 var start=Time.get_ticks_usec()
 for frame in range(3600):
  var previous=p.parts.map(func(part):return part.position)
  p.step(1.0/60,Vector2.from_angle(frame/120.0),frame%180<90)
  for i in p.parts.size():
   maximum_step=maxf(maximum_step,p.parts[i].position.distance_to(previous[i]))
   bounded=bounded and p.parts[i].position.is_finite() and p.parts[i].position.distance_to(p.head)<(p.parts.size()-1)*p.body_spacing+1
 var report={'max_modules':p.parts.size()-1,'seconds_simulated':60,'full_capacity':complete,'finite_bounded_positions':bounded,'maximum_part_step_pixels':maximum_step,'compute_ms':(Time.get_ticks_usec()-start)/1000.0,'passed':complete and bounded and maximum_step<30}
 FileAccess.open('res://artifacts/long-body-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
