extends Node2D
## Elastic torso + rigid articulated appendages. Combat owns the spring clock.
const Soft=preload("res://scripts/soft_insect.gd")
const Brood=preload("res://scripts/brood_theme.gd")
const Anatomy=preload("res://scripts/insect_anatomy.gd")
const HitFX=preload("res://scripts/insect_hit_fx.gd")
const HitShader=preload("res://shaders/insect_hit.gdshader")
var entity:Dictionary
var mesh:Polygon2D
var skeleton:Skeleton2D
var limb_skeleton:Skeleton2D
var bones:Array[Bone2D]=[]
var legs:Array=[]
var wings:Array=[]
var feelers:Array=[]
var aspect=Vector2.ONE
var death_age=0.0
var gait=0.0
var previous_position=Vector2.ZERO
var previous_angle=0.0
var art:Texture2D
var rest_points:PackedVector2Array
var hit_material:ShaderMaterial
var hit_fx:Node2D
var visual_offset=Vector2.ZERO
var visual_angle=0.0
var walk_amount=0.0
var gait_speed=0.0
var display_heading=0.0
const STRIDE={"grub":1.0,"beetle":1.15,"moth":1.3,"sac":1.0,"mantis":1.3,"queen":1.1}
@export var preview_species=""

func _ready():
	if preview_species.is_empty():
		set_process(false);set_process_unhandled_input(false)
		return
	entity={"uid":1,"kind":"AISwarmingUnit","position":Vector2.ZERO,"angle":-PI/2,"hp":100.0,"max_hp":100.0,"radius":50.0,"brood_species":preview_species}
	Soft.prepare(entity)
	rest_points=entity.soft_body.rest
	mesh=get_node("SkinMesh");skeleton=mesh.get_node("Skeleton2D")
	hit_material=mesh.material
	hit_fx=get_node("HitFX");hit_fx.setup(entity.soft_body)
	limb_skeleton=get_node("Appendages")
	art=Brood.texture("enemy_"+preview_species).atlas
	aspect=art.get_size()/maxf(art.get_width(),art.get_height())
	for bone in skeleton.get_children():bones.append(bone)
	_bind_appendages()

func _process(dt:float):
	if preview_species.is_empty():return
	var direction=Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	entity.position+=direction*40*dt
	Soft.step(entity,dt);pose(dt)

func _unhandled_input(event:InputEvent):
	if preview_species.is_empty():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var local=get_local_mouse_position()
		if local.length()<1.4:Soft.impact(entity,entity.position+local*Brood.extent(entity)*.5,-local.normalized(),40)

func local_uv(uv:Vector2)->Vector2:return (uv*2-Vector2.ONE)*aspect

func _new_bone(parent:Node,bone_name:String,p:Vector2,angle:float,length:float)->Bone2D:
	var bone=Bone2D.new();bone.name=bone_name;bone.position=p;bone.rotation=angle
	bone.rest=Transform2D(angle,p);bone.set_autocalculate_length_and_angle(false);bone.length=length
	parent.add_child(bone)
	return bone

func _cutout(parent:Node,region:PackedVector2Array,pivot:Vector2,angle:float):
	if region.size()<3:return
	var piece=Polygon2D.new();piece.name="RigidCutout"
	var points=PackedVector2Array();var uvs=PackedVector2Array()
	for uv in region:
		points.append((local_uv(uv)-pivot).rotated(-angle));uvs.append(uv*art.get_size())
	piece.polygon=points;piece.uv=uvs;piece.texture=art
	piece.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	piece.material=hit_material
	parent.add_child(piece)

func _joint_cap(parent:Node,pivot:Vector2,angle:float,radius:float):
	var uvs=PackedVector2Array()
	for i in range(12):uvs.append(((pivot+Vector2.from_angle(i*TAU/12)*radius)/aspect+Vector2.ONE)*.5)
	_cutout(parent,uvs,pivot,angle)
	parent.get_child(parent.get_child_count()-1).name="JointCap"

func _skin_weights(p:Vector2)->Array:
	var nearest:Array=[]
	for i in rest_points.size():nearest.append({"index":i,"distance":p.distance_squared_to(rest_points[i])})
	nearest.sort_custom(func(a,b):return a.distance<b.distance)
	var total=0.0;var result:Array=[]
	for j in range(4):total+=1.0/pow(.035+float(nearest[j].distance),2)
	for j in range(4):result.append(Vector2(nearest[j].index,(1.0/pow(.035+float(nearest[j].distance),2))/total))
	return result

func setup(actor:Dictionary):
	entity=actor;Soft.prepare(entity)
	rest_points=entity.soft_body.rest
	var species=Brood.species(entity)
	art=Brood.texture("enemy_"+species).atlas
	aspect=art.get_size()/maxf(art.get_width(),art.get_height())
	var anatomy:Dictionary=Anatomy.definition(species)
	hit_material=ShaderMaterial.new();hit_material.shader=HitShader;hit_material.resource_local_to_scene=true
	limb_skeleton=Skeleton2D.new();limb_skeleton.name="Appendages";add_child(limb_skeleton)
	mesh=Polygon2D.new();mesh.name="SkinMesh";add_child(mesh)
	mesh.texture=art;mesh.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;mesh.material=hit_material
	skeleton=Skeleton2D.new();skeleton.name="Skeleton2D";mesh.add_child(skeleton);mesh.skeleton=NodePath("Skeleton2D")
	for i in rest_points.size():bones.append(_new_bone(skeleton,"SoftBone%02d"%i,rest_points[i]*aspect,0,.12))
	var geometry=Anatomy.body_geometry(species)
	var vertices=PackedVector2Array();var uvs=PackedVector2Array();var weights:Array[PackedFloat32Array]=[]
	for i in bones.size():
		var row=PackedFloat32Array();row.resize(geometry.vertices.size());weights.append(row)
	for v in geometry.vertices.size():
		var uv:Vector2=geometry.vertices[v]
		vertices.append(local_uv(uv));uvs.append(uv*art.get_size())
		for influence in _skin_weights(uv*2-Vector2.ONE):weights[int(influence.x)][v]=influence.y
	mesh.polygon=vertices;mesh.uv=uvs;mesh.polygons=geometry.triangles
	for i in bones.size():mesh.add_bone(NodePath(bones[i].name),weights[i])
	for side in [-1,1]:
		for row in anatomy.legs.size():_build_leg(anatomy.legs[row],anatomy.body,side,row)
		_build_hinge("Feeler",anatomy.antenna_root,anatomy.antenna,anatomy.body,side)
		for wing in anatomy.wings:_build_hinge("Wing",wing.root,wing.region,anatomy.body,side)
	hit_fx=HitFX.new();hit_fx.name="HitFX";add_child(hit_fx);hit_fx.setup(entity.soft_body)
	_bind_appendages()

func _flipped(p:Vector2,side:int)->Vector2:return p if side<0 else Vector2(1-p.x,p.y)
func _flipped_polygon(p:PackedVector2Array,side:int)->PackedVector2Array:return p if side<0 else Anatomy.mirror(p)

func _build_leg(data:Dictionary,body:PackedVector2Array,side:int,row:int):
	var shift:Vector2=data.shift;shift.x*= -side
	var hip=local_uv(_flipped(data.hip,side));var knee=local_uv(_flipped(data.knee,side));var tip=local_uv(_flipped(data.foot,side))
	var first_angle=(knee-hip).angle();var first_length=hip.distance_to(knee)
	var upper=_new_bone(limb_skeleton,"Leg%s%d"%["L" if side<0 else "R",row],hip+shift*2*aspect,first_angle,first_length)
	upper.z_index=0
	upper.set_meta("type","leg");upper.set_meta("side",side);upper.set_meta("row",row)
	upper.set_meta("anchor",hip+shift*2*aspect);upper.set_meta("source_tip",tip+shift*2*aspect)
	var end=knee
	if data.has("wrist"):end=local_uv(_flipped(data.wrist,side))
	else:end=tip
	var second_angle=(end-knee).angle();var second_length=knee.distance_to(end)
	var lower=_new_bone(upper,"Knee",Vector2(first_length,0),second_angle-first_angle,second_length)
	var foot_parent:Node=lower;var last_length=second_length
	if data.has("parts"):
		var wrist=_new_bone(lower,"Wrist",Vector2(second_length,0),(tip-end).angle()-second_angle,end.distance_to(tip))
		foot_parent=wrist;last_length=end.distance_to(tip)
		var parents=[upper,lower,wrist];var pivots=[hip,knee,end];var angles=[first_angle,second_angle,(tip-end).angle()]
		for j in range(3):_cutout(parents[j],_flipped_polygon(data.parts[j],side),pivots[j],angles[j])
	else:
		var halves=Anatomy.split_leg(data.region,data.knee,data.foot)
		for j in range(2):
			for part in halves[j]:
				for clipped in Geometry2D.clip_polygons(part,body):
					_cutout(upper if j==0 else lower,_flipped_polygon(clipped,side),hip if j==0 else knee,first_angle if j==0 else second_angle)
	var foot=Node2D.new();foot.name="Foot";foot.position=Vector2(last_length,0);foot_parent.add_child(foot)
	_joint_cap(upper,hip,first_angle,minf(.034,first_length*.26))
	_joint_cap(lower,knee,second_angle,minf(.031,minf(first_length,second_length)*.24))
	upper.set_meta("bend",signf((tip-hip).cross(knee-hip)))

func _build_hinge(kind:String,pivot:Vector2,region:PackedVector2Array,body:PackedVector2Array,side:int):
	var p=local_uv(_flipped(pivot,side))
	var hinge=_new_bone(limb_skeleton,kind+("L" if side<0 else "R"),p,0,.15)
	hinge.z_index=0
	hinge.set_meta("type",kind);hinge.set_meta("side",side);hinge.set_meta("anchor",p)
	for clipped in Geometry2D.clip_polygons(region,body):_cutout(hinge,_flipped_polygon(clipped,side),p,0)

func _bind_appendages():
	previous_position=entity.position;previous_angle=float(entity.angle)+PI/2;display_heading=previous_angle
	for node in limb_skeleton.get_children():
		var anchor:Vector2=node.get_meta("anchor")
		var item={"node":node,"anchor":anchor,"weights":_skin_weights(anchor/aspect),"side":int(node.get_meta("side"))}
		match node.get_meta("type"):
			"leg":
				item.lower=node.get_node("Knee");item.row=int(node.get_meta("row"))
				item.wrist=item.lower.get_node_or_null("Wrist")
				item.foot=(item.wrist if item.wrist!=null else item.lower).get_node("Foot")
				item.l1=node.length;item.l2=item.lower.length
				item.bend=float(node.get_meta("bend"));item.rest_tip=anchor.lerp(node.get_meta("source_tip"),.90)
				item.world_foot=_to_world(item.rest_tip);item.swing=false;item.swing_u=0.0;item.swing_start=item.world_foot;item.swing_end=item.world_foot
				legs.append(item)
			"Wing":wings.append(item)
			"Feeler":feelers.append(item)

func _to_world(p:Vector2)->Vector2:return Vector2(entity.position)+(p+visual_offset).rotated(display_heading+visual_angle)*Brood.extent(entity)*.5
func _from_world(p:Vector2)->Vector2:return (p-Vector2(entity.position)).rotated(-display_heading-visual_angle)/(Brood.extent(entity)*.5)-visual_offset

func _attachment(item:Dictionary)->Vector2:
	var result=Vector2.ZERO
	for influence in item.weights:
		var i=int(influence.x)
		result+=(bones[i].position+(Vector2(item.anchor)-rest_points[i]*aspect).rotated(bones[i].rotation))*influence.y
	return result

func _pose_leg(item:Dictionary,moving:bool,travel:Vector2,dt:float):
	var upper:Bone2D=item.node;var lower:Bone2D=item.lower
	upper.position=_attachment(item)
	var group=(item.row+(1 if item.side>0 else 0))%2
	var phase=fposmod(gait+group*PI,TAU)/TAU
	if death_age>0 or item.wrist!=null:
		# Sickle arms are a three-link FK chain; death folds each joint without scaling.
		var fold=clampf(death_age/.28,0,1)
		var stride=sin(gait+group*PI)*.43*walk_amount+sin(float(entity.soft_body.pose_clock)*3.5+group*PI)*.085*(1-walk_amount)
		stride+=float(entity.soft_body.shock)*.18
		upper.rotation=upper.rest.get_rotation()+item.side*(stride+fold*.55)
		lower.rotation=lower.rest.get_rotation()+item.side*(-stride*1.8+fold*.8)
		if item.wrist!=null:item.wrist.rotation=item.wrist.rest.get_rotation()+item.side*(stride*1.3+fold*.3)
		return
	if (moving and phase<.5) or (not moving and item.swing):
		if not item.swing:
			item.swing=true;item.swing_start=item.world_foot
			item.swing_end=_to_world(item.rest_tip)+travel.normalized()*Brood.extent(entity)*STRIDE[Brood.species(entity)]*.125
		var u=phase*2 if moving else minf(1,item.swing_u+dt*7)
		item.swing_u=u
		var smooth=u*u*(3-2*u)
		var lift=minf(.16,(item.l1+item.l2)*.30)
		item.world_foot=Vector2(item.swing_start).lerp(item.swing_end,smooth)+Vector2(-item.side*lift,-.035).rotated(display_heading)*Brood.extent(entity)*.5*sin(u*PI)
		if not moving and u>=1:item.swing=false
	elif item.swing:
		item.world_foot=item.swing_end;item.swing=false
	# Keep stance feet on the ground; solve angles with fixed segment lengths.
	var target=_from_world(item.world_foot)-upper.position
	var distance=clampf(target.length(),absf(item.l1-item.l2)+.001,item.l1+item.l2-.001)
	var along=target.angle()
	var bend=acos(clampf((item.l1*item.l1+distance*distance-item.l2*item.l2)/(2*item.l1*distance),-1,1))
	upper.rotation=rotate_toward(upper.rotation,along+item.bend*bend,9.0*maxf(dt,0))
	var knee=upper.position+Vector2.from_angle(upper.rotation)*item.l1
	var reachable=upper.position+Vector2.from_angle(along)*distance
	lower.rotation=rotate_toward(lower.rotation,(reachable-knee).angle()-upper.rotation,12.0*maxf(dt,0))

func pose(dt:float,dying:bool=false):
	if mesh==null:return
	var state:Dictionary=entity.soft_body
	if dying:death_age+=dt;Soft.step(entity,dt)
	var t=float(state.pose_clock)+int(entity.get("uid",0))*1.37
	var species=Brood.species(entity)
	var travel:Vector2=Vector2(entity.position)-previous_position
	var turn=angle_difference(previous_angle,float(entity.angle)+PI/2)
	# Derive a bounded cycle rate from world speed, not a per-frame distance cap.
	# Tiny sprites previously took 10-20 strides per second and vibrated at 2x that rate.
	var span=maxf(1.0,Brood.extent(entity)*.5)
	var relocated=travel.length()>span*4.0
	var measured=(travel.length()+absf(turn)*span*.12)/maxf(dt,.0001) if dt>0 and not relocated else 0.0
	var target_rate=clampf(measured/(span*STRIDE[species]),0.0,2.8)
	var held=dying or float(state.hold)>0
	if held:target_rate=0.0
	var response=1.0-exp(-12.0*maxf(dt,0))
	var cycle_advance=target_rate*maxf(dt,0)+(gait_speed-target_rate)*response/12.0
	gait_speed=lerpf(gait_speed,target_rate,response)
	var moving=dt>0 and gait_speed>.04 and not held
	walk_amount=move_toward(walk_amount,clampf(gait_speed,0,1) if moving else 0.0,dt*6)
	if moving:gait+=maxf(0,cycle_advance)*TAU
	display_heading=lerp_angle(display_heading,float(entity.angle)+PI/2,1.0-exp(-14.0*maxf(dt,0)))
	visual_offset=Vector2(state.recoil)+Vector2(sin(gait)*.009,cos(gait*2)*.014)*walk_amount
	visual_angle=float(state.lean)+sin(gait)*.018*walk_amount
	if relocated:
		for item in legs:item.world_foot=_to_world(item.rest_tip);item.swing=false;item.swing_u=0.0
	mesh.position=visual_offset;limb_skeleton.position=visual_offset;hit_fx.position=visual_offset
	rotation=display_heading+visual_angle
	var push:Vector2=state.direction;var side=push.orthogonal()
	var squeeze=minf(.26,float(state.shock)*.20)
	var center=Vector2(0,rest_points[7].y)*aspect
	for i in bones.size():
		var rest:Vector2=rest_points[i]
		var belly=smoothstep(.10,.5,(i/3)/4.0)
		# Head/thorax resist deformation; the abdomen retains the spring impulse.
		var softness=lerpf(.22,1.0,belly)
		var sway=Vector2(sin(t*4.2-rest.y*3.2)*.038,cos(t*3.7-rest.y*2.8)*.027)*belly
		sway+=Vector2(sin(gait-rest.y*4.0)*.025,cos(gait*2-rest.y*3.5)*.018)*belly*walk_amount
		if species=="beetle":sway*=.65
		var collapse=Vector2(rest.x*.18,-rest.y*.42)*clampf(death_age/.28,0,1)*softness
		var p=(rest+Vector2(state.offset[i])*softness+sway+collapse)*aspect
		var delta=p-center
		bones[i].position=p-push*delta.dot(push)*squeeze*softness+side*delta.dot(side)*squeeze*.30*softness
		bones[i].rotation=(sin(t*4.5-rest.y*3.5)*.032+sin(gait-rest.y*3.5)*.025*walk_amount+float(state.offset[i].x)*.25)*softness
	for item in legs:_pose_leg(item,moving,travel,dt)
	for item in wings:
		item.node.position=_attachment(item)
		var flap=sin(t*27)
		item.node.rotation=item.side*(.40*flap+float(state.shock)*.16+clampf(death_age/.28,0,1)*.55)
		# Foreshortening of one rigid wing plane, with no soft vertex weights.
		item.node.scale=Vector2(.57+.43*cos(t*27),1)
	for item in feelers:
		item.node.position=_attachment(item)
		item.node.rotation=item.side*(sin(t*3.3+item.side*.6)*.14+float(state.shock)*.21)
	previous_position=entity.position;previous_angle=float(entity.angle)+PI/2
	var flash=clampf(float(state.flash)/.16,0,1)
	hit_material.set_shader_parameter("hit_flash",flash*flash)
	hit_material.set_shader_parameter("pressure",state.shock)
	hit_material.set_shader_parameter("contact_uv",(Vector2(state.contact)/aspect+Vector2.ONE)*.5)
	hit_fx.pose()
	var tint=Color.WHITE
	if entity.get("role","")=="friendly":tint=tint.lerp(Color(.75,1,.9),.35)
	mesh.modulate=tint;limb_skeleton.modulate=tint
	modulate.a=1-clampf((death_age-.1)/.22,0,1)
