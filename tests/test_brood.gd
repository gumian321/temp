extends SceneTree
const DB=preload("res://scripts/source_db.gd")
const Body=preload("res://scripts/grid_centipede.gd")
const Battle=preload("res://scripts/combat.gd")
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
const Rig=preload("res://scripts/soft_insect_rig.gd")
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,title:String):
	checks.append({"name":title,"passed":value})
	if not value:printerr("FAIL: ",title)
func specimen(species:String)->Dictionary:
	return {"uid":1,"kind":"AISwarmingUnit","position":Vector2.ZERO,"angle":-PI/2,"hp":100.0,"max_hp":100.0,"radius":30.0,"brood_species":species}
func simulate(fps:int)->Dictionary:
	var e=specimen("grub")
	Soft.impact(e,Vector2(-24,0),Vector2.RIGHT,30)
	for i in int(fps*0.25):Soft.step(e,1.0/fps)
	return e
func execute():
	var db=DB.new()
	var paths:Dictionary={}
	for v in db.catalog.values():
		if not str(v.name).begins_with("Turret_Gun_"):continue
		var sprite=db.sprite(v.turretSprite)
		check(sprite is AtlasTexture and "armaments_atlas_" in sprite.atlas.resource_path,"Generated weapon: "+v.name)
		paths[sprite.atlas.resource_path+str(sprite.region)]=true
	check(paths.size()==12,"All twelve ranged weapon families have distinct new art")
	for species in Brood.SPECIES:
		var e=specimen(species)
		Soft.impact(e,Vector2(-24,0),Vector2.RIGHT,30)
		check(e.soft_body.peak>.015 and e.soft_body.recoil.x>.06 and e.soft_body.hold>=.04,"Immediate first-frame dent, directional kick and short hold: "+species)
		var first=e.soft_body.offset.duplicate()
		Soft.step(e,1.0/120)
		check(first==e.soft_body.offset,"Contact compression holds before rebound: "+species)
		for i in range(12):Soft.step(e,1.0/120)
		check(e.soft_body.peak>0.02,"Visible local dent: "+species)
		check(Vector2(e.soft_body.offset[6]).x>Vector2(e.soft_body.offset[8]).x*1.2,"Impact remains local: "+species)
		for i in range(720):Soft.step(e,1.0/120)
		check(e.soft_body.offset.to_byte_array().size()>0 and Array(e.soft_body.offset).all(func(v):return v.length()<0.002),"Settles without permanent deformation: "+species)
		for i in range(160):
			Soft.impact(e,Vector2(24,0),Vector2.LEFT,1000)
			Soft.step(e,1.0/30)
		check(Array(e.soft_body.offset).all(func(v):return v.is_finite() and v.length()<=0.301) and e.soft_body.recoil.length()<=.231,"Repeated hits stay bounded: "+species)
		var rig=Rig.new();root.add_child(rig);rig.setup(e);rig.pose(0)
		check(rig.skeleton.get_bone_count()==15 and rig.mesh.polygons.size()>150,"Torso-only skinned mesh and fifteen spring bones: "+species)
		check(rig.legs.size()==6 and rig.feelers.size()==2,"Six articulated legs and two independent feelers: "+species)
		var lengths=true;var rigid=true;var stepped=false
		var original_angles=[]
		for limb in rig.legs:original_angles.append(limb.node.rotation)
		for frame in range(90):
			e.position+=Vector2(0,-.22);Soft.step(e,1.0/60);rig.pose(1.0/60)
			if frame==30:Soft.impact(e,e.position+Vector2(-15,5),Vector2.RIGHT,50)
			for j in rig.legs.size():
				var limb=rig.legs[j]
				lengths=lengths and absf(limb.lower.position.length()-limb.l1)<.00001 and limb.node.scale==Vector2.ONE and limb.lower.scale==Vector2.ONE
				stepped=stepped or absf(limb.node.rotation-original_angles[j])>.08
				for piece in limb.node.find_children("*","Polygon2D",true,false):rigid=rigid and piece.get_bone_count()==0 and piece.skeleton.is_empty()
		check(lengths and rigid,"Leg segments remain rigid and constant length under walking and hits: "+species)
		check(stepped,"Movement drives actual joint angles: "+species)
		for frame in range(45):Soft.step(e,1.0/60);rig.pose(1.0/60)
		var resting_feet=[]
		for limb in rig.legs:resting_feet.append(limb.world_foot)
		for frame in range(30):Soft.step(e,1.0/60);rig.pose(1.0/60)
		var planted=true
		for j in rig.legs.size():planted=planted and rig.legs[j].world_foot.distance_to(resting_feet[j])<.00001
		check(planted,"Stopping finishes the step then keeps feet planted: "+species)
		if species=="moth":
			var wing=rig.wings[0].node;var before_wing=wing.transform
			Soft.step(e,.05);rig.pose(.05)
			check(rig.wings.size()==2 and wing.transform!=before_wing and wing.get_child(0).get_bone_count()==0,"Moth wings flap around separate rigid hinges")
			var min_width=1.0;var max_width=0.0
			for frame in range(60):
				Soft.step(e,1.0/60);rig.pose(1.0/60)
				min_width=minf(min_width,wing.scale.x);max_width=maxf(max_width,wing.scale.x)
			check(min_width<.2 and max_width>.95,"Wing sweep reads clearly from full extension to folded projection")
		if species=="mantis":check(rig.legs[0].wrist!=null and rig.legs[3].wrist!=null,"Mantis sickles have shoulder, elbow and wrist joints")
		var valid=true
		for vertex in rig.mesh.polygon.size():
			var total=0.0;var influences=0
			for i in rig.mesh.get_bone_count():
				var weight=rig.mesh.get_bone_weights(i)[vertex]
				total+=weight
				if weight>0:influences+=1
			valid=valid and absf(total-1)<0.0001 and influences==4
		check(valid,"Mesh weights normalize to four influences: "+species)
		rig.queue_free()
		var saved:PackedScene=load(Brood.ROOT+"rigs/"+species+".tscn")
		var editable=saved.instantiate();root.add_child(editable)
		check(editable.bones.size()==15 and editable.mesh.get_bone_count()==15 and editable.legs.size()==6,"Saved scene restores soft torso and articulated legs: "+species)
		var second=saved.instantiate();root.add_child(second)
		check(editable.hit_material!=second.hit_material,"Each saved insect owns its flash material independently: "+species)
		second.free()
		editable.free()
	var a=simulate(60);var b=simulate(120)
	check(Vector2(a.soft_body.offset[6]).distance_to(b.soft_body.offset[6])<0.0001,"60 and 120 FPS impacts agree")
	var body=Body.new(db);var battle=Battle.new(db,body)
	var enemy=battle.spawn(db.pool["250"],Vector2(400,0))
	enemy.guns.clear()
	var bullet={"data":{"class":"BasicProjectile"},"damage":10.0,"shield_damage":10.0,"friendly":true,"chips":{},"velocity":Vector2.RIGHT,"position":enemy.position-Vector2(10,0),"pierce":1,"hit":[]}
	var before=float(enemy.hp)
	battle.hit_enemy(enemy,bullet)
	check(enemy.hp==before-10 and enemy.soft_body.hits==1,"Real projectile hull damage triggers the soft-body impulse")
	check(battle.audio_events.any(func(event):return event.get("flesh",false)),"Hull damage triggers the wet body slap in the grouped hit event")
	var original_position:Vector2=enemy.position
	Soft.step(enemy,0.1)
	check(enemy.position==original_position,"Visual deformation preserves collision position and gameplay balance")
	var neighbor=battle.spawn(db.pool["250"],enemy.position+Vector2(20,0));neighbor.guns.clear()
	bullet.data.projectileEffectArea=2.0
	battle.hit_enemy(enemy,bullet)
	check(neighbor.soft_body.hits>0,"Blast splash triggers deformation on nearby insects")
	var protected=specimen("beetle")
	Soft.impact(protected,Vector2(-20,0),Vector2.RIGHT,5,"gatling")
	var cue=int(protected.soft_body.cue)
	for i in range(20):Soft.impact(protected,Vector2(-20,0),Vector2.RIGHT,5,"gatling")
	check(protected.soft_body.hits==21 and protected.soft_body.cue==cue,"Rapid hull damage preserves every hit without stacking repeated burst cues")
	var organic=preload("res://scripts/insect_hit_audio.gd").make_stream()
	check(organic.data.size()>8000 and organic.mix_rate==22050,"Wet slap audio is a complete bounded PCM transient")
	organic.save_to_wav("res://artifacts/brood-wet-hit.wav")
	await process_frame
	await process_frame
	var report={"checks":checks,"passed":checks.all(func(c):return c.passed)}
	FileAccess.open("res://artifacts/brood-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if report.passed else 1)
