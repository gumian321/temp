extends "res://scripts/grid_centipede.gd"
## One element per segment. Array indices stay stable when the chain is reordered
## so drones and deployed devices retain their existing combat owners.

func reset():
	resting_segments = 0
	grown_segments = 0
	super.reset()

func segment_count() -> int:
	return maxi(0, parts.size() - 1)

func body_part_indices() -> Array:
	var order: Array = range(1, parts.size())
	order.sort_custom(func(a,b):return int(parts[a].get("segment",a))<int(parts[b].get("segment",b)))
	return order

func segment_index(index: int) -> int:
	return 0 if index==0 else int(parts[index].segment)

func mount_cell(segment: int, _slot: int = 4) -> Vector2i:
	return Vector2i(-segment,0)

func slot_offset(_slot: int) -> Vector2:
	return Vector2.ZERO

func part_at(segment: int, _slot: int = 4) -> int:
	for index in range(1,parts.size()):
		if int(parts[index].segment)==segment:return index
	return -1

func parts_on_segment(segment: int) -> Array:
	var index = part_at(segment)
	return [index] if index>0 else []

func can_mount(segment: int, _slot: int = 4, _ignore: int = -1) -> bool:
	if segment<1 or segment>segment_count()+1:
		last_error="请选择身体之间的位置，或拖到尾部。"
		return false
	return true

func install_module(id: String, before: int, _slot: int = 4) -> bool:
	if segment_count()>=int(db.stores.PlayerDataStore.maxBuiltCores):
		last_error="身体最多可长到 60 节。"
		return false
	if db.asset(id).is_empty() or not can_mount(before):return false
	for part in parts.slice(1):
		if int(part.segment)>=before:part.segment+=1
	var part = make_part(id,mount_cell(before))
	part.segment=before;part.slot=4
	parts.append(part)
	built_count+=1;built_score+=int(db.asset(id).get("coreRatePrize",0))
	refresh_positions();refresh_upgrades();last_error=""
	return true

func first_free_mount() -> Vector2i:
	return Vector2i(segment_count()+1,4)

func append_segment(id: String) -> bool:
	return install_module(id,segment_count()+1)

func move_to_mount(index: int, before: int, _slot: int = 4) -> bool:
	if index<=0 or index>=parts.size() or not can_mount(before):return false
	var order = body_part_indices()
	var start = order.find(index)
	var destination = before-1
	if destination==start or destination==start+1:return false
	order.remove_at(start)
	if destination>start:destination-=1
	order.insert(destination,index)
	for i in order.size():parts[order[i]].segment=i+1
	refresh_positions();last_error=""
	return true

func move_piece_to_segment(index: int, before: int) -> bool:
	return move_to_mount(index,before)

func swap_piece(a: int,b: int) -> bool:
	if a<=0 or b<=0 or a>=parts.size() or b>=parts.size() or a==b:return false
	var segment=int(parts[a].segment)
	parts[a].segment=parts[b].segment;parts[b].segment=segment
	refresh_positions()
	return true

func duplicate_to_mount(index: int,before: int,_slot: int = 4) -> bool:
	if index<=0 or index>=parts.size() or actions.duplicate<=0:return false
	if parts.size()+pending.size()>int(db.stores.PlayerDataStore.maxBuiltCores):return false
	if not install_module(parts[index].id,before):return false
	actions.duplicate-=1
	return true

func refresh_positions():
	var order = body_part_indices()
	for i in order.size():
		var part:Dictionary=parts[order[i]]
		part.segment=i+1;part.slot=4;part.cell=mount_cell(i+1)
	grown_segments=segment_count()
	super.refresh_positions()

func adjacent_part_indices(index: int,include_self: bool = false) -> Array:
	var result:Array=[]
	if index<0 or index>=parts.size():return result
	var segment=segment_index(index)
	if include_self:result.append(index)
	for other in range(parts.size()):
		if absi(segment_index(other)-segment)==1:result.append(other)
	return result

func module_size(index: int) -> float:
	return 42.0 if index==0 else 56.0

func display_slot_offset(segment: int,_slot: int = 4,_additional: int = 0) -> Vector2:
	return Vector2(0,-6 if segment%2 else 6)

func collision_radius(index: int) -> float:
	return 30.0 if index==0 else 27.0

func reward_module_count(_reward:Dictionary) -> int:
	return 1

func uses_build_actions() -> bool:
	return false
