extends SceneTree
func _initialize():call_deferred('execute')
func execute():
 var db=load('res://scripts/source_db.gd').new();var script_path=OS.get_environment('RBPEW_BATTLE_SCRIPT');var battle_script=load(script_path if script_path!='' else 'res://scripts/combat.gd');var all_snapshots=[]
 for scenario in ['Core_Gun_Gatling','Core_Gun_Tesla','Core_Gun_SonicWave','Core_Gun_BlackHoler']:
  seed(20261012)
  var core=db.named(scenario)
  if core.is_empty():continue
  var p=load('res://scripts/centipede.gd').new(db);var b=battle_script.new(db,p)
  for cell in [Vector2i(-1,0),Vector2i(-2,0),Vector2i(-1,-1),Vector2i(-2,-1)]:p.add_piece(core.id,cell)
  for i in range(20):
   var enemy=b.spawn(db.pool['250'],Vector2(-600+i*65,-150+(i%3)*150));enemy.hp=1000.0;enemy.max_hp=1000.0
  for frame in range(180):
   p.step(1.0/60,Vector2.from_angle(frame/60.0),false);b.step(1.0/60,p.head+Vector2.RIGHT*600,true);b.audio_events.clear()
   if frame%30==0:
    var enemies=[];var bullets=[];var parts=[]
    for e in b.enemies:enemies.append([e.uid,e.position.x,e.position.y,e.hp,e.stun])
    for shot in b.bullets:bullets.append([shot.position.x,shot.position.y,shot.velocity.x,shot.velocity.y,shot.damage,shot.life,shot.hit])
    for part in p.parts:parts.append([part.cell.x,part.cell.y,part.hp,part.shield,part.position.x,part.position.y,part.angle])
    all_snapshots.append({'scenario':scenario,'frame':frame,'enemies':enemies,'bullets':bullets,'parts':parts,'kills':b.kills,'rng_state':str(b.rng.state)})
 var file=FileAccess.open(OS.get_environment('RBPEW_COMPARISON_OUTPUT'),FileAccess.WRITE);file.store_string(JSON.stringify(all_snapshots));file.close();print('SNAPSHOTS ',all_snapshots.size());quit()
