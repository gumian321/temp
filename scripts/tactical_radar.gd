extends Node2D
## A HUD canvas, above every world effect and below menus. The map retains the
## generated creature sprites rather than replacing them with schematic dots.
const Art=preload("res://scripts/charcoal_art.gd")
const UI=preload("res://scripts/game_ui.gd")
var game
var use_icon_atlas=OS.get_environment("RBPEW_ENABLE_RADAR_ICON_ATLAS")!="0" and OS.get_environment("RBPEW_LEGACY_RADAR_ICON_ATLAS")!="1"
var icon_atlas=preload("res://scripts/radar_icon_atlas.gd").new()
var atlas_attempted=false
var atlas_ready=false
var atlas_sources:Dictionary={}
var retired_icon_resources:Array=[]
var icon_batch=preload("res://scripts/radar_icon_batch.gd").new()

func paint_icon(source:Texture2D,rect:Rect2,tint:Color):
	if icon_batch.paint(self,source,rect,tint):return
	icon_batch.interrupt();draw_texture_rect(source,rect,false,tint)

func prepare_icons(db):
	if not use_icon_atlas:return
	retired_icon_resources.append_array(icon_atlas.mapped.values())
	atlas_attempted=true;atlas_sources.clear()
	for id in db.stores.AIDataStore.threatsLevelSprites:atlas_sources[str(id)]=db.sprite(id)
	atlas_ready=icon_atlas.build(atlas_sources)
	for source in atlas_sources.values():
		if source!=null and not source.changed.is_connected(invalidate_icons):source.changed.connect(invalidate_icons)

func invalidate_icons():atlas_attempted=false;atlas_ready=false

func threat_texture(db,id)->Texture2D:
	var original:Texture2D=db.sprite(id)
	if not use_icon_atlas:return original
	if not atlas_attempted or atlas_sources.get(str(id))!=original:prepare_icons(db)
	if atlas_ready:
		var packed:Texture2D=icon_atlas.texture(str(id))
		if packed!=null:return packed
	return original

static func bounds(viewport_size:Vector2)->Rect2:
	var compact=viewport_size.x<1000 or viewport_size.y<700
	var extent=Vector2(144,120) if compact else Vector2(180,150)
	return Rect2(Vector2(viewport_size.x-extent.x-30,viewport_size.y-extent.y-85),extent)

func _draw():
	icon_batch.begin(self)
	# Keep textures referenced by already-recorded commands until this canvas
	# is redrawn, including an asset invalidation in the middle of a draw.
	retired_icon_resources.clear()
	if game==null or game.run==null or game.screen not in ["game","pause","rewards","result"] or game.radar_mode:icon_batch.finish();return
	var rect=bounds(get_viewport_rect().size)
	# The generated frame has translucent paper edges; the actual map must stay
	# opaque even under large flashes or bright continuous attacks.
	draw_rect(rect.grow(-12),Color("080808"))
	draw_style_box(Art.panel_skin(),rect)
	draw_rect(rect.grow(-12),Color(UI.MUTED,.12),false,1.0)
	var map_scale=rect.size.x/180.0
	for enemy in game.combat.enemies:
		var offset=(Vector2(enemy.position)-game.player.head)*.012
		if offset.length_squared()<70*70:
			game.draw_map_icon(enemy,rect.get_center()+offset*map_scale,(8 if enemy.kind!="AIBossUnit" else 13)*map_scale,true,self)
	draw_circle(rect.get_center(),4,UI.TEAL)
	icon_batch.finish()
