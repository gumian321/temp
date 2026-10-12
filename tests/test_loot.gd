extends SceneTree
var checks=[]
func check(ok,name):checks.append({'name':name,'passed':ok})
func _initialize():
 var db=load('res://scripts/source_db.gd').new();var save=load('res://scripts/save_store.gd').new(db);save.path='user://loot-test.json';save.fresh()
 var p=load('res://scripts/centipede.gd').new(db);var b=load('res://scripts/combat.gd').new(db,p);var r=load('res://scripts/run_state.gd').new(db,save,p,b,db.named('Survival Mission'),0)
 b.spawn_scraps(p.head,3)
 check(b.loot.size()==3 and b.loot.all(func(d):return d.value==1),'Source scrap count produces individual one-value pickups')
 check(b.loot.all(func(d):return d.scatter_left==.5),'Source scatter lasts Very_Short = 0.5 seconds')
 b.step_scraps(.5)
 check(b.loot.all(func(d):return d.position.distance_to(p.head)>=24 and d.position.distance_to(p.head)<=96),'Source scatter radius remains 0.5–2 Unity units')
 for drop in b.loot:drop.position=p.head
 r.step(.01)
 check(b.loot.size()==3 and r.collected_scraps==0,'Proximity does not bypass source drone collection')
 b.loot[0].delivered=true;r.step(.01)
 check(b.loot.size()==2 and r.collected_scraps==1,'Only a returned drone delivery credits the economy')
 b.loot.clear();b.spawn_scraps(Vector2(4000,0),250);b.spawn_scraps(Vector2.ZERO,5)
 check(b.loot.size()==250,'Source cap rejects a subsequent scrap spawn at 250')
 b.step_scraps(.5)
 check(b.loot.size()==244,'Source quarter-second remover removes at most six distant scraps')
 var ok=checks.all(func(c):return c.passed)
 FileAccess.open('res://artifacts/loot-test-report.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'passed':ok},'\t'));print(JSON.stringify(checks));quit(0 if ok else 1)
