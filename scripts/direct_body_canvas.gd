extends Control
## Assembly coordinates are independent of the live simulation and camera.
const UI=preload("res://scripts/game_ui.gd")
const Art=preload("res://scripts/centipede_art.gd")
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
		if target.get("kind")=="segment":
			return {"kind":"swap","segment":target.segment} if builder.active_drag_data.get("kind")=="mounted" else {"kind":"gap","before":int(target.segment)+1}
		return target
	func _get_drag_data(_at):
		if payload.is_empty():return null
		var preview=TextureRect.new();preview.texture=builder.db.core_sprite(builder.db.asset(payload.part.id));preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.size=Vector2(56,56);preview.position=Vector2(-28,-28)
		set_drag_preview(preview);builder.begin_drag(payload.duplicate());return payload.duplicate()
	func _can_drop_data(_at,data):
		builder.hover_mount(drop_target());return data is Dictionary and builder.can_drop(drop_target(),data)
	func _drop_data(_at,data):builder.drop(drop_target(),data)
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
	bounds=bounds.grow(35 if builder.player.character_id=="spider" else 85);center=bounds.get_center();fit()
func add_hotspot(target:Dictionary,payload:Dictionary,point:Vector2,index:int,gap:bool):
	var control=Hotspot.new();add_child(control);control.configure(builder,self,target,payload,point);hotspots.append(control)
	control.tooltip_text="拖入这里生长" if gap else builder.db.title(builder.db.asset(payload.part.id))+" · 拖动交换"
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
	if builder.player.character_id=="spider":
		SpiderArt.draw_body(self,builder.spider_preview,world_to_view(Vector2.ZERO),zoom,0)
		for part in builder.player.parts.slice(1):
			var pose=builder.spider_preview.spider_rig.mount_pose(int(part.segment))
			builder.draw_element(self,builder.db.core_sprite(builder.db.asset(part.id)),world_to_view(pose.point),zoom*0.62)
	else:
		for i in range(points.size()-1,-1,-1):
			var at=world_to_view(points[i])
			if i==points.size()-1:Art.tail(self,at,angles[i],zoom,i==0)
			Art.segment(self,at,angles[i],zoom,0,i==0)
			if i>0:
				var part=builder.player.parts[builder.player.part_at(i)]
				builder.draw_element(self,builder.db.core_sprite(builder.db.asset(part.id)),at,zoom*0.65)
	var carried=builder.active_drag_data if not builder.active_drag_data.is_empty() else builder.selected_data
	for control in hotspots:
		var target=control.drop_target()
		var valid=not carried.is_empty() and builder.can_drop(target,carried)
		var hovered=builder.hovered_target==target and valid
		var at=world_to_view(control.world)
		var gap=control.payload.is_empty()
		if gap and (valid or carried.is_empty()):
			draw_circle(at,clampf(10*zoom,9,17),Color(UI.BG,0.9));draw_arc(at,clampf(10*zoom,9,17),0,TAU,24,UI.TEAL if valid else Color(UI.MUTED,0.5),2,true)
			draw_line(at-Vector2(4,0),at+Vector2(4,0),UI.TEAL,2,true);draw_line(at-Vector2(0,4),at+Vector2(0,4),UI.TEAL,2,true)
		elif not gap and (valid or hovered or control.selected or control.has_focus()):draw_arc(at,clampf(27*zoom,14,90),0,TAU,40,UI.TEAL if hovered or control.selected or control.has_focus() else Color(UI.TEAL,0.3),3 if hovered else 1.5,true)
		if hovered:
			draw_arc(at,clampf(34*zoom,22,100),0,TAU,40,UI.TEAL,3,true)
			if gap:
				if builder.player.character_id=="centipede":
					Art.prepare();draw_set_transform(at,PI,Vector2.ONE*zoom)
					draw_texture_rect(Art.pieces.body,Rect2(-27,-27,54,54),false,Color(1,1,1,0.6));draw_set_transform(Vector2.ZERO)
				else:
					SpiderArt.prepare();draw_texture_rect(SpiderArt.pieces.segment,Rect2(at-Vector2(30,21)*zoom,Vector2(60,42)*zoom),false,Color(1,1,1,0.6))
				var id=carried.get("id",carried.get("part",{}).get("id",""))
				var texture=builder.db.core_sprite(builder.db.asset(id))
				if texture!=null:
					draw_texture_rect(texture,Rect2(at-Vector2.ONE*24*zoom,Vector2.ONE*48*zoom),false,Color(1,1,1,0.65))
				draw_string(UI.font(),at+Vector2(-28,-39*zoom),"生长",HORIZONTAL_ALIGNMENT_CENTER,56,16,UI.TEAL)
