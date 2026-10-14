extends SceneTree
var checks=[]
var captures=[]
func check(value:bool,title:String):
 checks.append({'name':title,'passed':value})
 if not value:push_error(title)
func _initialize():call_deferred('execute')
func settle():
 for i in 4:await process_frame
func key(code:int,shift:bool=false):
 var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.shift_pressed=shift;event.pressed=true;Input.parse_input_event(event);await settle()
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await settle()
func joy(code:int):
 var event=InputEventJoypadButton.new();event.button_index=code;event.pressed=true;Input.parse_input_event(event);await settle()
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await settle()
func capture(tag:String):
 if DisplayServer.get_name()=="headless":return
 await settle()
 await RenderingServer.frame_post_draw
 var file="res://artifacts/ui-overhaul-meta-"+tag+".png"
 var image=root.get_texture().get_image()
 check(image!=null and not image.is_empty(),"Renderer produced "+tag)
 if image==null or image.is_empty():return
 check(image.save_png(file)==OK,"Captured "+tag)
 captures.append({"file":file,"width":image.get_width(),"height":image.get_height()})
func execute():
 # Exercise actual logical viewports, rather than merely stretching a 1440 canvas.
 root.content_scale_size=Vector2i.ZERO
 root.size=Vector2i(1440,900)
 var db=load('res://scripts/source_db.gd').new();var save=load('res://scripts/save_store.gd').new(db);save.fresh();save.path='user://meta-redesign.json'
 var lab=load('res://scripts/research_ui.gd').new();root.add_child(lab);lab.setup(db,save,func():pass,func():pass)
 await process_frame
 check(lab.theme.default_font.resource_path.ends_with('NotoSansCJKsc-Bold.otf'),'Research uses bold Chinese typography')
 check(lab.node_buttons.values().all(func(b):return b.get_theme_stylebox('normal') is StyleBoxTexture),'Research nodes render generated raster panel skins')
 check(lab.node_buttons.size()==db.research.size(),'Every research branch represented in pictorial constellation')
 check(lab.canvas.get_child(0).lines.size()>0,'Prerequisite links shown as constellation paths')
 for b in lab.node_buttons.values():check(b.text.is_empty() and b.icon!=null,'Research node uses actual reward art with tooltip')
 lab.show_detail(db.research[0],0);await process_frame
 check(is_instance_valid(lab.detail),'Research detail opens')
 lab.dismiss_detail();await process_frame
 check(not is_instance_valid(lab.detail),'Detail back returns to constellation')
 for extent in [Vector2i(1280,720),Vector2i(1440,900)]:
  root.size=extent;await settle();lab.fit_screen();await settle()
  check(root.get_visible_rect().encloses(lab.get_global_rect()),'Research screen fits '+str(extent))
  check(lab.get_child(0).get_global_rect().is_equal_approx(root.get_visible_rect()),'Research backdrop fills viewport '+str(extent))
  var suffix='%dx%d'%[extent.x,extent.y]
  await capture('research-'+suffix)
  lab.show_detail(db.research[0],0);await settle()
  await capture('research-detail-'+suffix)
  lab.dismiss_detail();await settle()
 lab.queue_free();await process_frame
 var pool=load('res://scripts/reward_pool_ui.gd').new();root.add_child(pool);pool.setup(db,save,func():pass,func():pass)
 await process_frame
 check(pool.cards.all(func(b):return b.get_theme_stylebox('normal') is StyleBoxTexture),'Codex entries render generated raster skins')
 check(pool.cards.size()==pool.groups.size(),'Every original reward group appears in codex')
 check(pool.cards.all(func(b):return b.icon!=null),'Codex cards use reward illustrations')
 check(pool.unlock_button.visible and not pool.apply_button.visible,'Filter purchase is separate from codex browsing')
 var disabled=save.state.disabled.duplicate();pool.cards[0].pressed.emit();check(save.state.disabled==disabled,'Browsing does not save draft changes')
 save.state.meta=200;pool.action('ResearchSystem','',{});check(pool.apply_button.visible,'Unlock exposes filter controls')
 pool.action('ToggleNoneButton','',{});check(pool.apply_button.disabled,'Cannot apply fewer than five groups')
 # Restore a valid draft for the rendered codex without committing any selection.
 pool.action('ToggleAllButton','',{})
 check(save.state.disabled==disabled,'Rendering fixture leaves the saved reward pool unchanged')
 for extent in [Vector2i(1280,720),Vector2i(1440,900)]:
  root.size=extent;await settle();pool.fit_screen();await settle()
  check(root.get_visible_rect().encloses(pool.get_global_rect()),'Codex fits '+str(extent))
  check(pool.get_child(0).get_global_rect().is_equal_approx(root.get_visible_rect()),'Codex backdrop fills viewport '+str(extent))
  await capture('codex-%dx%d'%[extent.x,extent.y])
 pool.queue_free();await process_frame
 # The mission map uses a real main owner, with an isolated save path.
 root.size=Vector2i(1440,900)
 var game=load('res://main.tscn').instantiate();root.add_child(game);await settle();game.set_process(false)
 game.save.path='user://meta-mission-render.json';game.save.fresh();game.test_mode=true
 game.show_missions();await settle()
 check(game.mission_ui.scene_art is TextureRect and game.mission_ui.scene_art.texture!=null,'Mission hero is generated raster art')
 check(game.mission_ui.scene_textures.size()==6 and game.mission_ui.scene_textures.all(func(t):return t is AtlasTexture and t.atlas.resource_path==game.mission_ui.ART_PATH),'All six mission illustrations come from generated scene atlas')
 check(game.mission_ui.rows.all(func(b):return b.get_child(0) is TextureRect and b.get_child(0).texture!=null and b.get_child(0).size==Vector2(96,64)),'Mission thumbnails display raster illustrations at reserved sizes')
 check(game.mission_ui.rows.all(func(b):return b.get_theme_color('font_color')==load('res://scripts/game_ui.gd').TEXT),'Mission text retains navy contrast')
 var mission_id=game.selected_mission.id;var level=game.difficulty;var meta=game.save.state.meta
 for extent in [Vector2i(1440,900),Vector2i(1280,720)]:
  root.size=extent;await settle();game.mission_ui.layout_board();await settle()
  check(root.get_visible_rect().encloses(game.mission_ui.board.get_global_rect()),'Mission map fits '+str(extent))
  await capture('missions-%dx%d'%[extent.x,extent.y])
 check(game.selected_mission.id==mission_id and game.difficulty==level and game.save.state.meta==meta,'Mission render fixture does not deploy, unlock, or change selection')
 # Input routing must keep a research detail modal ahead of the parent menu handler.
 game.show_lab();await settle()
 var live_lab=game.panel.get_child(0)
 live_lab.show_detail(game.db.research[0],0);await settle()
 var focused=root.gui_get_focus_owner()
 check(focused!=null and live_lab.detail.is_ancestor_of(focused),'Detail starts with focus inside dialog')
 check(live_lab.node_buttons.values().all(func(b):return b.focus_mode==Control.FOCUS_NONE),'Background research nodes cannot take modal focus')
 for backward in [false,true]:
  for i in 12:
   await key(KEY_TAB,backward)
   focused=root.gui_get_focus_owner()
   check(focused!=null and live_lab.detail.is_ancestor_of(focused),'Modal '+('Shift-Tab' if backward else 'Tab')+' remains inside '+str(i))
 await key(KEY_ESCAPE)
 check(game.screen=='lab' and not is_instance_valid(live_lab.detail),'Escape dismisses only the research detail')
 check(live_lab.node_buttons.values().all(func(b):return b.focus_mode==Control.FOCUS_ALL),'Dismissing detail restores background focus')
 live_lab.show_detail(game.db.research[0],0);await settle();await joy(JOY_BUTTON_B)
 check(game.screen=='lab' and not is_instance_valid(live_lab.detail),'Controller B dismisses only the research detail')
 await key(KEY_ESCAPE);check(game.screen=='home','Second Escape leaves research normally')
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={'checks':checks,'captures':captures,'passed' :checks.all(func(c):return c.passed)}
 FileAccess.open('res://artifacts/meta-ui-redesign-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
