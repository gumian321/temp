extends SceneTree
const DB = preload("res://scripts/source_db.gd")
const Art = preload("res://scripts/insect_armaments.gd")
const Ink = preload("res://scripts/blue_ink.gd")
var checks: Array = []
func check(ok: bool, label: String):
	checks.append({"name":label,"passed":ok})
	if not ok: printerr("FAIL: ",label)
func _initialize():
	var db = DB.new()
	Ink.register_game_colors(db)
	var regions: Dictionary = {}
	for key in Art.entries():
		var texture = Art.texture(key)
		check(texture is AtlasTexture, "Generated texture exists: " + key)
		if texture == null: continue
		regions[texture.atlas.resource_path + str(texture.region)] = true
		check(Ink.keeps_color(texture), "Anatomical organ colors survive UI shader: " + key)
		check(Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region), "UV region stays within generated atlas: " + key)
		var image = texture.atlas.get_image().get_region(Rect2i(texture.region))
		check(image.detect_alpha() != Image.ALPHA_NONE, "Transparent anatomical silhouette: " + key)
		for size in [18,28,42,56,78,96]:
			var fit = Ink.fitted_size(texture,Vector2.ONE*size)
			check(is_equal_approx(fit.x/texture.get_width(),fit.y/texture.get_height()), "Preserve silhouette ratio at %d px: %s" % [size,key])
	check(regions.size() == 36, "All 36 identities use different atlas regions")
	for value in db.catalog.values():
		var key = db.armament_variant(value)
		if key.is_empty(): continue
		if value.has("coreTurret") or value.has("coreChip"): check(db.core_sprite(value) == Art.texture(key), "Mounted/HQ/enemy core art routed: " + value.name)
		if "Reward" in str(value.get("class", "")):
			var expected=preload("res://scripts/mutation_branches.gd").texture(str(value.mutation_branch)) if value.has("mutation_branch") else Art.texture(key)
			check(db.reward_sprite(value)==expected,"Reward/research art routed: "+value.name)
		for field in ["droneSprite","mineSprite","turretSprite","chipSprite"]:
			if value.has(field): check(db.sprite(value[field]) == Art.texture(key), "Direct sprite ID routed: " + value.name)
	var report = {"checks":checks,"passed":checks.all(func(c):return c.passed),"distinct_regions":regions.size()}
	FileAccess.open("res://artifacts/insect-armaments-art-routes-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("INSECT_ART_ROUTES ",checks.size()," ",report.passed)
	quit(0 if report.passed else 1)
