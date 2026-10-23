extends SceneTree
const Organs=preload("res://scripts/soft_organ_art.gd")
const Layer=preload("res://scripts/soft_insect_layer.gd")
const Art=preload("res://scripts/insect_armaments.gd")
const Brood=preload("res://scripts/brood_theme.gd")
var checks=[]
class Combat extends RefCounted:
	var enemies=[]
class Game extends Node2D:
	var combat=Combat.new()
	var screen="game"
	var radar_mode=false
	var zoom=1.0
	func world(p:Vector2)->Vector2:return p
class Board extends Node2D:
	var renderer
	var timings=[]
	var frame=0
	var entries=["sonic","cannon","shotgun","sniper","flame","drone_bay"]
	var textures=[]
	func _draw():
		renderer.begin_frame()
		var start=Time.get_ticks_usec()
		for i in 120:
			renderer.paint(self,str(i),textures[i%6],Vector2(80+i%20*60,50+i/20*120),Vector2(56,56),0,entries[i%6],frame/60.0,.18,Color.WHITE,float(i))
		if frame>=5:timings.append(Time.get_ticks_usec()-start)
		frame+=1
class CachedRig extends Node2D:
	var entity:Dictionary
	var death_age=0.0
	func pose(dt:float,dying:bool=false,_compact:bool=false):
		if dying:death_age+=dt
class Probe extends Node2D:
	var renderer=Organs.new()
	var texture:Texture2D
	var bounds=Vector2(120,120)
	var clock=0.0
	var key="probe"
	var variant="sonic"
	var enabled=true
	func _draw():
		renderer.begin_frame()
		if enabled:renderer.paint(self,key,texture,Vector2(250,250),bounds,.2,variant,clock,.18,Color.WHITE,3.7,.4)
func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)
func execute():
	if "--cache-only" in OS.get_cmdline_user_args():
		await verify_hidden_budget()
		var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
		FileAccess.open("res://artifacts/soft-hidden-cache-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print(JSON.stringify(report));quit(0 if report.passed else 1);return
	var max_error=0.0
	for variant in Art.entries():
		for frame in 32:
			var clock=frame*.071;var pulse=[0.0,.18,.07,.001][frame%4]
			var vertices=Organs.deformed_vertices(variant,clock,pulse,3.7,.4,Vector2(70,85))
			for row in 9:
				for col in 9:
					var expected=Organs.deform(Vector2(col/8.0,row/8.0),variant,clock,pulse,3.7,.4)*Vector2(70,85)
					var actual=vertices[row*9+col]
					max_error=maxf(max_error,expected.distance_to(Vector2(actual.x,actual.y)))
	check(max_error<.0001,"All variants retain scalar-reference deformation at all 81 vertices")
	var board=Board.new();board.renderer=Organs.new()
	for variant in board.entries:board.textures.append(Art.texture(variant))
	root.add_child(board)
	for i in 45:board.queue_redraw();await process_frame
	var costs={"optimized_120_organs_ms":average(board.timings)}
	check(board.renderer.meshes.size()==120,"Each visible organ keeps one reusable mesh")
	check(board.renderer.meshes["0"].get_surface_count()==1,"Dynamic poses keep one mesh surface")
	board.renderer=Organs.new();board.renderer.use_vertex_updates=false;board.timings.clear();board.frame=0
	for i in 45:board.queue_redraw();await process_frame
	costs.cached_rebuild_120_organs_ms=average(board.timings)
	var baseline=OS.get_environment("SOFT_RENDER_BASELINE")
	if not baseline.is_empty():
		board.renderer=load(baseline+"/scripts/soft_organ_art.gd").new();board.timings.clear();board.frame=0
		for i in 45:board.queue_redraw();await process_frame
		costs.baseline_120_organs_ms=average(board.timings)
	board.queue_free();await process_frame
	var probe=Probe.new();probe.texture=Art.texture("sonic");root.add_child(probe)
	await process_frame
	var original_mesh=probe.renderer.meshes.probe
	probe.clock=.73;probe.bounds=Vector2(240,280);probe.queue_redraw();await process_frame
	check(original_mesh==probe.renderer.meshes.probe,"Pose and larger bounds reuse mesh object")
	check(probe.renderer.meshes.probe.custom_aabb.size.x>200,"Larger mounts expand conservative culling bounds")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var arrays=probe.renderer.meshes.probe.surface_get_arrays(0)
		var uploaded:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var wanted=Organs.deformed_vertices("sonic",.73,.18,3.7,.4,Organs.Ink.fitted_size(probe.texture,probe.bounds))
		var buffer_error=0.0
		for i in wanted.size():buffer_error=maxf(buffer_error,uploaded[i].distance_to(wanted[i]))
		check(buffer_error<.0001,"GL vertex buffer readback matches changed pose and extent")
		var optimized_image=root.get_texture().get_image()
		optimized_image.save_png("res://artifacts/soft-render-cache-optimized.png")
		if not baseline.is_empty():
			probe.renderer=load(baseline+"/scripts/soft_organ_art.gd").new();probe.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			var reference_image=root.get_texture().get_image()
			reference_image.save_png("res://artifacts/soft-render-cache-baseline.png")
			check(optimized_image.get_data()==reference_image.get_data(),"GL screenshot exactly matches baseline after animation and resize")
			probe.renderer=Organs.new()
	probe.texture=Art.texture("cannon");probe.variant="cannon";probe.queue_redraw();await process_frame
	var cached=probe.renderer.surfaces.probe
	check(cached.source==probe.texture.atlas and cached.region==probe.texture.region,"Same key texture replacement refreshes UV/source cache")
	probe.enabled=false;probe.queue_redraw();await process_frame
	probe.queue_redraw();await process_frame
	check(probe.renderer.meshes.is_empty() and probe.renderer.surfaces.is_empty(),"Unused mesh and surface metadata are pruned together")
	probe.enabled=true;probe.queue_redraw();await process_frame
	check(probe.renderer.meshes.size()==1,"A pruned key can return with a fresh valid surface")
	probe.queue_free();await process_frame
	var game=Game.new();root.add_child(game)
	var layer=Layer.new();game.add_child(layer)
	for i in 24:
		game.combat.enemies.append({"uid":i,"kind":"AISwarmingUnit","position":Vector2(100+i%8*100,100+i/8*100),"angle":0.0,"hp":100.0,"max_hp":100.0,"radius":18.0,"brood_species":Brood.SPECIES[i%6]})
	layer.sync(game,1.0/60)
	var identities={}
	for uid in layer.rigs:identities[uid]=layer.rigs[uid].get_instance_id()
	var start=Time.get_ticks_usec()
	for cycle in 12:
		for actor in game.combat.enemies:actor.position.x+=10000
		layer.sync(game,1.0/60)
		check(layer.rigs.size()==24 and not layer.rigs[0].visible,"Offscreen live rigs retained but not drawn")
		for actor in game.combat.enemies:actor.position.x-=10000
		layer.sync(game,1.0/60)
	costs.optimized_24_rigs_12_reentries_ms=(Time.get_ticks_usec()-start)/1000.0
	var reused=true
	for uid in layer.rigs:reused=reused and identities[uid]==layer.rigs[uid].get_instance_id()
	check(reused,"Reentry reuses each actor rig without rebuilding anatomy")
	game.combat.enemies[0].hp=0;game.combat.enemies.remove_at(0)
	layer.sync(game,.1);check(layer.rigs.has(0),"Visible death animation remains alive")
	layer.sync(game,.3);check(not layer.rigs.has(0),"Completed death rig is released")
	game.combat.enemies.clear();layer.sync(game,.016)
	check(layer.rigs.is_empty(),"Removed actors release cached rigs")
	for i in 32:
		game.combat.enemies.append({"uid":100+i,"kind":"AISwarmingUnit","position":Vector2(100+i%8*35,100+i/8*35),"angle":0.0,"hp":100.0,"max_hp":100.0,"radius":15.0,"brood_species":"grub"})
	layer.sync(game,1.0/60)
	check(layer.rigs[100].compact_pose and layer.rigs[100].compact_sprite.visible and not layer.rigs[100].mesh.visible,"Small distant swarm actors use their original art without drawing hidden skeletons")
	check(layer.rigs[100].compact_sprite.material==layer.rigs[101].compact_sprite.material,"Distant actors share one material rather than allocating it per insect")
	preload("res://scripts/soft_insect.gd").impact(game.combat.enemies[0],Vector2(100,80),Vector2.DOWN,15)
	layer.sync(game,1.0/60)
	check(not layer.rigs[100].compact_pose and layer.rigs[100].mesh.visible and layer.rigs[100].hit_fx.visible,"Impact immediately restores full bones and contact feedback")
	game.combat.enemies[1].position=game.get_viewport_rect().size*.5;layer.sync(game,1.0/60)
	check(not layer.rigs[101].compact_pose,"A small enemy entering the player vicinity restores full anatomy")
	game.combat.enemies[2].hp=0;game.combat.enemies.remove_at(2);layer.sync(game,.1)
	check(layer.rigs.has(102) and not layer.rigs[102].compact_pose and layer.rigs[102].death_age>0,"A distant insect still plays its full death collapse")
	game.combat.enemies.clear();layer.sync(game,.3)
	if not baseline.is_empty():
		layer.free();layer=load(baseline+"/scripts/soft_insect_layer.gd").new();game.add_child(layer)
		for i in 24:game.combat.enemies.append({"uid":i,"kind":"AISwarmingUnit","position":Vector2(100+i%8*100,100+i/8*100),"angle":0.0,"hp":100.0,"max_hp":100.0,"radius":18.0,"brood_species":Brood.SPECIES[i%6]})
		layer.sync(game,1.0/60);start=Time.get_ticks_usec()
		for cycle in 12:
			for actor in game.combat.enemies:actor.position.x+=10000
			layer.sync(game,1.0/60)
			for actor in game.combat.enemies:actor.position.x-=10000
			layer.sync(game,1.0/60)
		costs.baseline_24_rigs_12_reentries_ms=(Time.get_ticks_usec()-start)/1000.0
	game.queue_free();await process_frame
	await verify_hidden_budget()
	var report={"passed":checks.all(func(c):return c.passed),"max_vertex_error_px":max_error,"cpu":costs,"checks":checks}
	FileAccess.open("res://artifacts/soft-render-cache-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
func average(values:Array)->float:
	var sum=0.0
	for value in values:sum+=float(value)
	return sum/maxi(1,values.size())/1000.0

func verify_hidden_budget():
	# Cache ownership/lifecycle does not depend on costly anatomical setup.
	# Lightweight rigs let this 180-actor boundary regression run in milliseconds.
	var game=Game.new();root.add_child(game)
	var layer=Layer.new();game.add_child(layer)
	layer.battle_id=game.combat.get_instance_id()
	for i in 180:
		var e={"uid":i,"kind":"AISwarmingUnit","position":Vector2(10000 if i<80 else 100,100),"hp":100.0,"radius":18.0,"soft_body":{"shock":0.0,"hold":0.0,"flash":0.0}}
		game.combat.enemies.append(e)
		var rig=CachedRig.new();rig.entity=e;layer.add_child(rig);layer.rigs[i]=rig
	layer.sync(game,.016)
	check(layer.hidden_rigs.size()==80 and layer.rigs.size()==180,"Under-budget hidden rigs and all visible rigs are retained")
	# Refresh one old hidden entry, then hide it with the second wave. It must
	# survive eviction while the oldest continuously hidden entries are removed.
	game.combat.enemies[0].position=Vector2(100,100);layer.sync(game,.016)
	for i in 160:game.combat.enemies[i].position=Vector2(10000,100)
	layer.sync(game,.016)
	check(layer.hidden_rigs.size()==Layer.MAX_HIDDEN_RIGS and layer.rigs.size()==Layer.MAX_HIDDEN_RIGS+20,"Hidden cache is capped at 96 while all 20 visible rigs remain")
	check(layer.rigs.has(0) and not layer.rigs.has(1) and not layer.rigs.has(64) and layer.rigs.has(65),"LRU evicts oldest hidden rigs and retains a recently seen rig")
	var visible_preserved=true
	for i in range(160,180):visible_preserved=visible_preserved and layer.rigs.has(i) and layer.rigs[i].visible
	check(visible_preserved,"Cache pressure never deletes visible rigs")
	game.combat.enemies[160].hp=0;game.combat.enemies.remove_at(160)
	layer.sync(game,.1)
	check(layer.rigs.has(160) and layer.rigs[160].death_age>0,"Visible death feedback is retained under cache pressure")
	layer.sync(game,.3)
	check(not layer.rigs.has(160),"Completed visible death feedback is released")
	game.combat.enemies[65].hp=0;game.combat.enemies.remove_at(65)
	layer.sync(game,.016)
	check(not layer.rigs.has(65) and not layer.hidden_rigs.has(65),"Removed hidden dead actors leave both rig cache and LRU")
	game.combat.enemies.clear();layer.sync(game,.016)
	check(layer.rigs.is_empty() and layer.hidden_rigs.is_empty(),"Actor removal clears all cached rigs and LRU entries")
	layer.clear();check(layer.hidden_rigs.is_empty(),"Battle reset clears the hidden cache")
	game.queue_free();await process_frame
