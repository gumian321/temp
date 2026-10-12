extends SceneTree
var checks=[]
func check(value:bool,label:String):checks.append({'passed':value,'name':label})
func _initialize():
 var db=load('res://scripts/source_db.gd').new();var player=load('res://scripts/centipede.gd').new(db);var battle=load('res://scripts/combat.gd').new(db,player)
 var a=battle.spawn(db.pool['250'],Vector2(100,0));var b=battle.spawn(db.pool['250'],Vector2(200,0));a.max_hp=100;a.hp=10;a.radius=100;b.max_hp=1000;b.hp=50;b.radius=10
 var expected={'ClosetTargetRadarConfiguration':a.uid,'FurthestRadarConfiguration':b.uid,'BiggestTargetRadarConfiguration':b.uid,'SmallestTargetRadarConfiguration':a.uid,'LowestHealthTargetRadarConfiguration':b.uid,'StunnedRadarConfiguration':b.uid}
 for type in expected:
  var config=db.kind(type)[0];var target=battle.target_for({'radarConfiguration':config.id},Vector2.ZERO,500)
  check(target.get('uid',0)==expected[type],type+' source selection')
 var config=db.kind('LowestHealthTargetRadarConfiguration')[0];a.hp=a.max_hp;b.hp=b.max_hp
 check(battle.target_for({'radarConfiguration':config.id},Vector2.ZERO,500).is_empty(),'Fully healthy targets excluded by source repair radar')
 b.guns.append({'id':db.named('Core_Shield').id,'shield':100});config=db.kind('ClosetTargetRadarConfiguration')[0]
 check(battle.target_for({'radarConfiguration':config.id},Vector2.ZERO,500).uid==b.uid,'Live shield priority precedes closest hull')
 b.guns[-1].shield=0
 check(battle.target_for({'radarConfiguration':config.id},Vector2.ZERO,500).uid==a.uid,'Broken shield does not take target priority')
 var report={'checks':checks,'passed':checks.all(func(c):return c.passed)}
 FileAccess.open('res://artifacts/radar-test-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
