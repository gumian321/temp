extends SceneTree
const Rig=preload("res://scripts/soft_insect_rig.gd")
const Soft=preload("res://scripts/soft_insect.gd")
func _initialize():call_deferred("execute")
func stats(a:Array)->Dictionary:
 a.sort();return {"p50":a[a.size()/2],"p95":a[int(a.size()*.95)]}
func execute():
 var original=[];var batched=[];var original_ms=[];var batched_ms=[]
 for i in 64:
  var species=["grub","beetle","moth","sac","mantis","queen"][i%6]
  var entity={"uid":i+1,"kind":"AISwarmingUnit","position":Vector2(i*12,0),"angle":0.0,"hp":100.0,"max_hp":100.0,"radius":30.0,"brood_species":species}
  for enabled in [false,true]:
   var rig=Rig.new();rig.batch_appendages=enabled;root.add_child(rig);rig.setup(entity.duplicate(true));rig.visible=false
   if enabled:batched.append(rig)
   else:original.append(rig)
 for frame in 100:
  for group in [original,batched]:
   for rig in group:
    rig.entity.position+=Vector2(1.3,.2);rig.entity.angle+=.015;Soft.step(rig.entity,1.0/60.0)
  var start=Time.get_ticks_usec()
  for rig in original:rig.pose(1.0/60.0)
  var split=Time.get_ticks_usec()
  for rig in batched:rig.pose(1.0/60.0)
  var end=Time.get_ticks_usec()
  if frame>=20:original_ms.append((split-start)/1000.0);batched_ms.append((end-split)/1000.0)
 var report={"scope":"64 mixed animated rigs, headless pose CPU only; identical movement. Measures animation CPU; final GPU batch performs no CPU vertex update. Excludes renderer savings.","original_ms":stats(original_ms),"batched_ms":stats(batched_ms)}
 print("RIG_BATCH_CPU ",JSON.stringify(report));FileAccess.open("res://artifacts/rig-batch-cpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit()
