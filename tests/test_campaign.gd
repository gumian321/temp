extends SceneTree
const DB=preload('res://scripts/source_db.gd')
const Save=preload('res://scripts/save_store.gd')
const Body=preload('res://scripts/centipede.gd')
const Battle=preload('res://scripts/combat.gd')
const Run=preload('res://scripts/run_state.gd')
var results=[]
func _initialize():call_deferred('execute')
func execute():
 var db=DB.new();var save=Save.new(db);save.path='user://campaign-fixture.json';save.fresh()
 for m in db.kind('Mission'):
  if not OS.get_environment('RBPEW_TEST_MISSION').is_empty() and OS.get_environment('RBPEW_TEST_MISSION') not in m.name:continue
  save.path='user://campaign-'+m.id+'.json'
  var p=Body.new(db);var b=Battle.new(db,p);var r=Run.new(db,save,p,b,m,0)
  # Strong reachable late-run layout; explicit fixture, never alter target HP or invoke victory callbacks.
  var cells=[]
  for y in range(-5,6):
   for x in range(-5,6):
    if not (x in [0,1] and y in [0,1]):cells.append(Vector2i(x,y))
  cells.sort_custom(func(a,c):return a.length_squared()<c.length_squared())
  var weapons=['Core_Gun_Tesla','Core_Gun_Gatling','Core_Gun_Shotgun']
  var built=0
  var balanced=OS.get_environment('RBPEW_BALANCED_FIXTURE')=='1'
  for cell in cells:
   var name='Core_Shield' if built%6==0 else ('Core_Repair' if built%6==1 else weapons[built%3])
   if balanced:
    name='Core_Gun_Sniper' if built%3==0 else weapons[built%3]
    if cell.y>=2 and abs(cell.x)<=2:name='Core_Shield'
    elif cell.y>=1 and abs(cell.x)>=3:name='Core_Drones_Engineer'
    elif cell in [Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,-1),Vector2i(1,-1)]:name='Core_Repair'
    elif cell in [Vector2i(2,0),Vector2i(2,1)]:name='Core_FuelTank'
   var core=db.named(name)
   if not core.is_empty() and p.add_piece(core.id,cell):built+=1
   if built>=(60 if balanced else 40):break
  if balanced:p.hq_weapon=db.named("HQ_Core_Shotgun").id
  for reward in db.catalog.values():
   if 'LevelUp' in str(reward.get('class','')):p.levels[reward.id]=3
  for stat in [2,3,10,13,14,15,16,17]:p.change_stat(stat,1)
  p.refresh_upgrades()
  var limit=r.duration+30
  if r.mode.get('class')=='EndlessModeManager':limit=float(OS.get_environment('RBPEW_ENDLESS_SECONDS')) if not OS.get_environment('RBPEW_ENDLESS_SECONDS').is_empty() else 180.0
  var frame=0;var peak=0
  while not r.finished and r.elapsed<limit:
   var dt=0.05;var target={}
   var objectives=b.enemies.filter(func(e):return e.hp>0 and e.damageable and e.role!='friendly' and (e.objective or (not balanced and e.parent!=0)))
   if not objectives.is_empty():
    objectives.sort_custom(func(a,c):return a.position.distance_squared_to(p.head)<c.position.distance_squared_to(p.head));target=objectives[0]
   if target.is_empty():target=b.nearest(p.head,4000)
   var goal:Vector2=target.get('position',p.head)
   var mode=r.mode.get('class')
   if mode=='GAModeManager':goal=r.director.fleet_position+Vector2(-250,0)
   elif mode=='SProtectModeManager':goal=Vector2.from_angle(r.elapsed*0.03)*200
   var delta=goal-p.head
   var direction=delta.normalized() if delta.length()>(700 if balanced else 400) else delta.normalized().orthogonal()*(1.0 if balanced else 0.5)
   p.step(dt,direction,balanced and target.get("position",p.head).distance_to(p.head)<350);b.step(dt,target.get('position',p.head+Vector2.RIGHT*500),true);r.step(dt)
   b.audio_events.clear();peak=maxi(peak,b.enemies.size());frame+=1
   # This scenario exercises mission combat with a fixed layout, not reward/build interaction (separately tested).
   if frame%200==0:print(m.name,' simulated ',roundi(r.elapsed),'s parts ',p.parts.size(),' targets ',b.enemies.size());await process_frame
  results.append({'mission':m.name,'elapsed':r.elapsed,'finished':r.finished,'won':r.won,'hp':p.parts[0].hp,'parts':p.parts.size(),'peak_entities':peak,'bosses_destroyed':b.boss_kills,'endless_waves':r.director.endless_wave})
  print(JSON.stringify(results[-1]))
 var report={'step_seconds':0.05,'fixture':('60 source modules with shield/engineer/fuel support and HQ shotgun' if OS.get_environment('RBPEW_BALANCED_FIXTURE')=='1' else '40 source modules')+' plus attainable source upgrades; normal enemy/player damage; no direct HP edits, forced kills, timer jumps or victory callbacks. Automated aim/movement. Not a fresh-save playthrough.','results':results}
 FileAccess.open('res://artifacts/'+OS.get_environment('RBPEW_REPORT_NAME')+'campaign-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));quit()
