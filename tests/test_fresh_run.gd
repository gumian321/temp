extends SceneTree
func _initialize():call_deferred('execute')
func execute():
 var db=load('res://scripts/source_db.gd').new();var save=load('res://scripts/save_store.gd').new(db);save.fresh();save.path='user://fresh-run-test.json'
 var p=load('res://scripts/centipede.gd').new(db);var b=load('res://scripts/combat.gd').new(db,p)
 var m=db.named('Survival Mission');var r=load('res://scripts/run_state.gd').new(db,save,p,b,m,0)
 var cells=[]
 for y in range(-5,6):
  for x in range(-5,6):cells.append(Vector2i(x,y))
 cells.sort_custom(func(a,c):return a.length_squared()<c.length_squared())
 var rewards_chosen=[];var frame=0
 while not r.finished and r.elapsed<r.duration+10:
  # Automated player decisions only: no injected modules, currency, health, kills, timers or mission callbacks.
  if r.packs>0:
   var offers=r.roll_rewards().filter(func(reward):return r.can_reward(reward))
   offers.sort_custom(func(a,c):return priority(db,a)>priority(db,c))
   if not offers.is_empty():rewards_chosen.append(offers[0].name);r.take_reward(offers[0])
   else:r.rewards.recycle()
  while not p.pending.is_empty():
   var placed=false
   for cell in cells:
    if p.add_piece(p.pending[0],cell):p.pending.pop_front();placed=true;break
   if not placed:break
  for action in p.actions:
   while int(p.actions[action])>0:
    var acted=false
    for i in range(1,p.parts.size()):
     if action=='wall' and p.reinforce(i):acted=true;break
     if action=='swap' and p.swap_piece(i,1 if i!=1 else 2):acted=true;break
     for cell in cells:
      if (action=='move' and p.move_piece(i,cell)) or (action=='duplicate' and p.duplicate_piece(i,cell)):acted=true;break
     if acted:break
    if not acted:break
  var target=b.nearest(p.head,1800)
  var delta:Vector2=target.get('position',p.head+Vector2.RIGHT*300)-p.head
  var move=delta.normalized() if delta.length()>650 else delta.normalized().orthogonal()
  if target.is_empty():move=Vector2.from_angle(r.elapsed*0.02)
  var near_drops=b.loot.filter(func(d):return not d.has('reserved_by') and d.position.distance_to(p.head)<400)
  if not near_drops.is_empty() and delta.length()>350:move=(near_drops[0].position-p.head).normalized()
  var dt=1.0/30
  p.step(dt,move,delta.length()<250);b.step(dt,target.get('position',p.head+move*500),true);r.step(dt);b.audio_events.clear();frame+=1
  if frame%600==0:print('fresh ',roundi(r.elapsed),'s parts ',p.parts.size(),' HP ',roundi(p.parts[0].hp),' rewards ',r.opened);await process_frame
 var report={'fixture':'Fresh default save, source initial HQ and drones only. Automated targeting, movement, reward selection and legal construction. No injected equipment or outcome.','won':r.won,'finished':r.finished,'seconds':r.elapsed,'hp':p.parts[0].hp,'parts':p.parts.size(),'rewards':rewards_chosen,'bosses_destroyed':b.boss_kills}
 FileAccess.open('res://artifacts/fresh-run-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit()
func priority(db,reward:Dictionary)->int:
 var kind=reward.get('class','')
 if kind=='BlockReward':
  var core=db.asset(reward.blockCore)
  if core.has('coreProjectile'):return 100
  if core.get('class')=='ShieldCore':return 90
  if core.get('class')=='DroneCore':return 80
  return 50
 if kind=='MainCoreTurretReward':return 70
 if kind=='MainCoreDroneReward':return 60
 if 'LevelUp'in kind:return 40
 if kind=='PercentBasicReward':return 30
 return 10
