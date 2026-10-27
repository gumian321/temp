extends RefCounted
## Consecutive equal meshes within each existing material stream are instanced.
## A size change starts a new run, preserving every overlapping body's order.
var groups:Dictionary={}
var parents:Dictionary={}
var dirty=false
const MAX_UNUSED=96
func begin_frame():
	parents.clear();dirty=true
	for group in groups.values():group.transforms.clear();group.used=false
func append(painter,mesh:ArrayMesh,pose:Transform2D,order:int):
	var parent:RID=painter.batch.rid
	if not parents.has(parent):parents[parent]={"mesh":null,"index":-1,"group":{}}
	var state:Dictionary=parents[parent]
	if state.mesh!=mesh:
		state.mesh=mesh;state.index+=1
		var key=[parent,state.index]
		if not groups.has(key):
			var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_2D
			var rid=RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(rid,parent)
			RenderingServer.canvas_item_add_multimesh(rid,mm.get_rid())
			RenderingServer.canvas_item_set_visible(rid,false)
			groups[key]={"rid":rid,"mm":mm,"transforms":[],"previous":[],"used":false,"mesh":null,"material":RID(),"order":-1,"last_order":-1,"visible":false}
		state.group=groups[key]
		var selected:Dictionary=state.group
		if selected.mesh!=mesh:selected.mm.mesh=mesh;selected.mesh=mesh
		var material:RID=painter.batch.material.get_rid()
		if selected.material!=material:RenderingServer.canvas_item_set_material(selected.rid,material);selected.material=material
	var group:Dictionary=state.group
	if not group.used:group.order=order
	group.used=true;group.transforms.append(pose)
	dirty=true
func end_frame():
	if not dirty:return
	dirty=false
	var unused=0;var erase:Array=[]
	for key in groups:
		var group:Dictionary=groups[key];var mm:MultiMesh=group.mm
		if not group.used:
			if mm.visible_instance_count!=0:mm.visible_instance_count=0
			if group.visible:RenderingServer.canvas_item_set_visible(group.rid,false);group.visible=false
			unused+=1
			if unused>MAX_UNUSED:RenderingServer.free_rid(group.rid);erase.append(key)
			continue
		var count=group.transforms.size()
		var resized=mm.instance_count<count
		if resized:mm.instance_count=ceili(float(count)/16)*16
		if mm.visible_instance_count!=count:mm.visible_instance_count=count
		if resized or group.previous!=group.transforms:
			for i in count:mm.set_instance_transform_2d(i,group.transforms[i])
			group.previous=group.transforms.duplicate()
		if group.last_order!=group.order:RenderingServer.canvas_item_set_draw_index(group.rid,group.order);group.last_order=group.order
		if not group.visible:RenderingServer.canvas_item_set_visible(group.rid,true);group.visible=true
	for key in erase:groups.erase(key)
func stats()->Dictionary:
	var active=0;var instances=0
	for group in groups.values():
		if group.used:active+=1;instances+=group.transforms.size()
	return {"groups":groups.size(),"active_groups":active,"instances":instances}
func _notification(what):
	if what==NOTIFICATION_PREDELETE:
		for group in groups.values():RenderingServer.free_rid(group.rid)
		groups.clear();parents.clear();dirty=false
func dispose():
	for group in groups.values():RenderingServer.free_rid(group.rid)
	groups.clear();parents.clear();dirty=false
