extends SceneTree
## Isolated renderer regression: frozen snapshots, visibility and pooled resources.
var game
var checks: Array = []
func _initialize(): call_deferred("execute")
func verify(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok: printerr("FAIL: ",label)
func draw_frame():
	game.queue_redraw()
	await process_frame
	await process_frame
func execute():
	var ground=preload("res://scripts/centipede_fragments_art.gd").GroundBatch
	var joined: Dictionary=ground.connector_profile(58.0)
	var stretched: Dictionary=ground.connector_profile(120.0)
	verify(joined.width==19.0 and joined.alpha==1.0,"Normally spaced segments retain their substantial body connection")
	verify(stretched.width<3.0 and stretched.alpha<0.3 and stretched.bend>0.0,"Stretched recovery links thin, fade and curve instead of forming a rigid bar")
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false);game.save.state.settings.skip_boss=true;game.start_run();game.set_process(false)
	game.combat.enemies.clear();game.combat.bullets.clear()
	game.player.append_segment(game.db.named("Core_Gun_Cannon").id)
	game.player.append_segment(game.db.named("Core_Gun_Tesla").id)
	game.player.append_segment(game.db.named("Core_Gun_Shotgun").id)
	game.player.parts[2].fusion_level=3
	game.test_time=2.5
	game.player_legs.step(game.player,1.0/60)
	game.zoom=1.5;game.camera=game.player.head+Vector2(-70,0)
	await draw_frame()
	var live=game.fragment_art.active_snapshots.duplicate(true)
	game.player.parts[1].hp=0
	game.player.remove_destroyed_parts([1])
	var fragment=game.player.detached_fragments[0]
	var source_bytes=var_to_bytes(fragment)
	await draw_frame()
	verify(game.fragment_art.visible_parts==2,"Both severed surviving bodies render")
	var first=game.fragment_art.batches[0].entries[1]
	verify(first.at==game.world(fragment.poses[0].point),"Dormant body is drawn at its actual world position")
	verify(first.fused and first.feelers.size()==3,"Fused dormant modules retain level-dependent body feelers")
	verify(var_to_bytes(fragment)==source_bytes,"Drawing leaves fragment simulation dictionaries unchanged")
	verify(game.fragment_art.stats().materials==14 and game.fragment_art.stats().batches==15,"Fixed shader/material batch budget")
	var entry=game.fragment_art.batches[0].entries[0]
	var key=entry.key
	var original=game.fragment_art.frozen_snapshots[key].duplicate(true)
	verify(original.clock==2.5,"Organ phase freezes at previous live frame")
	verify(entry.legs==live[int(entry.seed)].legs,"Actual planted leg pose survives severance")
	game.test_time=40
	await draw_frame()
	verify(game.fragment_art.frozen_snapshots[key]==original,"Dormant visual snapshots stay frozen as global time advances")
	game.screen="build"
	await draw_frame()
	verify(not game.fragment_art.visible and game.fragment_art.frozen_snapshots[key]==original,"Hidden assembly screen retains frozen visuals and hides fragment renderer")
	game.screen="game"
	var camera: Vector2=game.camera
	game.camera+=Vector2(10000,10000)
	await draw_frame()
	verify(not game.fragment_art.visible and game.fragment_art.stats().meshes==0,"Offscreen fragments release drawing meshes")
	verify(game.fragment_art.frozen_snapshots[key]==original,"Offscreen culling retains the frozen limb pose")
	game.camera=camera
	fragment.state="waking";fragment.wake_age=.24
	fragment.poses[0].activation=.6;fragment.poses[1].activation=.12
	await draw_frame()
	verify(game.fragment_art.batches[7].entries.size()==1 and game.fragment_art.batches[1].entries.size()==1,"Separate segments select sequential wake material stages")
	verify(game.fragment_art.organs.meshes.size()<=2,"One cached organ mesh per detached module across stage changes")
	game.player.reset()
	await draw_frame()
	verify(game.fragment_art.stats().frozen_snapshots==0 and game.fragment_art.stats().meshes==0,"New-run reset clears stale identities and organ meshes")
	verify(not game.fragment_art.visible,"Empty renderer stays hidden")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear()
	game.queue_free();await process_frame;await process_frame
	var report={"passed":checks.all(func(check):return check.passed),"checks":checks,"scope":"Production renderer state and resource lifetime; visible shader pixels are checked separately by the native fragment-recovery scene."}
	FileAccess.open("res://artifacts/fragment-art-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
