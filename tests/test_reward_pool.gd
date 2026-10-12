extends SceneTree
var checks=[]
func check(value:bool,name:String):
 checks.append({'name':name,'passed':value})
 if not value:push_error(name)
func _initialize():call_deferred('execute')
func execute():
 var db=load('res://scripts/source_db.gd').new();var save=load('res://scripts/save_store.gd').new(db)
 save.fresh();save.path='user://pool-test-isolated.json'
 var ui=load('res://scripts/reward_pool_ui.gd').new();root.add_child(ui);ui.setup(db,save,func():pass,func():pass)
 check(ui.groups.size()>20,'Original reward groups loaded')
 check(not save.unlock_reward_pool(150),'Cannot buy system without funds')
 save.state.meta=200
 check(save.unlock_reward_pool(150) and save.state.meta==50,'Unlock costs source 150')
 check(not save.unlock_reward_pool(150) and save.state.meta==50,'Cannot purchase twice')
 ui.action('ToggleNoneButton','',{})
 check(not save.apply_reward_pool(ui.groups,ui.draft),'Reject fewer than five enabled groups')
 check(save.state.disabled.is_empty(),'Draft toggles do not modify saved pool')
 var eligible=[]
 for group in ui.groups:
  if group[0] in save.state.unlocked:eligible.append(group)
 check(eligible.size()>=6,'Source default unlocks permit group selection')
 for i in range(5):ui.draft[eligible[i][0]]=true
 check(save.apply_reward_pool(ui.groups,ui.draft),'Five groups accepted')
 check(eligible[5].all(func(id):return id in save.state.disabled),'All tiers of disabled group saved together')
 var restored=load('res://scripts/save_store.gd').new(db);restored.path=save.path;restored.load_save()
 check(restored.state.systems.get('ToggleResearches',false) and restored.state.disabled==save.state.disabled,'System and groups restored from disk')
 ui.queue_free();await process_frame
 var report={'checks':checks,'passed':checks.all(func(c):return c.passed)}
 FileAccess.open('res://artifacts/reward-pool-test-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
