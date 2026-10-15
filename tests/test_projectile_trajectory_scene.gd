extends SceneTree
## Real Combat.fire/step and WeaponFX routes; isolated visual fixtures, not a live battle.
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/grid_centipede.gd")
const Combat=preload("res://scripts/combat.gd")
const FX=preload("res://scripts/weapon_fx.gd")
const Feedback=preload("res://scripts/weapon_feedback.gd")
const ENTRIES=[
	["gatling","Core_Gun_Gatling"],["shotgun","Core_Gun_Shotgun"],["cannon","Core_Gun_Cannon"],["flak","Core_Gun_Flak"],
	["rocket","Core_Gun_Rocket"],["nuke","Core_Gun_Nuke"],["emp","Core_Gun_EMP"],["blackhole","Core_Gun_BlackHoler"],
	["sonic","Core_Gun_SonicWave"],["rail","Core_Gun_Sniper"],["tesla","Core_Gun_Tesla"],["flame","Core_Gun_Flame Thrower"]]
class Board extends Node2D:
	var fixtures:Array=[]
	var font:Font=load("res://assets/fonts/NotoSansSC-Light.otf")
	var fx=FX.new()
	var phase=0.0
	var panel_origin=Vector2.ZERO
	var view_scale=.24
	func _ready():texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func world(at:Vector2)->Vector2:return panel_origin+at*view_scale
	func _draw():
		draw_rect(Rect2(0,0,1440,900),Color("f5f2e7"))
		draw_string(font,Vector2(24,34),"连续弹道 / 喷射黏液 · 实际开火与更新 · %.2f 秒"%phase,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("213b6e"))
		draw_string(font,Vector2(24,60),"轨迹按各武器速度缩小，弹体单独放大用于观察；灰线是第一发真实采样，非游戏拖尾。",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("5e6c7e"))
		for index in fixtures.size():
			var f:Dictionary=fixtures[index]
			var origin=Vector2(12+(index%4)*357,78+(index/4)*270)
			draw_rect(Rect2(origin,Vector2(349,260)),Color("d4d2c6"),false,1.0)
			draw_string(font,origin+Vector2(12,27),Feedback.profile(f.key).label,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("213b6e"))
			panel_origin=origin+Vector2(44,110);view_scale=f.view_scale
			draw_line(panel_origin,origin+Vector2(330,110),Color("d8d7cf"),1.0,true)
			if f.trace.size()>1:
				var trace=PackedVector2Array()
				for point in f.trace:trace.append(world(point))
				draw_polyline(trace,Color("a9b0af"),1.1,true)
			for bullet in f.battle.bullets:fx.paint_projectile(self,bullet,phase,1.35)
			fx.paint(self,f.battle,phase,1.0)
			draw_string(font,origin+Vector2(12,241),"%.2f s  ·  %s"%[phase,"连续喷射" if f.key=="flame" else ("锁定后平滑转向" if f.key in ["rocket","nuke"] else "固定中心线")],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("5e6c7e"))
func _initialize():call_deferred("execute")
func execute():
	root.size=Vector2i(1440,900)
	var db=DB.new();var board=Board.new()
	for entry in ENTRIES:
		var body=Body.new(db);var battle=Combat.new(db,body)
		var core=db.named(entry[1]);var key=entry[0]
		var target_at=Vector2(190,0) if key in ["rail","tesla","flame"] else Vector2(600,300)
		var target=battle.spawn(db.pool["250"],target_at)
		target.guns=[];target.hp=100000;target.max_hp=100000;target.kind="Asteroid";target.unit={};target.radius=18.0
		var view_scale=.65 if key in ["rocket","nuke"] else (1.4 if key in ["rail","tesla"] else (.7 if key=="flame" else .20))
		board.fixtures.append({"battle":battle,"core":core,"key":key,"view_scale":view_scale,"trace":[],"primary":{}})
	root.add_child(board)
	var snapshots:Array=[]
	var frames_to_capture=[5,11,21,33,45,59]
	for frame in 60:
		for f in board.fixtures:
			var battle=f.battle
			if f.key=="flame":battle.special.continuous(f.core,Vector2.ZERO,Vector2.RIGHT,true,{},0,1.0/60.0,"fixture_flame")
			elif frame%18==0:battle.fire(f.core,Vector2.ZERO,Vector2.RIGHT,true,{})
			if f.primary.is_empty() and not battle.bullets.is_empty():f.primary=battle.bullets[0]
			battle.step(1.0/60.0,Vector2(600,300),false,false)
			if not f.primary.is_empty() and float(f.primary.life)>0:f.trace.append(f.primary.position)
			battle.audio_events.clear()
		board.phase=(frame+1)/60.0;board.queue_redraw();await process_frame
		if frame in frames_to_capture:
			await process_frame
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				var path="res://artifacts/projectile-continuity-%03d.png"%int(round(board.phase*1000))
				if root.get_texture().get_image().save_png(path)!=OK:printerr("ERROR: capture failed ",path);quit(1);return
				snapshots.append(path)
	var report={"passed":true,"renderer":DisplayServer.get_name(),"native_capture":DisplayServer.get_name()!="headless","families":ENTRIES.map(func(e):return e[0]),"snapshots":snapshots,"scope":"Actual fire/step and draw routes for the twelve gun families, six frame samples; trajectory scale and 1.35x body magnification are explicitly separate for inspection. Not a live combat performance benchmark."}
	FileAccess.open("res://artifacts/projectile-trajectory-scene-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PROJECTILE_TRAJECTORY_SCENE ",JSON.stringify(report));quit(0)
