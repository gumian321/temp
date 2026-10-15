extends SceneTree
const FX=preload("res://scripts/weapon_fx.gd")
const Wet=preload("res://scripts/viscous_projectiles.gd")
const Art=preload("res://scripts/insect_projectiles.gd")
var checks:Array=[]
class Probe extends RefCounted:
	var textures:Array=[]
	var lines=0
	var circles=0
	var transforms=0
	var poses:Array=[]
	var stamps:Array=[]
	var transform_at=Vector2.ZERO
	var transform_heading=0.0
	var polygons=0
	func world(p):return p
	func get_viewport_rect():return Rect2(0,0,1440,900)
	func draw_set_transform(at,heading=0):
		transforms+=1
		transform_at=at;transform_heading=heading
		if at!=Vector2.ZERO:poses.append({"position":at,"heading":heading})
	func draw_texture_rect(texture,rect,_tile,color):
		textures.append(texture)
		stamps.append({"texture":texture,"rect":rect,"position":transform_at,"heading":transform_heading,"color":color})
	func draw_line(_a,_b,_c,_d,_e=true):lines+=1
	func draw_polyline(_a,_b,_c,_d=true):lines+=1
	func draw_colored_polygon(_a,_b):lines+=1;polygons+=1
	func draw_circle(_a,_b,_c,_d=true,_e=-1,_f=false):circles+=1
	func draw_arc(_a,_b,_c,_d,_e,_f,_g,_h):lines+=1
func check(ok:bool,label:String):
	checks.append({"name":label,"passed":ok})
	if not ok:printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
	var import_config=ConfigFile.new()
	check(import_config.load(Wet.ATLAS_PATH+".import")==OK and bool(import_config.get_value("params","mipmaps/generate",false)),"Imported viscous atlas enables mipmaps for small projectile stability")
	check(Wet.texture("mucus").atlas.get_image().has_mipmaps(),"Runtime viscous atlas retains mip chain after import")
	var fx=FX.new()
	var bullet={"position":Vector2(300,300),"origin":Vector2(200,300),"velocity":Vector2(600,0),"radius":4,"friendly":true,"fx_family":"cannon","data":{}}
	for key in Wet.CELLS:
		var texture=Wet.texture(key)
		check(texture!=null and texture.get_image().get_used_rect().get_area()>0,"Generated transparent asset resolves: "+key)
		if texture!=null:
			var image=texture.get_image()
			var edge=0.0
			for x in image.get_width():edge=maxf(edge,maxf(image.get_pixel(x,0).a,image.get_pixel(x,image.get_height()-1).a))
			for y in image.get_height():edge=maxf(edge,maxf(image.get_pixel(0,y).a,image.get_pixel(image.get_width()-1,y).a))
			check(edge<0.02,"Generated silhouette has transparent crop margin: "+key)
	check(Wet.family({},"gatling")=="mucus" and Wet.family({},"sonic")=="tongue" and Wet.family({},"rocket")=="larva","Fallback mappings match initialized combat families")
	check(Wet.family({},"emp").is_empty() and Wet.family({},"blackhole").is_empty(),"Special spore families keep their original art")
	var pose_ok=true
	for kind in ["mucus","egg","larva","tongue"]:
		for frame in 120:
			var pose=Wet.pose(bullet,kind,frame/60.0)
			pose_ok=pose_ok and pose.is_finite() and pose.x>0.75 and pose.y>0.75 and pose.x<1.3 and pose.y<1.3
	check(pose_ok,"Cheap deterministic body deformation remains finite and restrained")
	var probe=Probe.new();var before=bullet.duplicate(true)
	fx.paint_projectile(probe,bullet,1.0,1.0)
	check(probe.textures.size()==3 and probe.circles==0,"Friendly projectile has one body plus at most two generated wet decorations")
	check(probe.textures[0]==Wet.texture("mucus"),"Actual friendly projectile uses new mucus atlas")
	check(bullet==before,"Visual squish never changes gameplay state")
	probe=Probe.new();fx.draw_count=FX.MAX_PROJECTILES;fx.paint_projectile(probe,bullet,1,1)
	check(probe.textures.size()==1,"Exhausted embellishment budget preserves generated body")
	probe=Probe.new();bullet.friendly=false;fx.paint_projectile(probe,bullet,1,.4)
	check(probe.textures.size()==1 and probe.lines>=6,"Hostile cue and old contrast shell survive exhausted budget and zoom out")
	probe=Probe.new();bullet.position=Vector2(-2000,-2000);fx.paint_projectile(probe,bullet,1,1)
	check(probe.textures.is_empty() and probe.transforms==0,"Offscreen shots are culled before atlas rendering")
	var event={"position":Vector2(300,300),"kind":"viscous_contact","organic_family":"egg","direction":Vector2.RIGHT,"radius":7,"life":.4,"fx_duration":.72,"friendly":true}
	probe=Probe.new();fx.paint_effect(probe,event,1)
	check(probe.textures.size()==1 and probe.textures[0]==Wet.texture("egg") and probe.circles==0,"Attached egg swells using generated egg without flash")
	event.kind="egg_burst";event.life=.1;probe=Probe.new();fx.paint_effect(probe,event,1)
	check(probe.textures.size()==1 and probe.textures[0]==Wet.texture("egg_burst"),"Egg detonation uses generated wet burst")
	var chain={"position":Vector2(200,200),"end":Vector2(400,200),"kind":"chain","life":.04,"fx_duration":.22,"fx_family":"tesla","friendly":true}
	probe=Probe.new();fx.paint_effect(probe,chain,1)
	check(probe.textures.size()==2 and probe.lines==0 and probe.circles==0,"Friendly tongue uses one continuous generated filament and a retracting tip")
	for key in ["rail","tesla","sonic"]:
		var aligned=true
		for progress in [0.0,.25,.6,.7,.9,.99]:
			var start=Vector2(100,100);var finish=Vector2(400,300)
			var duration=.22;var reach=1.0 if progress<.64 else pow((1.0-progress)/.36,.75)
			chain={"position":start,"end":finish,"kind":"chain","life":duration*(1-progress),"fx_duration":duration,"fx_family":key,"friendly":true}
			probe=Probe.new();fx.paint_effect(probe,chain,1)
			aligned=aligned and probe.textures.size()==2 and probe.poses.size()==2
			if probe.poses.size()==2:
				for pose in probe.poses:
					aligned=aligned and absf(float(pose.heading)-start.direction_to(finish).angle())<.00001 and Geometry2D.get_closest_point_to_segment(pose.position,start,finish).distance_to(pose.position)<.001
				aligned=aligned and Vector2(probe.poses[-1].position).distance_to(start.lerp(finish,reach))<.001
		check(aligned,key+" tongue remains collinear through contact hold and smooth retraction without a V joint")
	# Production secretion stream: exact generated route, fixed seven-stamp cap,
	# axial front masses and no visible quad escaping behind the emitter.
	for phase in [0.0,.1,.25,.57,.77,1.0]:
		var start=Vector2(220,180);var axis=Vector2.from_angle(.71);var length=336.0
		var stream={"position":start,"end":start+axis*length,"kind":"flame","life":.04,"fx_duration":.06,"fx_family":"flame","friendly":true}
		var original=stream.duplicate(true)
		probe=Probe.new();fx.clock=phase;fx.paint_effect(probe,stream,1)
		var atlas_only=probe.textures.size()==7 and probe.polygons==0 and probe.lines==0 and probe.circles==0
		var aligned=true;var contained=true;var mucus_count=0;var bead_count=0;var trail_count=0
		for stamp in probe.stamps:
			atlas_only=atlas_only and stamp.texture in [Wet.texture("wet_trail"),Wet.texture("mucus"),Wet.texture("goo_bead")]
			aligned=aligned and absf(float(stamp.heading)-axis.angle())<.00001
			if stamp.texture==Wet.texture("mucus"):
				mucus_count+=1
				aligned=aligned and absf((Vector2(stamp.position)-start).dot(axis.orthogonal()))<.001
			elif stamp.texture==Wet.texture("goo_bead"):bead_count+=1
			else:trail_count+=1
			var rect:Rect2=stamp.rect
			for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
				var world_corner=Vector2(stamp.position)+Vector2(corner).rotated(float(stamp.heading))
				var axial=(world_corner-start).dot(axis)
				contained=contained and axial>=-.001 and axial<=length+.001
		check(atlas_only and mucus_count==3 and bead_count==3 and trail_count==1,"Friendly stream %.2fs uses seven generated stamps without orange polygons or glow"%phase)
		check(aligned and contained and stream==original,"Friendly stream %.2fs is axial and stays within original endpoints without mutating damage state"%phase)
		stream.friendly=false;probe=Probe.new();fx.paint_effect(probe,stream,1)
		check(probe.polygons==3 and probe.lines>=16 and probe.textures.size()>13 and probe.textures.all(func(t):return t==fx.halo_texture),"Hostile flame %.2fs retains existing three-layer cone and danger glow"%phase)
	check(Art.texture("rocket").region==Art.REGIONS[Art.CELLS.rocket],"Original atlas API retains exact legacy contract")
	var effects:Array=[]
	for i in 300:effects.append(event)
	probe=Probe.new();fx.paint(probe,{"effects":effects,"special":{"black_holes":[],"mines":[]}},1,1)
	check(probe.textures.size()==FX.MAX_TRANSIENTS,"Contact rendering respects existing global transient cap")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/viscous-renderer-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
