extends SceneTree
const DB=preload('res://scripts/source_db.gd')
const Save=preload('res://scripts/save_store.gd')
const Body=preload('res://scripts/centipede.gd')
const Battle=preload('res://scripts/combat.gd')
const Run=preload('res://scripts/run_state.gd')
var results=[]
func _initialize():call_deferred('execute')
func execute():
 var db=DB.new();var save=Save.new(db);save.path='user://simulation-isolated.json';save.fresh()
 for mission in db.kind('Mission'):
  var player=Body.new(db);var battle=Battle.new(db,player);var run=Run.new(db,save,player,battle,mission,0)
  for i in range(4):player.add_piece(db.named('Core_Gun_Gatling').id,Vector2i(0,-i-1))
  var max_enemies=0;var max_bullets=0;var restarts=0
  for frame in range(2400):
   if run.finished:break
   var dt=0.1
   var direction=Vector2.from_angle(frame*0.002)
   player.step(dt,direction,false)
   var target=battle.nearest(player.head,1200)
   battle.step(dt,target.get('position',player.head+direction*500),true)
   run.step(dt)
   battle.audio_events.clear()
   max_enemies=maxi(max_enemies,battle.enemies.size());max_bullets=maxi(max_bullets,battle.bullets.size())
   if frame%100==0:await process_frame
  if not run.finished:run.finish(false)
  results.append({'mission':mission.name,'simulated_seconds':run.elapsed,'won':run.won,'score':run.result.score,'peak_enemies':max_enemies,'peak_projectiles':max_bullets,'parts_left':player.parts.size()})
  print(JSON.stringify(results[-1]))
 var report={'scope':'Six source missions with normal damage, continuous movement and fire; four starting test modules. Stops on death or 240 seconds. Not a full victory playthrough.','results':results}
 var f=FileAccess.open('res://artifacts/simulation-report.json',FileAccess.WRITE);f.store_string(JSON.stringify(report,'\t'));f.close();quit()
