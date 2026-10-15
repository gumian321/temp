extends SceneTree
# Optional baseline comparison: PARTICLE_BASELINE_SCRIPT=/absolute/path/particle_effects.gd
# Run with an isolated XDG_DATA_HOME; no player saves are read or written.
var failures:Array=[]
func _initialize():call_deferred('execute')
func check(ok:bool,message:String):
 if not ok:failures.append(message)
func compare_nodes(a:CPUParticles2D,b:CPUParticles2D,label:String):
 for property in a.get_property_list():
  if not (int(property.usage)&PROPERTY_USAGE_STORAGE):continue
  var key:String=property.name
  if key in ['name','seed']:continue
  var av=a.get(key);var bv=b.get(key)
  if av is Curve:
   check(bv is Curve,label+': missing curve '+key)
   if bv is Curve:
    check(av.point_count==bv.point_count,label+': curve points '+key)
    for i in 129:check(is_equal_approx(av.sample(float(i)/128),bv.sample(float(i)/128)),label+': curve sample '+key)
  elif av is Gradient:
   check(bv is Gradient and av.colors==bv.colors and av.offsets==bv.offsets,label+': gradient '+key)
  elif av is Resource or bv is Resource:continue
  else:check(av==bv,label+': property '+key)
func dispose(nodes:Array):
 for node in nodes:node.free()
func benchmark(fx,rounds:int,types:Array=[])->float:
 var start=Time.get_ticks_usec()
 if types.is_empty():types=fx.definitions.keys()
 for repetition in rounds:
  for type in types:
   dispose(fx.play(type,Vector2(12,34),1.7,0.5,{},0.3,true))
 return float(Time.get_ticks_usec()-start)/1000
func execute():
 var db=load('res://scripts/source_db.gd').new()
 var fx=load('res://scripts/particle_effects.gd').new();root.add_child(fx);fx.setup(db)
 var checked=0;var cached_curves=0;var curve_types:Array=[]
 for type in fx.definitions:
  var first=fx.play(type,Vector2.ZERO,1,0,{},0,true)
  var second=fx.play(type,Vector2(50,25),2.5,3,{},1.2,true)
  for i in first.size():
   for key in ['damping_curve','radial_accel_curve','angular_velocity_curve']:
    var curve=first[i].get(key)
    if curve!=null:
     check(curve==second[i].get(key),'Curve must be shared: '+str(type)+' '+key);cached_curves+=1
     if type not in curve_types:curve_types.append(type)
   checked+=1
  dispose(first);dispose(second)
 # Dead weak references are removed without skipping or retaining live followers.
 var target={'position':Vector2(71,29)}
 var dead=fx.play('300',Vector2.ZERO,1,0,target,0,true)
 var live=fx.play('301',Vector2.ZERO,1,0,target,0,true)
 dispose(dead);fx._process(0)
 check(fx.followers.size()==live.size(),'Follower compaction')
 for node in live:check(node.position==target.position,'Follower position')
 dispose(live);fx._process(0);check(fx.followers.is_empty(),'Follower cleanup')
 var report={'preset_count':fx.definitions.size(),'emitters_checked':checked,'shared_curves_checked':cached_curves}
 var baseline_path=OS.get_environment('PARTICLE_BASELINE_SCRIPT')
 if not baseline_path.is_empty():
  var old_script=GDScript.new();old_script.source_code=FileAccess.get_file_as_string(baseline_path)
  check(old_script.reload()==OK,'Baseline loads')
  var old=old_script.new();root.add_child(old);old.setup(db)
  for type in fx.definitions:
   for radius in [0.25,1.0,2.5]:
    var before=old.play(type,Vector2(25,19),radius,0.8,{},0.7,true)
    var after=fx.play(type,Vector2(25,19),radius,0.8,{},0.7,true)
    check(before.size()==after.size(),'Emitter count '+str(type))
    for i in before.size():compare_nodes(before[i],after[i],str(type)+'/'+str(i))
    dispose(before);dispose(after)
  benchmark(old,2);benchmark(fx,2)
  var baseline_ms:Array=[];var cached_ms:Array=[]
  for sample in 5:
   if sample%2==0:
    baseline_ms.append(benchmark(old,10));cached_ms.append(benchmark(fx,10))
   else:
    cached_ms.append(benchmark(fx,10));baseline_ms.append(benchmark(old,10))
  baseline_ms.sort();cached_ms.sort()
  report['baseline_median_ms']=baseline_ms[2];report['cached_median_ms']=cached_ms[2]
  report['speedup']=baseline_ms[2]/cached_ms[2];report['benchmark_emissions_per_sample']=checked*10
  var targeted_baseline:Array=[];var targeted_cached:Array=[]
  for sample in 5:
   targeted_baseline.append(benchmark(old,100,curve_types));targeted_cached.append(benchmark(fx,100,curve_types))
  targeted_baseline.sort();targeted_cached.sort()
  report['curve_presets']=curve_types;report['curve_baseline_median_ms']=targeted_baseline[2];report['curve_cached_median_ms']=targeted_cached[2]
  report['curve_speedup']=targeted_baseline[2]/targeted_cached[2]
  old.free()
 report['failures']=failures;report['passed']=failures.is_empty()
 print(JSON.stringify(report));fx.free();quit(0 if failures.is_empty() else 1)
