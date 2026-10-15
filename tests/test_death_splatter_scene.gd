extends SceneTree
## Shared current/baseline fixture. Dynamic loads let this identical file execute
## on dc9ef75 without changing any baseline production source.
const AGES=[0.02,0.09,0.2,0.4,0.8]
const SIZES=[18.0,36.0,60.0]
const NAMES=["SMALL", "LARGE", "BOSS"]
const WARMUP=20
const FRAMES=60
class Counter extends RefCounted:
	var calls=0
	var textures=0
	var lines=0
	func world(at):return at
	func get_viewport_rect():return Rect2(0,0,1440,900)
	func draw_set_transform(_a,_b=0):calls+=1
	func draw_texture_rect(_a,_b,_c,_d):calls+=1;textures+=1
	func draw_line(_a,_b,_c,_d,_e=true):calls+=1;lines+=1
	func draw_circle(_a,_b,_c,_d=true,_e=-1,_f=false):calls+=1
	func draw_colored_polygon(_a,_b):calls+=1
	func draw_polyline(_a,_b,_c,_d=true):calls+=1
	func draw_arc(_a,_b,_c,_d,_e,_f,_g,_h):calls+=1
class Board extends Node2D:
	var fx
	var burst_script
	var dense=false
	var age=0.09
	var font:Font=load("res://assets/fonts/NotoSansSC-Light.otf")
	var samples=[]
	var fixture
	func _ready():texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func world(at):return at
	func label(at,text,size=17):draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("213b6e"))
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("f5f2e7"))
		if dense:
			label(Vector2(25,35),"384 SIMULTANEOUS DEATHS  |  %.2f s  |  %s"%[age,"WET SPRAY" if burst_script!=null else "BASELINE EXPLOSIONS"],22)
			var started=Time.get_ticks_usec()
			fx.paint(self,fixture,age,0.75)
			samples.append((Time.get_ticks_usec()-started)/1000.0)
		else:
			label(Vector2(25,35),"ENEMY DEATH STAGES  |  Generated wet atlas / production WeaponFX.paint()",23)
			for col in AGES.size():
				label(Vector2(150+col*270,80),"%.2f s"%AGES[col],22)
			for row in 3:
				label(Vector2(30,130+row*255),NAMES[row]+"  r=%.0f"%SIZES[row],18)
				for col in AGES.size():
					var center=Vector2(160+col*270,200+row*250)
					draw_line(center+Vector2(-70,98),center+Vector2(70,98),Color("b3b2a6"),1)
					fx.paint(self,fixture[row][col],AGES[col],0.65)
var revision=""
var output=""
var death_script
var fx
var visual_only=false
func _initialize():call_deferred("execute")
func stats(values:Array)->Dictionary:
	var ordered=values.duplicate();ordered.sort();var total=0.0
	for value in values:total+=float(value)
	return {"mean":total/maxi(1,values.size()),"p50":ordered[ordered.size()/2],"p95":ordered[mini(ordered.size()-1,int(ordered.size()*0.95))],"max":ordered[-1]}
func make_battle(count:int,age:float,single:Dictionary={})->Dictionary:
	var result={"effects":[],"special":{"black_holes":[],"mines":[]}}
	if death_script!=null:result.death_splatters=[]
	for i in count:
		var e={"kind":"AIBossUnit" if i%48==47 else "AISwarmingUnit","radius":60.0 if i%48==47 else SIZES[i%48/24],"position":Vector2(42+(i%24)*59,90+(i/24)*49),"uid":i+1,"last_death_direction":Vector2.from_angle(float(i)*2.39996323)}
		if not single.is_empty():e=single.duplicate()
		if death_script!=null:
			var effect=death_script.make_effect(e);effect.life=effect.fx_duration-age
			if effect.life>0:result.death_splatters.append(effect)
		else:
			var effect=load("res://scripts/weapon_feedback.gd").decorate({"kind":"explosion","position":e.position,"radius":float(e.radius)*2,"life":0.65},"impact",true)
			effect.life-=age
			if effect.life>0:result.effects.append(effect)
	return result
func capture(path:String)->bool:
	var err=root.get_texture().get_image().save_png(path)
	if err!=OK:push_error("Capture failed: "+path)
	return err==OK
func execute():
	visual_only=OS.get_environment("RBPEW_DEATH_VISUAL_ONLY")=="1"
	if FileAccess.file_exists("res://scripts/enemy_death_splatter.gd"):death_script=load("res://scripts/enemy_death_splatter.gd")
	fx=load("res://scripts/weapon_fx.gd").new()
	revision=OS.get_environment("RBPEW_REVISION")
	output=OS.get_environment("RBPEW_DEATH_OUTPUT")
	if output.is_empty():output="res://artifacts/death-splatter-round12"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var cpu=[];var native=[];var counter=Counter.new()
	for age in ([] if visual_only else AGES):
		var battle=make_battle(384,age)
		for frame in WARMUP:fx.paint(counter,battle,age,0.75)
		var timings=[];counter.calls=0;counter.textures=0;counter.lines=0
		for frame in 120:
			var started=Time.get_ticks_usec();fx.paint(counter,battle,age,0.75);timings.append((Time.get_ticks_usec()-started)/1000.0)
		cpu.append({"age_s":age,"draw_build_ms":stats(timings),"commands_per_frame":counter.calls/120.0,"texture_rects_per_frame":counter.textures/120.0,"lines_per_frame":counter.lines/120.0,"retained_effects":battle.get("death_splatters",battle.effects).size()})
	var report={"fixture":"death-only 384 simultaneous organic deaths; same test source on current and dc9ef75; no simulation/particles/audio","revision":revision,"variant":"wet_splatter" if death_script!=null else "baseline_explosion","ages_s":AGES,"cpu_stub_draw_command_construction":cpu,"cpu_note":"CPU function/construction time and submitted Canvas methods; not GPU draw calls or user hardware FPS.","display":DisplayServer.get_name(),"screenshots":[],"native":native}
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(1440,900));root.size=Vector2i(1440,900)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
		var board=Board.new();board.fx=fx;board.burst_script=death_script;root.add_child(board)
		var rows=[]
		for row in 3:
			var cells=[]
			for col in AGES.size():
				cells.append(make_battle(1,AGES[col],{"kind":"AIBossUnit" if row==2 else "AISwarmingUnit","radius":SIZES[row],"position":Vector2(160+col*270,200+row*250),"uid":13+row,"last_death_direction":Vector2.RIGHT}))
			rows.append(cells)
		board.fixture=rows;board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		var sheet=output+"-stages.png"
		if not capture(sheet):quit(1);return
		report.screenshots.append(sheet)
		var rigs=[]
		for row in 3:
			for col in AGES.size():
				var entity={"uid":13+row,"kind":"AIBossUnit" if row==2 else "AISwarmingUnit","radius":SIZES[row],"position":Vector2(160+col*270,200+row*250),"angle":0.0,"hp":0.0,"max_hp":100.0,"brood_species":["grub","beetle","queen"][row]}
				var rig=load("res://scripts/soft_insect_rig.gd").new();board.add_child(rig);rig.setup(entity)
				rig.position=entity.position;rig.scale=Vector2.ONE*maxf(38.0,SIZES[row]*2.7)*0.5*0.65
				rig.pose(AGES[col],true);rigs.append(rig)
		board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		var body_sheet=output+"-rig-stages.png"
		if not capture(body_sheet):quit(1);return
		report.screenshots.append(body_sheet)
		for rig in rigs:rig.queue_free()
		await process_frame
		board.dense=true
		for age in AGES:
			board.age=age;board.fixture=make_battle(384,age);board.samples.clear()
			var frame_times=[];var draw_calls=[];var objects=[]
			for frame in (2 if visual_only else WARMUP+FRAMES):
				if frame==WARMUP:board.samples.clear()
				var started=Time.get_ticks_usec();board.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
				if frame>=(0 if visual_only else WARMUP):
					frame_times.append((Time.get_ticks_usec()-started)/1000.0)
					draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			native.append({"age_s":age,"frame_ms":stats(frame_times),"draw_build_ms":stats(board.samples),"native_draw_calls":stats(draw_calls),"render_objects":stats(objects)})
			var path=output+"-dense-%03d.png"%int(round(age*1000))
			if not capture(path):quit(1);return
			report.screenshots.append(path)
		report.renderer=RenderingServer.get_video_adapter_name();report.viewport=[1440,900];report.native_note="Visual-only smoke: timing not benchmark evidence." if visual_only else "Static fixed-age production FX, 20 warmup and 60 measured native frames per stage; software renderer/compositor timing is not user hardware FPS."
	FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DEATH_SPLATTER_SCENE_OK ",JSON.stringify(report));quit(0)
