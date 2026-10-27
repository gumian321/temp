extends SceneTree
## Native-renderer A/B. A failed maximum-channel gate rejects this prototype.
const Prototype=preload("res://scripts/radar_icon_batch.gd")
const Brood=preload("res://scripts/brood_theme.gd")
const DB=preload("res://scripts/source_db.gd")
const UI=preload("res://scripts/game_ui.gd")
const Radar=preload("res://scripts/tactical_radar.gd")
const Art=preload("res://scripts/charcoal_art.gd")
var checks:Array=[]
class Board extends Node2D:
	var sources:Dictionary={}
	var prototype=Prototype.new()
	var optimized=false
	var icons:Array=[]
	func _ready():texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	func _draw():
		prototype.enabled=optimized;prototype.begin(self)
		draw_rect(get_viewport_rect(),Color("34333b"))
		var bounds=Radar.bounds(get_viewport_rect().size)
		draw_rect(bounds.grow(-12),Color("080808"));draw_style_box(Art.panel_skin(),bounds)
		draw_rect(bounds.grow(-12),Color(UI.MUTED,.12),false,1.0)
		for icon in icons:
			var source:Texture2D=sources[icon.key]
			var extent=source.get_size();extent*=float(icon.pixels)/maxf(extent.x,extent.y)
			var rect=Rect2(icon.at-extent*.5,extent)
			if not prototype.paint(self,source,rect,icon.tint):
				prototype.interrupt();draw_texture_rect(source,rect,false,icon.tint)
		draw_circle(bounds.get_center(),4,UI.TEAL)
		prototype.finish()

func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)
func picture(board:Board,optimized:bool)->Dictionary:
	board.optimized=optimized;board.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	await process_frame;await RenderingServer.frame_post_draw
	return {"image":root.get_texture().get_image(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func compare(reference:Image,actual:Image)->Dictionary:
	var a=reference.get_data();var b=actual.get_data();var maximum=0;var changed=0;var sum=0
	for i in a.size():
		var difference=absi(int(a[i])-int(b[i]));maximum=maxi(maximum,difference);sum+=difference
		if difference>0:changed+=1
	return {"maximum_channel_error":maximum,"changed_channels":changed,"mean_channel_error":float(sum)/a.size()}
func fixture(board:Board,overlap:bool,fractional:bool):
	board.icons.clear();var bounds=Radar.bounds(root.size);var keys=board.sources.keys()
	for i in 96:
		var local=Vector2(15+(i%12)*12,15+(i/12)*14)
		if overlap:local=Vector2(50+(i%8)*3,35+(i/8)*2)
		if fractional:local+=Vector2(.37,.61)+Vector2(i%3*.19,i%5*.13)
		board.icons.append({"key":keys[i%keys.size()],"at":bounds.position+local,"pixels":13.0 if i%7==0 else 8.0,"tint":Color.WHITE if str(keys[i%keys.size()]).begins_with("brood:") else (UI.AMBER if i%3==0 else UI.TEXT)})
func execute():
	if DisplayServer.get_name()=="headless":push_error("Radar atlas requires a native renderer");quit(1);return
	var board=Board.new();root.add_child(board)
	for species in Brood.SPECIES:board.sources["brood:"+species]=Brood.texture("enemy_"+species)
	var db=DB.new()
	for id in db.stores.AIDataStore.threatsLevelSprites:
		if not board.sources.has("threat:"+str(id)):board.sources["threat:"+str(id)]=db.sprite(id)
	var cases=[]
	for dimensions in [Vector2i(1440,900),Vector2i(960,640)]:
		root.size=dimensions;await process_frame
		for overlap in [false,true]:
			for fractional in [false,true]:
				fixture(board,overlap,fractional)
				var old=await picture(board,false);var now=await picture(board,true)
				var row=compare(old.image,now.image)
				row["viewport"]=[dimensions.x,dimensions.y];row["overlap"]=overlap;row["fractional"]=fractional;row["native_draw_calls"]=old.draw_calls;row["atlas_draw_calls"]=now.draw_calls
				cases.append(row)
				check(row.maximum_channel_error<=1,"Radar atlas max channel error <=1 at "+str(dimensions)+" overlap="+str(overlap)+" fractional="+str(fractional))
				if dimensions.x==1440 and overlap and fractional:
					old.image.save_png("res://artifacts/radar-icon-batch-reference.png");now.image.save_png("res://artifacts/radar-icon-batch-prototype.png")
	check(cases.all(func(row):return row.atlas_draw_calls<=row.native_draw_calls) and cases.any(func(row):return row.atlas_draw_calls<row.native_draw_calls),"Real draw calls decrease while order and pixels stay intact")
	board.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fixture(board,true,true);var fallback_old=await picture(board,false);var fallback_new=await picture(board,true)
	check(compare(fallback_old.image,fallback_new.image).maximum_channel_error<=1 and fallback_old.draw_calls==fallback_new.draw_calls,"Different filtering falls back to native commands and material")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"sources":board.prototype.sources.size(),"cases":cases,"scope":"Original images and native regions sampled together, with the actual radar CanvasLayer's linear filter, exact order and clipping. Original mip chains untouched. Source/group/capacity or unsupported-filter cases retain native drawing."}
	FileAccess.open("res://artifacts/radar-icon-batch.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("RADAR_ICON_ATLAS ",JSON.stringify(report))
	board.queue_free();await process_frame;quit(0 if report.passed else 1)
