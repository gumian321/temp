extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Body = preload("res://scripts/grid_centipede.gd")
const Battle = preload("res://scripts/combat.gd")
const Ink = preload("res://scripts/blue_ink.gd")
var checks: Array = []
func check(ok: bool, title: String):
	checks.append({"passed": ok, "name": title})
	if not ok: printerr("FAIL: ", title)
func _initialize():
	var db = DB.new()
	Ink.register_game_colors(db)
	var p = Body.new(db)
	var names = ["Core_Gun_Gatling", "Core_Gun_Cannon", "Core_Shield", "Core_Repair", "Core_Gun_Tesla", "Core_Gun_EMP", "Core_Gun_Flame Thrower", "Core_Gun_Shotgun", "Core_Chip_Mammoth"]
	var gun = db.named("Core_Gun_Gatling").id
	for slot in range(9):
		var core = db.named(names[slot])
		check(not core.is_empty(), "Source module exists: " + names[slot])
		check(p.install_module(core.id, 1, slot), "Free mount accepts weapon/support in slot " + str(slot))
	check(p.parts.size() == 10 and p.segment_count() == 6, "Nine modules occupy one shell without widening or growing the body")
	check(not p.install_module(gun, 1, 4) and not p.install_module(gun, 8, 4), "Occupied slots and skipped tail segments reject installation")
	var center = Vector2(p.segment_pose(1).point)
	check(p.parts.slice(1).all(func(part): return absf(part.position.x-center.x)<=16.01 and absf(part.position.y-center.y)<=16.01), "All nine world mounts stay within the existing 54-pixel shell")
	var positions = {}
	for part in p.parts.slice(1): positions[part.position] = true
	check(positions.size() == 9, "Nine installed modules have distinct world positions")
	check(p.adjacent_part_indices(p.part_at(1,4)).size() == 4, "Center support has exactly four orthogonal grid neighbors")
	var shield = p.parts[p.part_at(1,2)]
	var battle = Battle.new(db,p)
	var target = p.part_at(1,4)
	var hp = p.parts[target].hp
	var charge = shield.shield
	battle.hurt_player(target,10,10)
	check(p.parts[target].hp == hp and shield.shield < charge, "A shield covers a neighboring module at its actual world position")
	var source = p.part_at(1,0)
	p.actions = {"move":1,"swap":1,"duplicate":1,"wall":1}
	check(p.move_to_mount(source,7,4) and p.segment_count()==7 and p.part_at(1,0)<0, "Moving to the tail grows one segment and clears only the old slot")
	check(p.actions.move==0 and not p.move_to_mount(source,1,0), "Move token is consumed once; refused moves preserve placement")
	var other = p.part_at(1,1)
	var source_id = p.parts[source].id
	check(p.swap_piece(source,other) and p.part_at(1,1)==source and p.parts[source].id==source_id, "Swap exchanges mount coordinates while preserving module state")
	check(p.duplicate_to_mount(source,1,0) and p.actions.duplicate==0, "Duplicate creates a module in the chosen empty grid slot")
	var blueprint = p.blueprint()
	check(blueprint.slice(1).all(func(part): return part.has("segment") and part.has("slot")), "Blueprint records both body segment and local slot")
	var survivor = p.parts[p.part_at(1,8)]
	var removed = p.part_at(1,7)
	p.parts.remove_at(removed);p.refresh_positions()
	check(survivor.segment==1 and survivor.slot==8 and p.segment_count()==7, "Destroyed modules leave an empty mount without renumbering survivors or shrinking the body")
	var fit_ok = true
	var texture_count = 0
	for core in db.catalog.values():
		if not core.has("turretSprite"): continue
		var texture = db.sprite(core.turretSprite)
		if texture==null: continue
		texture_count+=1
		for limit in [14.0,27.0,35.0,42.0,65.0]:
			var extent=Ink.fitted_size(texture,Vector2.ONE*limit)
			fit_ok=fit_ok and is_equal_approx(extent.x/texture.get_width(),extent.y/texture.get_height()) and maxf(extent.x,extent.y)<=limit+0.001 and Ink.keeps_color(texture)
	check(fit_ok and texture_count>=20, "All source turret sprites preserve color and aspect ratio in compact, head, world and UI sizes")
	while p.parts.size()<61:
		var free=p.first_free_mount()
		if not p.install_module(gun,free.x,free.y): break
	check(p.parts.size()==61 and not p.install_module(gun,8,4), "Nine-slot construction retains the source 60-module limit")
	var finite=true
	for frame in range(360):
		p.step(1.0/60.0,Vector2.from_angle(floorf(frame/60.0)*PI*.75),false)
		for i in range(1,p.parts.size()):
			var local=(p.parts[i].position-Vector2(p.segment_pose(p.parts[i].segment).point)).rotated(-p.parts[i].body_angle)
			finite=finite and local.distance_to(p.slot_offset(p.parts[i].slot)) < 0.001
	check(finite, "All sixty grid mounts rotate rigidly with their individual shells through hard turns")
	var support = Body.new(db)
	support.install_module(gun,1,4)
	support.install_module(db.named("Core_Chip_Mammoth").id,1,1)
	support.install_module(db.named("Core_Chip_Mammoth").id,1,0)
	check(support.chips(1).get(5,0)==1,"Only the orthogonal chip affects the turret; a diagonal chip does not")
	support.install_module(db.named("Core_Repair").id,1,3)
	support.parts[1].hp-=20
	var damaged=support.parts[1].hp
	var support_battle=Battle.new(db,support)
	support_battle.step(.25,Vector2.RIGHT,false)
	check(support.parts[1].hp>damaged,"Repair heals its neighbor in the same shell")
	support.install_module(gun,2,5)
	check(support.adjacent_part_indices(4).has(5),"Touching grid edges connect support across neighboring body segments")
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed),"turret_textures":texture_count}
	FileAccess.open("res://artifacts/grid-mounts-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
