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
	check(probe.textures.is_empty() and probe.polygons>=2 and probe.circles==2,"Hostile cell membrane and nucleus survive exhausted budget and zoom out")
	probe=Probe.new();bullet.position=Vector2(-2000,-2000);fx.paint_projectile(probe,bullet,1,1)
	check(probe.textures.is_empty() and probe.transforms==0,"Offscreen shots are culled before atlas rendering")
	var event={"position":Vector2(300,300),"kind":"viscous_contact","organic_family":"egg","direction":Vector2.RIGHT,"radius":7,"life":.4,"fx_duration":.72,"friendly":true}
	probe=Probe.new();fx.paint_effect(probe,event,1)
	check(probe.textures.size()==1 and probe.textures[0]==Wet.texture("egg") and probe.circles==0,"Attached egg swells using generated egg without flash")
	event.kind="egg_burst";event.life=.1;probe=Probe.new();fx.paint_effect(probe,event,1)
	check(probe.textures.size()==1 and probe.textures[0]==Wet.texture("egg_burst"),"Egg detonation uses generated wet burst")
	var chain={"position":Vector2(200,200),"end":Vector2(400,200),"kind":"chain","life":.04,"fx_duration":.22,"fx_family":"tesla","friendly":true}
	probe=Probe.new();fx.paint_effect(probe,chain,1)
	check(probe.textures.size()==2 and probe.lines>=3 and probe.lines<=10 and probe.circles==0,"Friendly Tesla keeps continuous generated filament and tip with bounded three-layer discharge")
	for key in ["rail","tesla","sonic"]:
		var aligned=true
		var bounded=true
		for progress in [0.0,.25,.6,.7,.9,.99]:
			var start=Vector2(100,100);var finish=Vector2(400,300)
			var duration=.22;var reach=1.0 if progress<.64 else pow((1.0-progress)/.36,.75)
			chain={"position":start,"end":finish,"kind":"chain","life":duration*(1-progress),"fx_duration":duration,"fx_family":key,"friendly":true}
			probe=Probe.new();fx.paint_effect(probe,chain,1)
			aligned=aligned and probe.textures.size()==2 and probe.poses.size()==2
			bounded=bounded and probe.circles==0 and probe.polygons==0 and (probe.lines==2 if key=="rail" else (probe.lines==5 if key=="sonic" else probe.lines>=3 and probe.lines<=10))
			if probe.poses.size()==2:
				for pose in probe.poses:
					aligned=aligned and absf(float(pose.heading)-start.direction_to(finish).angle())<.00001 and Geometry2D.get_closest_point_to_segment(pose.position,start,finish).distance_to(pose.position)<.001
				aligned=aligned and Vector2(probe.poses[-1].position).distance_to(start.lerp(finish,reach))<.001
		check(bounded,key+" dynamic accents preserve fixed family draw budget through retraction")
		check(aligned,key+" tongue remains collinear through contact hold and smooth retraction without a V joint")
	# Continuous secretion is now an anchored soft whip, not a stretched sprite.
	for phase in [0.0,.1,.25,.57,.77,1.0]:
		var start=Vector2(220,180);var axis=Vector2.from_angle(.71);var length=336.0
		var stream={"position":start,"end":start+axis*length,"kind":"flame","life":.14,"fx_duration":.14,"fx_family":"flame","friendly":true}
		var original=stream.duplicate(true)
		probe=Probe.new();fx.clock=phase;fx.paint_effect(probe,stream,1)
		check(probe.textures.is_empty() and probe.lines==72 and probe.circles==0,"Friendly soft whip uses a bounded continuous tapered ribbon")
		check(stream==original,"Whip rendering never changes damage state")
		stream.friendly=false;probe=Probe.new();fx.paint_effect(probe,stream,1)
		check(probe.textures.is_empty() and probe.lines==72,"Hostile whip uses the same flexible shape with its danger palette")
	check(Art.texture("rocket").region==Art.REGIONS[Art.CELLS.rocket],"Original atlas API retains exact legacy contract")
	var effects:Array=[]
	for i in 300:effects.append(event)
	probe=Probe.new();fx.paint(probe,{"effects":effects,"special":{"black_holes":[],"mines":[]}},1,1)
	check(probe.textures.size()==FX.MAX_TRANSIENTS,"Contact rendering respects existing global transient cap")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	FileAccess.open("res://artifacts/viscous-renderer-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0 if report.passed else 1)
