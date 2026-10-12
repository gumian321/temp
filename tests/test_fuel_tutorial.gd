extends SceneTree
var checks=[]
func check(value:bool,name:String):checks.append({'name':name,'passed':value})
func _initialize():call_deferred('execute')
func execute():
 var db=load('res://scripts/source_db.gd').new();var p=load('res://scripts/centipede.gd').new(db)
 p.step(1,Vector2.RIGHT,true);check(not p.boost and p.fuel==0,'No fuel tank means no boost')
 var fuel=db.named('Core_FuelTank');p.add_piece(fuel.id,Vector2i(-1,0));p.step(1,Vector2.ZERO,false)
 check(p.fuel==0,'New empty tank observes recharge delay')
 p.step(2,Vector2.ZERO,false);check(p.fuel>0 and p.max_fuel==float(fuel.fuelCapacity),'Tank supplies capacity and recharges')
 var before=p.fuel;p.step(0.1,Vector2.RIGHT,true);check(p.boost and is_equal_approx(p.fuel,before-5),'Active tank consumes source fifty fuel per second')
 p.parts[1].stun=1;p.step(0.1,Vector2.RIGHT,true);check(not p.boost and p.max_fuel==0,'Stunned tank is removed from active fuel supply')
 var save=load('res://scripts/save_store.gd').new(db);save.fresh();save.path='user://tutorial-test-isolated.json'
 var tutorials=load('res://scripts/tutorial_ui.gd').new();root.add_child(tutorials);tutorials.setup(db,save)
 tutorials.show_tip('move');check(tutorials.shown.has('move') and save.state.tutorials.MoveTutorial==1,'Original first tutorial appears and saves count')
 tutorials.reset_run();tutorials.show_tip('move');check(tutorials.shown.has('move') and save.state.tutorials.MoveTutorial==2,'Second tutorial appearance allowed')
 tutorials.reset_run();tutorials.show_tip('move');check(not tutorials.shown.has('move') and save.state.tutorials.MoveTutorial==3,'Third appearance suppressed by source count rule')
 tutorials.queue_free();await process_frame
 var report={'checks':checks,'passed':checks.all(func(c):return c.passed)}
 FileAccess.open('res://artifacts/fuel-tutorial-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
