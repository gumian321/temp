extends "res://tests/test_centipede_scene.gd"
const Crystal=preload("res://scripts/crystal_loot.gd")

func capture(label:String):
	game.queue_redraw();await process_frame;await process_frame
	if DisplayServer.get_name()=="headless":return null
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image()
	var path="res://artifacts/"+label+".png"
	check(image.save_png(path)==OK,"Captured "+label);captures.append(path)
	return image

func colored_pixels(image:Image,at:Vector2,radius:int)->int:
	var count=0
	for y in range(maxi(0,int(at.y)-radius),mini(image.get_height(),int(at.y)+radius)):
		for x in range(maxi(0,int(at.x)-radius),mini(image.get_width(),int(at.x)+radius)):
			var color=image.get_pixel(x,y)
			if color.s>.45 and color.v>.35:count+=1
	return count

func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	game.start_run();game.set_process(false)
	game.combat.enemies.clear();game.combat.loot.clear();game.combat.effects.clear()
	game.run.timers={"swarm":999.0,"wave":999.0,"patrol":999.0}
	var victim=game.combat.spawn(game.db.pool["55"],game.player.head+Vector2(160,100))
	victim.unit=victim.unit.duplicate(true);victim.unit.scrapsCount=26;victim.unit.rewardPacksList=[]
	victim.guns=[];victim.hp=0;victim.mission_controlled=true
	game.combat.enemies=[victim]
	game.combat.step(.01,Vector2.RIGHT,false,false)
	check(game.combat.loot.map(func(d):return d.value)==[20,5,1],"Real enemy death creates three value-coded crystals totaling 26")
	game.combat.step_scraps(.5)
	game.camera=game.player.head;game.test_time=2.0
	for i in game.combat.loot.size():game.combat.loot[i].position=game.player.head+Vector2((i-1)*150,100)
	for z in [.6,1.0]:
		game.zoom=z
		var image=await capture("energy-crystals-zoom-"+str(z))
		if image!=null:
			for drop in game.combat.loot:
				check(colored_pixels(image,game.world(drop.position),25)>35,"Crystal %d stays visibly colored above death effects at zoom %.1f"%[drop.value,z])
	game.zoom=1.0
	var carried:Dictionary={}
	for frame in 2000:
		game.combat.step_drones(.02)
		for drop in game.combat.loot:
			if drop.get("carried",false):carried=drop;break
		if not carried.is_empty():break
	check(not carried.is_empty(),"Collector picks up a real generated crystal")
	if not carried.is_empty():
		var image=await capture("energy-crystals-carried")
		if image!=null:check(colored_pixels(image,game.world(carried.position)+Vector2(0,12),20)>25,"Carried crystal stays visible beneath the collector")
		var value=int(carried.value)
		for frame in 2000:
			game.combat.step_drones(.02)
			if carried.get("delivered",false):break
		check(carried.get("delivered",false),"Collector returns crystal to the player")
		game.run.step(.01)
		check(game.run.collected_scraps>=value and not game.combat.loot.has(carried),"Delivered crystal grants its energy and disappears")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear()
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for i in 12:await process_frame
	game.queue_free();await process_frame;await process_frame
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/crystal-loot-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
