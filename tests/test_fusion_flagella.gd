extends "res://tests/test_chain_ui_redesign.gd"
const Body=preload("res://scripts/chain_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Flagella=preload("res://scripts/flagella.gd")

func grow_tier(body, id:String, tier:int)->Dictionary:
	if tier==1:
		body.append_segment(id)
		return body.parts[-1]
	var a=grow_tier(body,id,tier-1)
	var b=grow_tier(body,id,tier-1)
	check(body.merge_parts(body.parts.find(a),body.parts.find(b)),"Two tier %d elements fuse"%(tier-1))
	return b

func measure_special(db, name:String, tier:int)->float:
	var p=Body.new(db);var b=Battle.new(db,p)
	var core=db.named(name)
	var part=grow_tier(p,core.id,tier)
	var index=p.parts.find(part)
	p.parts[0].stun=100;part.angle=0
	var e=b.spawn(db.pool["250"],p.weapon_origin(index)+Vector2(50,0))
	e.mission_controlled=true;e.guns=[];e.components=[];e.hp=100000;e.max_hp=100000;e.warp=0.0
	if name=="Core_MinesField":
		b.enemies.clear();b.special.step(0.001)
		e.position=b.special.mines[0].position;b.enemies.append(e)
		b.special.step(0.001)
	elif name=="Core_Drones_Attack":
		b.drones.clear();b.add_drone(index,db.asset(core.coreDrone))
		var d=b.drones[0];d.target=e;d.mode="attack";d.position=e.position-Vector2(1,0);d.docked=false
		b.step_drones(0.001)
		return b.bullets[0].damage if not b.bullets.is_empty() else -1
	else:b.step(0.1,Vector2.RIGHT*1000,false)
	return 100000-e.hp

func execute():
	root.size=Vector2i(1440,900)
	game=load("res://main.tscn").instantiate();root.add_child(game);await settle()
	game.set_process(false);game.test_mode=true;game.save.state.settings.skip_boss=true;game.start_run();game.set_process(false)
	var db=game.db
	var id=db.named("Core_Gun_Gatling").id
	var body=Body.new(db)
	var battle=Battle.new(db,body)
	var source=grow_tier(body,id,1)
	var target=grow_tier(body,id,1)
	var drone=db.asset(db.stores.PlayerDataStore.playerDronesList[0])
	battle.add_drone(1,drone);battle.add_drone(2,drone)
	var survivor=battle.drones[-1]
	check(body.merge_parts(1,2) and body.parts.size()==2 and target.fusion_level==2,"Mounted fusion consumes exactly one segment and keeps target identity")
	check(battle.drones.has(survivor) and survivor.owner==1 and battle.drones.filter(func(d):return d.owner==1).size()==1,"Fusion removes consumed owner's drones and remaps surviving owners")
	check(not body.merge_parts(0,1) and not body.merge_parts(1,1),"Head and self fusion are rejected")
	var tier3=grow_tier(body,id,3)
	var tier4=grow_tier(body,id,4)
	check(not body.can_merge(target,tier3),"Mixed tiers cannot fuse")
	var another4=grow_tier(body,id,4)
	check(not body.can_merge(tier4,another4),"Fourth tier is capped without consuming either segment")
	for tier in range(1,5):
		var p=Body.new(db);var b=Battle.new(db,p)
		var evolved=grow_tier(p,id,tier)
		var index=p.parts.find(evolved)
		p.parts[0].stun=100
		var victim=b.spawn(db.pool["250"],p.weapon_origin(index)+Vector2(150,0))
		victim.mission_controlled=true;victim.guns=[];victim.hp=100000;victim.max_hp=100000
		evolved.angle=0
		b.step(0.001,Vector2.RIGHT*1000,false)
		var friendly=b.bullets.filter(func(shot):return shot.friendly)
		var base=float(db.asset(db.asset(id).coreProjectile).projectileDamage.hullDamage)
		check(not friendly.is_empty() and is_equal_approx(friendly[0].damage,base*pow(2.2,tier-1)),"Actual automatic tier %d projectile has correct attack multiplier"%tier)
		if not friendly.is_empty():
			var hp=float(victim.hp);b.hit_enemy(victim,friendly[0])
			check(is_equal_approx(hp-victim.hp,base*pow(2.2,tier-1)),"Tier %d damage reaches enemy health"%tier)
		for frame in 60:p.step(1.0/60,Vector2.RIGHT,false)
		check(p.flagella.poses(int(evolved.feedback_uid)).size()==2*(tier-1),"Tier %d adds one symmetric pair per fusion"%tier)
		check(is_equal_approx(evolved.max_hp,float(db.asset(id).CoreHealth)*pow(1.6,tier-1)),"Tier %d health survives refresh"%tier)
	for name in ["Core_Gun_Flame Thrower","Core_MinesField","Core_Drones_Attack"]:
		var normal=measure_special(db,name,1)
		var evolved=measure_special(db,name,2)
		check(normal>0 and is_equal_approx(evolved/normal,2.2),"Fusion scales actual special attack: "+name)
	var hole=db.kind("BlackHoleProjectile")[0]
	battle.special.add_black_hole({"data":hole,"position":Vector2.ZERO,"damage":22.0,"shield_damage":44.0,"chips":{},"friendly":true})
	check(battle.special.black_holes[-1].damage==22 and battle.special.black_holes[-1].shield_damage==44,"Persistent vortex retains evolved projectile damage")
	var rig=Flagella.new()
	for frame in 60:rig.step(0,Vector2.ZERO,0,2,true,1.0/60,frame/60.0)
	var before=rig.poses(0)[0].duplicate()
	rig.step(0,Vector2(3,0),0.2,2,true,1.0/60,1.0)
	var after=rig.poses(0)[0]
	check(after[0]==Vector2(12,-22) and after[-1].distance_to(before[-1])>1,"Head flagella keep pinned roots and inertial tips through turning")
	var links_ok=true
	for i in range(1,after.size()):links_ok=links_ok and absf(after[i].distance_to(after[i-1])-164.0/15)<0.001
	check(links_ok,"Every flagellum link retains its length")
	for is_head in [true,false]:
		for fps in [30,60,120]:
			var returning=Flagella.new()
			var dt=1.0/fps
			var at=Vector2.ZERO
			for frame in fps:
				at=Vector2(frame*150.0/fps,cos(frame*4.0/fps)*50)
				returning.step(0,at,frame*2.0/fps,2 if is_head else 4,is_head,dt,frame*dt,150.0)
			var last=returning.poses(0)[0][-1]
			var first_delta=0.0
			var stop_frames=int(ceil(1.6*fps))
			for frame in range(stop_frames):
				returning.step(0,at,2.0,2 if is_head else 4,is_head,dt,1+(frame+1)*dt,0.0)
				if frame==0:first_delta=last.distance_to(returning.poses(0)[0][-1])
			var clock=1+stop_frames*dt
			var settled=returning.poses(0)
			var max_error=0.0
			for strand in settled.size():
				max_error=maxf(max_error,Vector2(settled[strand][-1]).distance_to(Flagella.natural_pose(strand,is_head,clock)[-1]))
			# Slower relaxation intentionally trails the continuously moving wave;
			# the tip should still track within 10% of the head strand's length.
			check(max_error<16,"Idle eases back to natural motion within 1.6s at %d FPS, head=%s (error %.2f)"%[fps,is_head,max_error])
			check(first_delta<55,"Stopping blends smoothly instead of snapping: %d FPS"%fps)
			for strand in settled.size():
				var measured=0.0
				for i in range(1,settled[strand].size()):measured+=settled[strand][i].distance_to(settled[strand][i-1])
				check(absf(measured-(164.0 if is_head else 128.0+20.0*int(strand/2)))<.01,"Head and side flagella retain exactly doubled length")
			var tip=settled[0][-1]
			for frame in fps:returning.step(0,at,2.0,2 if is_head else 4,is_head,dt,clock+(frame+1)*dt,0.0)
			check(tip.distance_to(returning.poses(0)[0][-1])>2,"Idle flagella continue natural motion after recovery")

	for name in ["Core_Gun_Gatling","Core_Gun_Cannon","Core_Gun_Gatling","Core_Gun_Tesla"]:game.player.append_segment(db.named(name).id)
	game.show_build_ui();await settle()
	var ui=game.build_ui
	var first=game.player.parts[game.player.part_at(1)]
	var second=game.player.parts[game.player.part_at(2)]
	var canvas=ui.body_canvas
	var start=Vector2(canvas.display_poses[int(second.feedback_uid)].point)
	var destination=ui.insert_targets[4].get_global_rect().get_center()
	await start_drag(ui.segment_buttons[1].get_global_rect().get_center(),destination)
	check(root.gui_is_dragging() and ui.hovered_target=={"kind":"gap","before":4},"Native drag resolves insertion gap before mouse release")
	check(first.segment==1 and second.segment==2,"Drag preview never mutates gameplay order")
	var current=Vector2(canvas.display_poses[int(second.feedback_uid)].point)
	check(current.distance_to(start)>0.1 and current.distance_to(canvas.points[1])>0.1,"Neighbor moves aside through intermediate positions")
	await capture("fusion-01-smooth-reorder")
	await release_at(destination);await settle()
	check(first.segment==3 and second.segment==1,"Release inserts whole segment while preserving neighbor order")
	var merge_source=ui.segment_buttons[3].get_global_rect().get_center()
	var merge_target=ui.segment_buttons[2].get_global_rect().get_center()
	await start_drag(merge_source,merge_target)
	check(ui.hovered_target=={"kind":"merge","segment":2},"Compatible center resolves fusion instead of reordering")
	await capture("fusion-02-merge-preview")
	await release_at(merge_target);await settle()
	check(game.player.segment_count()==3 and game.player.parts[game.player.part_at(2)].fusion_level==2,"Native body drop fuses two identical elements")
	check(game.screen=="build" and is_instance_valid(ui),"Fusion keeps assembly open for manual adjustment")
	var moving=game.player.parts[game.player.part_at(1)]
	destination=ui.insert_targets[4].get_global_rect().get_center()
	await start_drag(ui.segment_buttons[1].get_global_rect().get_center(),destination)
	var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true;Input.parse_input_event(cancel);await process_frame
	await release_at(destination)
	check(moving.segment==1 and game.screen=="build","Escape restores drag without consuming or moving any segment")
	grow_tier(game.player,id,3);grow_tier(game.player,id,4)
	ui.rebuild();await settle();ui.body_canvas.fit()
	for frame in 60:await process_frame
	await capture("fusion-03-evolution-levels")
	game.player.pending=[id]
	ui.rebuild();await settle()
	var level1=game.player.parts[game.player.part_at(1)]
	game.player.pending=[level1.id];ui.rebuild();await settle()
	await drag_at(ui.inventory[0].get_global_rect().get_center(),ui.segment_buttons[1].get_global_rect().get_center());await settle()
	check(game.player.pending.is_empty() and level1.fusion_level==2,"Pending reward can fuse directly onto a matching first-tier segment")
	game.show_game()
	for frame in 120:game.player.step(1.0/60,Vector2.RIGHT.rotated(frame*0.008),false)
	game.camera=game.player.head
	await capture("fusion-04-combat")
	game.player.configure_character("spider")
	var spider_a=grow_tier(game.player,id,1);var spider_b=grow_tier(game.player,id,1)
	game.show_build_ui();await settle()
	ui=game.build_ui
	await drag_at(ui.segment_buttons[spider_a.segment].get_global_rect().get_center(),ui.segment_buttons[spider_b.segment].get_global_rect().get_center());await settle()
	check(game.player.parts.size()==2 and spider_b.fusion_level==2,"Spider mounted elements share the same native fusion interaction")
	await capture("fusion-05-spider")
	game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.process_mode=Node.PROCESS_MODE_DISABLED;game.queue_free();await settle()
	var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/fusion-flagella-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
