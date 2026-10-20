extends Control
## Assembly coordinates are independent of the live simulation and camera.
const UI=preload("res://scripts/game_ui.gd")
const Art=preload("res://scripts/centipede_art.gd")
const Flagella=preload("res://scripts/flagella.gd")
const DragPreview=preload("res://scripts/chain_drag_preview.gd")
const SpiderArt=preload("res://scripts/spider_art.gd")
class Hotspot extends Button:
	var builder
	var canvas
	var target:Dictionary={}
	var payload:Dictionary={}
	var selected=false
	var world=Vector2.ZERO
	func _init():
		flat=true;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state in ["normal","hover","pressed","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	func configure(b,c,t,p,w):
		builder=b;canvas=c;target=t;payload=p;world=w
		pressed.connect(func():builder.click(target,payload))
		mouse_entered.connect(func():builder.hover_mount(drop_target());builder.inspect(payload))
		mouse_exited.connect(func():builder.hover_mount({});builder.inspect({}))
		focus_entered.connect(func():canvas.reveal(world);canvas.queue_redraw())
	func drop_target()->Dictionary:
		if not builder.active_drag_data.is_empty():
			return canvas.target_at(canvas.local_pointer(),builder.active_drag_data)
		var carried=builder.selected_data
		var segment=int(target.get("segment",target.get("before",-1)))
		var merge={"kind":"merge","segment":segment}
		if not carried.is_empty() and not payload.is_empty() and builder.can_drop(merge,carried):return merge
		if target.get("kind")=="segment":return {"kind":"gap","before":segment+1}
		return target
	func _get_drag_data(_at):
		if payload.is_empty():return null
		var preview=DragPreview.new();preview.builder=builder;preview.texture=builder.db.core_sprite(builder.db.asset(payload.part.id))
		set_drag_preview(preview);builder.begin_drag(payload.duplicate());return payload.duplicate()
	func _can_drop_data(at,data):
		return canvas._can_drop_data(position+at,data)
	func _drop_data(at,data):canvas._drop_data(position+at,data)
	func _notification(what):
		if what==NOTIFICATION_DRAG_END and is_instance_valid(builder):builder.end_drag()

var builder
var points:Array[Vector2]=[]
var angles:Array[float]=[]
var hotspots:Array=[]
var zoom=1.0
var pan=Vector2.ZERO
var center=Vector2.ZERO
var bounds=Rect2()
var panning=false
var view_adjusted=false
var display_poses:Dictionary={}
var flagella=Flagella.new()
var clock=0.0
var organs=preload("res://scripts/soft_organ_art.gd").new()
func setup(owner):
	builder=owner;clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP
	if builder.player.character_id=="spider":
		var rig=builder.spider_preview.spider_rig
		bounds=Rect2(-75,-75,150,150)
		for leg in rig.legs:bounds=bounds.expand(leg.foot).expand(leg.hip)
		for leg in range(8):
			var count=builder.player.spider_leg_count(leg)
			for depth in range(count):
				var mount=builder.player.spider_mount(leg,depth)
				var part=builder.player.parts[builder.player.part_at(mount)]
				add_hotspot({"kind":"mount","before":mount},{"kind":"mounted","part":part},rig.mount_pose(mount).point,mount,false)
			if count<4:
				var mount=builder.player.spider_mount(leg,count)
				add_hotspot({"kind":"mount","before":mount},{},rig.mount_pose(mount).point,mount,true)
	else:
		var count=builder.player.segment_count()
		# A smooth, continuous coiled body remains legible even at sixty pieces.
		for i in range(count+1):
			var distance=float(i)*56.0
			var row=int(distance/(700.0+PI*70.0))
			var travel=fmod(distance,700.0+PI*70.0)
			var direction=1.0 if row%2==0 else -1.0
			var start=0.0 if row%2==0 else 700.0
			var point=Vector2(start+direction*minf(travel,700.0),row*140.0)
			if travel>700.0:
				var angle=(travel-700.0)/70.0
				point+=Vector2(direction*sin(angle)*70.0,(1-cos(angle))*70.0)
			points.append(point)
		for i in points.size():
			var direction=points[maxi(0,i-1)]-points[mini(points.size()-1,i+1)]
			angles.append(PI if direction.length()<0.1 else direction.angle())
		bounds=Rect2(points[0],Vector2.ONE)
		for point in points:bounds=bounds.expand(point)
		for segment in range(1,count+1):
			var part=builder.player.parts[builder.player.part_at(segment)]
			add_hotspot({"kind":"segment","segment":segment},{"kind":"mounted","part":part},points[segment],segment,false)
		for before in range(1,count+2):
			var point=points[before-1]-Vector2.from_angle(angles[-1])*72.0 if before==count+1 else points[before-1].lerp(points[before],0.5)
			bounds=bounds.expand(point)
			add_hotspot({"kind":"gap","before":before},{},point,before,true)
	for control in hotspots:
		if not control.payload.is_empty():
			var part=control.payload.part
			display_poses[int(part.feedback_uid)]={"point":control.world,"angle":pose_angle(int(part.segment))}
	bounds=bounds.grow(100 if builder.player.character_id=="spider" else 175);center=bounds.get_center();fit()
func add_hotspot(target:Dictionary,payload:Dictionary,point:Vector2,index:int,gap:bool):
	var control=Hotspot.new();add_child(control);control.configure(builder,self,target,payload,point);hotspots.append(control)
	control.tooltip_text="拖入这里生长" if gap else builder.db.title(builder.db.asset(payload.part.id))+" · 拖动调整顺序；同元素同阶叠放合成"
	if gap:builder.insert_targets[index]=control;builder.tail_target=control
	else:builder.segment_buttons[index]=control
func world_to_view(point:Vector2)->Vector2:return (point-center)*zoom+size/2+pan
func view_to_world(point:Vector2)->Vector2:return (point-size/2-pan)/zoom+center
func fit():
	view_adjusted=false
	zoom=clampf(minf((size.x-60)/bounds.size.x,(size.y-50)/bounds.size.y),0.35,3.2);pan=Vector2.ZERO;layout_hotspots()
func zoom_at(factor:float,point:Vector2):
	view_adjusted=true
	var anchor=view_to_world(point);zoom=clampf(zoom*factor,0.3,4.5);pan=point-size/2-(anchor-center)*zoom;layout_hotspots()
func reveal(point:Vector2):
	if not Rect2(Vector2(40,40),size-Vector2(80,80)).has_point(world_to_view(point)):pan=-(point-center)*zoom;layout_hotspots()
func layout_hotspots():
	for control in hotspots:
		var gap=control.payload.is_empty()
		var diameter=clampf((22.0 if gap else 42.0)*zoom,18.0,80.0)
		control.size=Vector2.ONE*diameter;control.position=world_to_view(control.world)-control.size/2
	queue_redraw()
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom_at(1.15,event.position);accept_event()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom_at(1/1.15,event.position);accept_event()
		elif event.button_index==MOUSE_BUTTON_MIDDLE or event.button_index==MOUSE_BUTTON_LEFT:panning=event.pressed;accept_event()
	elif event is InputEventMouseMotion and panning:view_adjusted=true;pan+=event.relative;layout_hotspots();accept_event()
func _draw():
	if builder==null:return
	organs.begin_frame()
	if builder.player.character_id=="spider":
		SpiderArt.draw_body(self,builder.spider_preview,world_to_view(Vector2.ZERO),zoom,0)
		for part in builder.player.parts.slice(1):
			if dragging_part(part):continue
			var pose=display_poses.get(int(part.feedback_uid),{})
			# A module can change before the old assembly canvas is retired.
			if pose.is_empty():continue
			Flagella.paint(self,flagella.poses(int(part.feedback_uid)),world_to_view(pose.point),pose.angle,zoom*0.65,true)
			paint_organ(part,world_to_view(pose.point),zoom)
	else:
		var last=points.size()-1
		Art.tail(self,world_to_view(points[last]),angles[last],zoom,last==0)
		for i in range(points.size()-1,0,-1):
			var part=builder.player.parts[builder.player.part_at(i)]
			if dragging_part(part):continue
			var pose=display_poses.get(int(part.feedback_uid),{})
			# A module can change before the old assembly canvas is retired.
			if pose.is_empty():continue
			var at=world_to_view(pose.point)
			var level=int(part.get("fusion_level",1))
			Flagella.paint(self,flagella.poses(int(part.feedback_uid)),at,pose.angle,zoom,true)
			Art.segment(self,at,pose.angle,zoom,clock*3)
			paint_organ(part,at,zoom)
			if level>1:draw_string(UI.font(),at+Vector2(-16,37)*zoom,"%d阶"%level,HORIZONTAL_ALIGNMENT_CENTER,32*zoom,int(10*zoom),UI.TEAL)
		Art.segment(self,world_to_view(points[0]),angles[0],zoom,clock*3,true,false,false,0,clock,[],flagella.poses(0))
	var carried=builder.active_drag_data if not builder.active_drag_data.is_empty() else builder.selected_data
	for control in hotspots:
		var gap=control.payload.is_empty()
		var target:Dictionary=control.target
		if not gap:
			if dragging_part(control.payload.part):continue
			target={"kind":"merge","segment":int(control.payload.part.segment)}
		var valid=not carried.is_empty() and builder.can_drop(target,carried)
		var hovered=builder.hovered_target==target and valid
		var point:Vector2=control.world if gap else display_poses[int(control.payload.part.feedback_uid)].point
		var at=world_to_view(point)
		if gap and (valid or carried.is_empty()):
			draw_circle(at,clampf(10*zoom,9,17),Color(UI.BG,0.9))
			draw_arc(at,clampf(10*zoom,9,17),0,TAU,24,UI.TEAL if valid else Color(UI.MUTED,0.5),2,true)
			draw_line(at-Vector2(4,0),at+Vector2(4,0),UI.TEAL,2,true);draw_line(at-Vector2(0,4),at+Vector2(0,4),UI.TEAL,2,true)
		elif not gap and (valid or control.selected or control.has_focus()):
			draw_arc(at,clampf(27*zoom,14,90),0,TAU,40,UI.TEAL if hovered or control.selected or control.has_focus() else Color(UI.TEAL,0.3),3 if hovered else 1.5,true)
		if hovered:
			draw_arc(at,clampf(32*zoom,22,100),0,TAU,40,UI.AMBER if not gap else UI.TEAL,3,true)
			if gap and carried.get("kind")=="inventory":
				var texture=builder.db.core_sprite(builder.db.asset(carried.id))
				if texture!=null:
					builder.draw_element(self,texture,at,zoom,{},Color(1,1,1,0.35))
		if not gap and int(control.payload.part.segment)==builder.landing_segment and builder.landing_left>0:
			draw_arc(at,(29+(1-builder.landing_left/0.65)*14)*zoom,0,TAU,48,Color(UI.TEAL,builder.landing_left/0.65),2,true)

func pose_angle(segment:int)->float:
	return Vector2(builder.spider_preview.spider_rig.mount_pose(segment).direction).angle() if builder.player.character_id=="spider" else angles[clampi(segment,0,angles.size()-1)]

func dragging_part(part:Dictionary)->bool:
	return not builder.drag_cancelled and builder.active_drag_data.get("kind")=="mounted" and builder.active_drag_data.get("part",{})==part

# Hit testing uses the fixed insertion slots, never the moving artwork, so a
# neighbor sliding under the pointer cannot flip the target back and forth.
func target_at(at:Vector2,data:Dictionary)->Dictionary:
	var point=view_to_world(at)
	var best=INF
	var nearest=null
	for control in hotspots:
		var distance=point.distance_to(control.world)
		if distance<best:best=distance;nearest=control
	if nearest==null or best>64:return {}
	var target:Dictionary=nearest.target
	if not nearest.payload.is_empty():
		var segment=int(nearest.payload.part.segment)
		var merge={"kind":"merge","segment":segment}
		if best<16 and builder.can_drop(merge,data):return merge
		if builder.player.character_id=="spider":return target
		var axis=-Vector2.from_angle(angles[segment])
		return {"kind":"gap","before":segment+(1 if (point-nearest.world).dot(axis)>0 else 0)}
	return target

func _can_drop_data(_at,data):
	if not data is Dictionary:return false
	var target=target_at(local_pointer(),data)
	builder.hover_mount(target)
	return builder.can_drop(target,data)

func _drop_data(_at,data):builder.drop(target_at(local_pointer(),data),data)

func target_poses()->Dictionary:
	var result:Dictionary={}
	for control in hotspots:
		if not control.payload.is_empty():
			var part=control.payload.part
			result[int(part.feedback_uid)]={"point":control.world,"angle":pose_angle(int(part.segment))}
	var data:Dictionary=builder.active_drag_data
	var target:Dictionary=builder.hovered_target
	if builder.player.character_id!="centipede" or data.get("kind")!="mounted" or target.get("kind")!="gap" or not builder.can_drop(target,data):return result
	var order=builder.player.body_part_indices()
	var source=builder.player.parts.find(data.part)
	var start=order.find(source)
	var destination=int(target.before)-1
	order.erase(source)
	if destination>start:destination-=1
	order.insert(destination,source)
	for i in order.size():
		var uid=int(builder.player.parts[order[i]].feedback_uid)
		result[uid]={"point":points[i+1],"angle":angles[i+1]}
	return result

func _process(dt:float):
	if builder==null:return
	clock+=dt
	if not builder.active_drag_data.is_empty():
		builder.hover_mount(target_at(local_pointer(),builder.active_drag_data) if Rect2(Vector2.ZERO,size).has_point(local_pointer()) else {})
	var targets=target_poses()
	for uid in targets:
		var pose=display_poses.get(uid,targets[uid])
		pose.point=Vector2(pose.point).lerp(targets[uid].point,1-exp(-16*dt))
		pose.angle=lerp_angle(pose.angle,targets[uid].angle,1-exp(-16*dt))
		display_poses[uid]=pose
	for part in builder.player.parts.slice(1):
		var uid=int(part.feedback_uid)
		var pose=display_poses.get(uid,{})
		if not pose.is_empty() and int(part.get("fusion_level",1))>1:
			flagella.step(uid,pose.point,pose.angle,Flagella.fusion_count(int(part.fusion_level)),false,dt,clock)
	if not points.is_empty():flagella.step(0,points[0],angles[0],2,true,dt,clock)
	queue_redraw()

func capture_drop(part:Dictionary):
	if builder.active_drag_data.get("kind")=="mounted" and builder.hovered_target.get("kind")!="merge":
		display_poses[int(part.feedback_uid)]={"point":view_to_world(local_pointer()),"angle":pose_angle(int(part.segment))}

func local_pointer()->Vector2:
	return get_global_transform().affine_inverse()*builder.drag_pointer

func paint_organ(part:Dictionary,at:Vector2,scale_factor:float):
	var core=builder.db.asset(part.id)
	organs.paint(self,str(part.feedback_uid),builder.db.core_sprite(core),at,builder.element_bounds(scale_factor,part),builder.ASSEMBLY_FACING+PI/2,builder.db.Armaments.variant(builder.db,core),clock,0.0,Color.WHITE,float(part.feedback_uid))
