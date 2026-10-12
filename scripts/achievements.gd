extends RefCounted
var db
var save
var player
var combat
func _init(source,store,body,battle):db=source;save=store;player=body;combat=battle
func unlock(id:String):
 if id not in save.state.achievements:save.state.achievements.append(id);save.save()
func check_build():
 var counts={'shield':0,'fuel':0,'chips':0,'drones':0}
 for i in range(player.parts.size()):
  var p:Dictionary=player.parts[i]
  if p.hp<=0:continue
  var c:Dictionary=db.asset(p.id)
  if c.get('class')=='ShieldCore':counts.shield+=1
  if c.get('class')=='FuelCore':counts.fuel+=1
  if c.has('coreChip'):counts.chips+=1
  if c.get('class')=='DroneCore':counts.drones+=int(c.DroneCount)
  if player.chips(i).size()>=4:unlock('ACH_SUPERWEAPON')
 for rule in [['shield',5,'ACH_SHIELD_5'],['fuel',5,'ACH_FUEL_5'],['chips',5,'ACH_CHIPS_6'],['drones',40,'ACH_DRONES_40']]:
  if counts[rule[0]]>=rule[1]:unlock(rule[2])
 if combat.drones.filter(func(d):return d.owner==0).size()>=25:unlock('ACH_HIVEMIND')
 if combat.special.mines.size()>=50:unlock('ACH_MINES_50')
func finish(run):
 var mode:String=run.mode.get('class','')
 if mode=='EndlessModeManager':
  if run.elapsed>=900:unlock('ACH_ENDLESS_15')
  if run.elapsed>=1800:unlock('ACH_ENDLESS_30')
 if run.won:
  var fraction=float(run.director.living_objectives().size())/maxi(1,run.director.initial_objectives)
  if mode=='GAModeManager' and fraction>=1:unlock('ACH_GA100')
  if mode=='SProtectModeManager' and fraction>=0.75:unlock('ACH_SP75')
  if mode=='BHModeManager' and combat.boss_kills==0:unlock('ACH_WEASEL')
 for key in combat.statistics:
  save.state.statistics[key]=int(save.state.statistics.get(key,0))+int(combat.statistics[key])
 save.state.statistics.stat_PacksOpened=int(save.state.statistics.get('stat_PacksOpened',0))+run.opened
 save.state.statistics.stat_ScrapsCollected=int(save.state.statistics.get('stat_ScrapsCollected',0))+run.collected_scraps
