extends SceneTree
func _initialize():
 var db=load('res://scripts/source_db.gd').new();var p=load('res://scripts/centipede.gd').new(db);var b=load('res://scripts/combat.gd').new(db,p)
 var target=Vector2(0,600)
 for i in range(120):p.step(1.0/60,Vector2.ZERO,false);b.step(1.0/60,target,true)
 var shots=int(b.statistics.get('stat_BulletsFired',0))
 var error=absf(angle_difference(p.parts[0].angle,(target-p.head).angle()))
 var report={'shots':shots,'angle_error':error,'passed':shots>0 and error<0.01,'scenario':'Stationary head turns HQ gun ninety degrees while centipede path updates at 60 Hz'}
 FileAccess.open('res://artifacts/turret-tracking-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
