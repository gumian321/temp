extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Layer=preload("res://scripts/attack_shader_layer.gd")
const FX=preload("res://scripts/weapon_fx.gd")
class Board extends Node2D:
	var db
	var job:Callable
	func _draw():
		draw_rect(get_viewport_rect(),Color("383838"))
		if job.is_valid():job.call()
	func world(at):return at+Vector2(500,400)
	func skill_module_art(family:String,texture:Texture2D,at:Vector2,bounds:Vector2,angle:float=0.0,hostile:bool=false):
		var painter=Layer.route(self,family,hostile)
		var size=preload("res://scripts/blue_ink.gd").fitted_size(texture,bounds)
		painter.draw_set_transform(at,angle);painter.draw_texture_rect(texture,Rect2(-size*.5,size),false,Color.WHITE);painter.draw_set_transform(Vector2.ZERO)
var checks=[]
func check(ok:bool,label:String):
	checks.append({"passed":ok,"name":label})
	if not ok:push_error(label)
func _initialize():call_deferred("execute")
func execute():
	root.size=Vector2i(1440,900)
	var db=DB.new();var player=Body.new(db);var battle=Battle.new(db,player)
	player.append_segment(db.named("Core_MinesField").id)
	player.levels[db.named("Reward_LevelUP_MineField").id]=2
	for i in 30:player.parts[1].cooldown=0;battle.special.step(0)
	battle.effects.clear()
	var board=Board.new();board.db=db;root.add_child(board)
	var layer=Layer.new();layer.trace_commands=true;layer.attach(board)
	var fx=FX.new();var before=battle.special.mines.duplicate(true)
	check(before.size()==30,"The fixture retains all 30 upgraded mines")
	for zoom in [1.0,1.75,.65]:
		for legacy in [true,false]:
			fx.use_mine_batches=not legacy
			board.job=func():
				layer.begin_frame(1.25);fx.paint_mine_sprites(board,battle,zoom);fx.paint(board,battle,1.25,zoom)
			for frame in 3:board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
			var captures="res://artifacts/egg-batch-%s-%s.png"%[str(zoom),"legacy" if legacy else "instanced"]
			root.get_texture().get_image().save_png(captures)
			if not legacy:
				var commands=layer.friendly_batches.mine.batch.commands
				check(commands.filter(func(c):return c[0]==&"draw_multimesh").size()==3,"All 30 egg sprites, rings and halos use three draws at zoom "+str(zoom))
	check(before==battle.special.mines,"Drawing preserves mine owners, positions, slots, life and damage data")
	var ids=fx.egg_visuals.sprites.values().map(func(item):return item.mm.get_instance_id())
	board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	check(ids==fx.egg_visuals.sprites.values().map(func(item):return item.mm.get_instance_id()),"Repeated frames reuse the same MultiMesh resources")
	for i in 15:battle.special.mines[i].friendly=false
	board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	check(layer.hostile_batches.mine.batch.commands.any(func(c):return c[0]==&"draw_multimesh"),"Hostile eggs retain their separate hazard material and layer")
	battle.special.mines.clear();board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	check(layer.friendly_batches.mine.batch.command_count==0 and layer.hostile_batches.mine.batch.command_count==0,"Empty/restarted scenes clear every previous mine drawing command")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/egg-visual-batch-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));board.queue_free();await process_frame;quit(0 if report.passed else 1)
