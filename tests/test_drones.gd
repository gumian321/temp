extends SceneTree
const DB=preload('res://scripts/source_db.gd')
const Body=preload('res://scripts/centipede.gd')
const Battle=preload('res://scripts/combat.gd')
func _initialize():
 var db=DB.new();var player=Body.new(db);var battle=Battle.new(db,player)
 var drop={'position':Vector2(150,0),'value':3,'pack':false};battle.loot.append(drop)
 var carried=false;var reserved=false;var delivered=false
 for frame in range(2000):
  battle.step_drones(0.02)
  reserved=reserved or drop.has('reserved_by');carried=carried or drop.get('carried',false)
  if drop.get('delivered',false):delivered=true;break
 var report={'reserved':reserved,'carried':carried,'delivered_after_return':delivered,'drones':battle.drones.size(),'position':[drop.position.x,drop.position.y]}
 var ok=reserved and carried and delivered
 report.passed=ok
 FileAccess.open('res://artifacts/drone-test-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if ok else 1)
