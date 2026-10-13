extends SceneTree
const DB=preload('res://scripts/source_db.gd')
const Save=preload('res://scripts/save_store.gd')
const Body=preload('res://scripts/centipede.gd')
const Battle=preload('res://scripts/combat.gd')
var checks=0
var failures=[]
func check(ok,message):
 checks+=1
 if not ok:failures.append(message);printerr(message)
func _initialize():call_deferred('execute')
func execute():
 var db=DB.new();var player=Body.new(db);var battle=Battle.new(db,player)
 battle.fire(db.named('HQ_Core_Shotgun'),Vector2.ZERO,Vector2.RIGHT,true)
 var directions={}
 for b in battle.bullets:directions[snappedf(Vector2(b.velocity).angle(),0.001)]=true
 check(directions.size()>3,'Shotgun projectiles follow distinct source barrel angles')
 var emp=db.kind('EMPBasicProjectile')[0]
 battle.hit_player(0,{'data':emp,'damage':1.0,'shield_damage':1.0,'velocity':Vector2.RIGHT})
 check(player.parts[0].stun==float(emp.stunDuration),'EMP actually stuns player gun')
 var shield=db.named('Core_Shield');player.add_piece(shield.id,Vector2i(-1,0));player.parts[1].shield=100
 var before=player.parts[0].hp;battle.hurt_player(0,100,20)
 check(player.parts[0].hp==before and player.parts[1].shield==80,'Shield absorbs damage before hull')
 var save=Save.new(db);save.path='user://recovery-isolated.json';save.fresh();save.state.meta=91;save.save();save.state.meta=72;save.save()
 FileAccess.open(save.path,FileAccess.WRITE).store_string('{broken')
 save.fresh();check(save.load_save() and save.state.meta==91,'Malformed primary save restores last valid atomic backup')
 save.state.settings.volume=0.23;save.reset_progress();check(save.state.meta==55 and save.state.settings.volume==0.23,'Reset clears progress and preserves settings')
 var audio=load('res://scripts/audio_system.gd').new();root.add_child(audio);audio.setup(db,save)
 audio.sync_loops([{'key':'boost','type':41,'position':Vector2.ZERO}])
 check(audio.loops.size()==1 and audio.loops.boost.playing,'Source boost loop starts')
 audio.sync_loops([]);check(audio.loops.is_empty(),'Loop stops when effect ends')
 audio.shutdown()
 # Drain the audio mixer in wall time before freeing its streams/bus. Frame
 # timers may advance faster than the mixer in an isolated headless fixture.
 for i in 12:OS.delay_msec(10);await process_frame
 audio.queue_free();await process_frame;await process_frame
 var report={'checks':checks,'passed':checks-failures.size(),'failures':failures,'scope':'Source barrel geometry, player EMP, shield interception, backup recovery, reset semantics and looped audio lifecycle.'}
 FileAccess.open('res://artifacts/regression-test-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(1 if not failures.is_empty() else 0)
