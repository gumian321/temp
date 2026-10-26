extends SceneTree
## Verify imported production art and show every weapon/branch/projectile route.
const Art=preload("res://scripts/insect_armaments.gd")
const Branches=preload("res://scripts/mutation_branches.gd")
const Mutation=preload("res://scripts/mutation_weapon_art.gd")
const Projectiles=preload("res://scripts/insect_projectiles.gd")
const Wet=preload("res://scripts/viscous_projectiles.gd")
const Ink=preload("res://scripts/blue_ink.gd")
const DB=preload("res://scripts/source_db.gd")
var checks:Array=[]

class Board extends Node2D:
	var font:Font=load("res://assets/fonts/NotoSansSC-Light.otf")
	var items:Array=[]
	var title=""
	var columns=7
	func _draw():
		draw_rect(Rect2(0,0,1536,1130),Color("161c2a"))
		draw_string(font,Vector2(30,42),title,HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("f2e7cc"))
		draw_string(font,Vector2(30,76),"保留造型 · 去高光 · 简化纹理 · 轻微阴影    大图与实际小尺寸",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("9baec2"))
		var cell_width=1480.0/columns
		for i in items.size():
			var at=Vector2(28+(i%columns)*cell_width,100+(i/columns)*166)
			draw_rect(Rect2(at,Vector2(cell_width-8,156)),Color("212a3a"))
			var texture:Texture2D=items[i].texture
			if texture==null:continue
			var extent=Ink.fitted_size(texture,Vector2(cell_width-48,106))
			draw_texture_rect(texture,Rect2(at+Vector2(cell_width*.44,57)-extent*.5,extent),false)
			var small=Ink.fitted_size(texture,Vector2(32,32))
			draw_texture_rect(texture,Rect2(at+Vector2(cell_width-31,107)-small*.5,small),false)
			draw_string(font,at+Vector2(10,144),str(items[i].label),HORIZONTAL_ALIGNMENT_LEFT,cell_width-20,15,Color("e4decd"))

func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"name":label})
	if not ok:push_error(label)

func inspect(texture:Texture2D,label:String):
	check(texture is AtlasTexture,label+" uses an atlas region")
	if not texture is AtlasTexture:return
	var extent=Rect2(Vector2.ZERO,texture.atlas.get_size())
	check(extent.encloses(texture.region),label+" crop stays inside the atlas")
	var image=texture.atlas.get_image().get_region(Rect2i(texture.region))
	check(image.get_used_rect().has_area(),label+" imported crop contains visible art")
	for size in [24,32,56,96]:
		var fitted=Ink.fitted_size(texture,Vector2.ONE*size)
		check(is_equal_approx(fitted.x/texture.get_width(),fitted.y/texture.get_height()),label+" keeps proportions at "+str(size))

func capture(items:Array,title:String,path:String,columns:int):
	if DisplayServer.get_name()=="headless":return
	var viewport=SubViewport.new();viewport.size=Vector2i(1536,1130)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var board=Board.new();board.items=items;board.title=title;board.columns=columns
	board.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;viewport.add_child(board)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(path)==OK,"Captured "+path.get_file())
	viewport.queue_free();await process_frame

func execute():
	var db=DB.new();Ink.register_game_colors(db)
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/matte_style_generation.json"))
	check(manifest.assets.size()==14,"All fourteen production atlases are included")
	for asset in manifest.assets:
		var path="res://"+str(asset.path)
		var source:Texture2D=load(path)
		var raw=Image.load_from_file(ProjectSettings.globalize_path(path))
		check(source!=null and raw!=null,"Replacement imports: "+str(asset.path))
		if source==null or raw==null:continue
		var imported=source.get_image()
		check(imported.get_size()==raw.get_size(),"Importer preserves atlas dimensions: "+str(asset.path))
		var corners=[Vector2i.ZERO,Vector2i(imported.get_width()-1,0),Vector2i(0,imported.get_height()-1),imported.get_size()-Vector2i.ONE]
		check(corners.all(func(p):return imported.get_pixelv(p).a<.03),"Transparent margins: "+str(asset.path))
	var weapons:Array=[]
	for key in Art.entries():
		var texture=Art.texture(key);inspect(texture,key)
		check(texture.atlas.resource_path==Art.atlas_path(key),"Runtime weapon uses replacement: "+key)
		weapons.append({"texture":texture,"label":Art.entries()[key].zh})
	for branch in Branches.DEFINITIONS:
		var texture=Branches.texture(branch);inspect(texture,branch)
		weapons.append({"texture":texture,"label":Branches.DEFINITIONS[branch].zh})
	check(weapons.size()==42,"All 36 base organs and six evolution branches are covered")
	var bullets:Array=[]
	for key in ["mucus","egg","larva","tongue","emp","blackhole","mucus_splat","egg_burst","goo_bead","wet_trail"]:
		var texture=Wet.texture(key);inspect(texture,key)
		bullets.append({"texture":texture,"label":key})
	for key in ["gatling","shotgun","cannon","flak","rocket","nuke","emp","blackhole","sonic"]:
		var texture=Projectiles.texture(key);inspect(texture,"insect-"+key)
		bullets.append({"texture":texture,"label":"insect / "+key})
	for key in ["toxin","boneblade","parasite","toxin_branches","boneblade_branches","parasite_branches"]:
		for cell in range(2 if key.ends_with("_branches") else 1,4):
			var texture=Mutation.texture(key,cell);inspect(texture,key+str(cell))
			bullets.append({"texture":texture,"label":key.replace("_branches","+")+" / "+str(cell)})
	check(bullets.size()==34,"All 34 active projectile/contact variants are covered")
	await capture(weapons,"武器与进化分支 · 游戏实装贴图","res://artifacts/matte-weapons-lineup.png",7)
	await capture(bullets,"弹体与命中特效 · 游戏实装贴图","res://artifacts/matte-projectiles-lineup.png",7)
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"atlases":14,"weapons":weapons.size(),"projectile_variants":bullets.size(),"renderer":DisplayServer.get_name()}
	FileAccess.open("res://artifacts/matte-art-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
