extends SceneTree
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
const Rig=preload("res://scripts/soft_insect_rig.gd")
const Fixture=preload("res://tests/visual_settling_fixture.gd")
var checks:Array=[]

func _initialize():call_deferred("execute")
func check(ok:bool,label:String):
	checks.append({"passed":ok,"label":label})
	if not ok:push_error(label)

func viewport()->SubViewport:
	var result=SubViewport.new();result.size=Vector2i(512,512);result.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(result)
	var background=ColorRect.new();background.color=Color("e8e5d8");background.size=Vector2(512,512);result.add_child(background)
	return result

func pixel_difference(a:Image,b:Image)->int:
	a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
	var left=a.get_data();var right=b.get_data()
	if left==right:return 0
	if left.size()!=right.size():return 255
	var maximum=0
	for i in left.size():maximum=maxi(maximum,absi(int(left[i])-int(right[i])))
	return maximum

func skin_point(rig,index:int)->Vector2:
	var result=Vector2.ZERO
	var uv:Vector2=rig.mesh.uv[index]/rig.art.get_size()
	for influence in rig._skin_weights(uv*2-Vector2.ONE):
		var bone=rig.bones[int(influence.x)]
		result+=(bone.global_transform*(bone.rest.affine_inverse()*rig.mesh.polygon[index]))*influence.y
	return result

func rigid_geometry_difference(a:Node,b:Node)->float:
	var worst=0.0
	if a is Polygon2D and a.name!="SkinMesh":
		if a.polygon.size()!=b.polygon.size():return INF
		for i in a.polygon.size():worst=maxf(worst,Fixture.difference(a.global_transform*a.polygon[i],b.global_transform*b.polygon[i]))
	if a.get_child_count()!=b.get_child_count():return INF
	for i in a.get_child_count():worst=maxf(worst,rigid_geometry_difference(a.get_child(i),b.get_child(i)))
	return worst

func geometry_difference(a,b)->float:
	var worst=Fixture.difference(a.visual_offset,b.visual_offset)
	worst=maxf(worst,absf(a.visual_angle-b.visual_angle))
	for i in a.bones.size():
		worst=maxf(worst,Fixture.difference(a.bones[i].global_position,b.bones[i].global_position))
		worst=maxf(worst,absf(a.bones[i].global_rotation-b.bones[i].global_rotation)*Brood.extent(a.entity)*2)
	for i in a.mesh.polygon.size():worst=maxf(worst,Fixture.difference(skin_point(a,i),skin_point(b,i)))
	worst=maxf(worst,rigid_geometry_difference(a,b))
	for group in ["legs","wings","feelers"]:
		for i in a.get(group).size():
			var left=a.get(group)[i].node;var right=b.get(group)[i].node
			worst=maxf(worst,Fixture.difference(left.global_position,right.global_position))
			worst=maxf(worst,absf(left.global_rotation-right.global_rotation)*Brood.extent(a.entity)*2)
	return worst

func execute():
	if DisplayServer.get_name()=="headless":push_error("Native renderer required for settling pixel comparison");quit(2);return
	var original=Soft.use_visual_settling;var previous_exact=Soft.use_exact_rest_certificate;Soft.use_exact_rest_certificate=false
	var left=viewport();var right=viewport();var rows:Array=[];var maximum_channel=0;var maximum_geometry=0.0;var physical_equal=true;var active_hits=0
	for species in Brood.SPECIES:
		for radius in [15.0,60.0]:
			for zoom in [.5,1.0,1.5]:
				var baseline=Fixture.actor(species,radius);var candidate=baseline.duplicate(true)
				var rig_a=Rig.new();var rig_b=Rig.new();left.add_child(rig_a);right.add_child(rig_b);rig_a.setup(baseline);rig_b.setup(candidate)
				for rig in [rig_a,rig_b]:rig.position=Vector2(256.125,256.375);rig.scale=Vector2.ONE*Brood.extent(baseline)*.5*zoom
				var case_channel=0;var case_geometry=0.0
				for frame in 8:
					for actor in [baseline,candidate]:
						actor.position+=Vector2(.017,.011);actor.angle+=.003
						if frame==2:Soft.impact(actor,actor.position+Vector2(8,4),Vector2.LEFT,17,"cannon")
						if frame==4:actor.knockback_velocity=Vector2.RIGHT*100;Soft.begin_push(actor)
						if frame==6:Soft.pull(actor,Vector2.LEFT,100,1.0/30)
					var dt:float=[1.0/120,1.0/60,1.0/30,.013][frame%4]
					Soft.use_visual_settling=false;Soft.step(baseline,dt)
					Soft.use_visual_settling=true;Soft.step(candidate,dt)
					if frame==2 and candidate.soft_body.lattice_active and candidate.soft_body.shock>.1:active_hits+=1
					physical_equal=physical_equal and Fixture.without_visuals(baseline.duplicate(true))==Fixture.without_visuals(candidate.duplicate(true))
					rig_a.pose(dt);rig_b.pose(dt)
					case_geometry=maxf(case_geometry,geometry_difference(rig_a,rig_b))
					await process_frame;await RenderingServer.frame_post_draw
					case_channel=maxi(case_channel,pixel_difference(left.get_texture().get_image(),right.get_texture().get_image()))
				maximum_channel=maxi(maximum_channel,case_channel);maximum_geometry=maxf(maximum_geometry,case_geometry)
				rows.append({"species":species,"radius":radius,"zoom":zoom,"maximum_channel_byte_error":case_channel,"maximum_screen_geometry_error_px":case_geometry})
				rig_a.free();rig_b.free()
	check(rows.size()==36 and active_hits==36,"All six body types, two body sizes and three render scales preserve full new-hit deformation")
	check(maximum_channel<=1,"Every production rig and hit-feedback pixel differs by at most one RGBA8 channel value")
	check(maximum_geometry<1e-5,"Projected skin vertices, bones and rigid appendage vertices remain below 1e-5 pixel displacement")
	check(physical_equal,"All nonvisual actor fields, events and clocks remain exactly equal during rendered hit/push/pull sequences")
	Soft.use_visual_settling=original;Soft.use_exact_rest_certificate=previous_exact
	var passed=checks.all(func(item):return item.passed)
	var report={"passed":passed,"checks":checks,"maximum_channel_byte_error":maximum_channel,"maximum_screen_geometry_error_px":maximum_geometry,"renderer":RenderingServer.get_video_adapter_name(),"rows":rows,"settle_threshold":Soft.VISUAL_SETTLING_THRESHOLD,"scope":"Native production SoftInsectRig skeleton, appendage batching, real textures/shader and HitFX. Paired identical 512px viewports; all pixels compared at each of eight frames per body/scale, including fresh hit and interleaved push/pull. No FPS claim."}
	FileAccess.open("res://artifacts/deep50-soft-visual-settling-pixels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if passed else 1)
