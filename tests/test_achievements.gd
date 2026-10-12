extends SceneTree
var checks=[]
func check(value:bool,name:String):checks.append({'name':name,'passed':value})
func _initialize():
 var db=load('res://scripts/source_db.gd').new();var save=load('res://scripts/save_store.gd').new(db);save.fresh();save.path='user://achievements-test-isolated.json'
 var p=load('res://scripts/centipede.gd').new(db);var b=load('res://scripts/combat.gd').new(db,p)
 var a=load('res://scripts/achievements.gd').new(db,save,p,b)
 for spec in [['Core_Shield','ACH_SHIELD_5'],['Core_FuelTank','ACH_FUEL_5'],['Core_Chip_Mammoth','ACH_CHIPS_6']]:
  var core=db.named(spec[0]);p.reset();save.state.achievements=[]
  if core.is_empty():check(false,'Source core exists '+spec[0]);continue
  for i in range(4):p.parts.append(p.make_part(core.id,Vector2i(i-4,0)))
  a.check_build();check(spec[1] not in save.state.achievements,'Below threshold '+spec[1])
  p.parts.append(p.make_part(core.id,Vector2i(-5,0)));a.check_build();check(spec[1] in save.state.achievements,'Source five-core threshold '+spec[1])
 p.reset();save.state.achievements=[]
 for i in range(49):b.special.mines.append({})
 a.check_build();check('ACH_MINES_50' not in save.state.achievements,'Forty-nine active mines below threshold')
 b.special.mines.append({});a.check_build();check('ACH_MINES_50' in save.state.achievements,'Fifty active mines unlock achievement')
 b.drones=[]
 for i in range(25):b.add_drone(0,db.asset(db.stores.PlayerDataStore.playerDronesList[0]))
 a.check_build();check('ACH_HIVEMIND' in save.state.achievements,'Twenty-five HQ drones unlock hivemind')
 var report={'checks':checks,'passed':checks.all(func(c):return c.passed)}
 FileAccess.open('res://artifacts/achievement-test-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
