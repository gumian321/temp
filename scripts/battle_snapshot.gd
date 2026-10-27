extends RefCounted
## Diagnostic state only: derived nodes, spatial indexes and A* objects are
## rebuilt by a replay. This is never loaded by ordinary player save handling.
static func pure(value,depth:int=0)->bool:
	if depth>32:return false
	if value is Object or value is Callable or value is Signal:return false
	if value is Dictionary:
		for key in value:
			if not pure(key,depth+1) or not pure(value[key],depth+1):return false
	elif value is Array:
		for item in value:
			if not pure(item,depth+1):return false
	return true

static func state(source,excluded:Array=[])->Dictionary:
	var values={};var random={};var skipped:Array=[]
	if source==null:return {"values":values,"random":random,"skipped":skipped}
	for property in source.get_property_list():
		if not (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE):continue
		var key:String=property.name
		if key in excluded:continue
		var value=source.get(key)
		if value is RandomNumberGenerator:
			random[key]={"seed":value.seed,"state":value.state}
		elif pure(value):values[key]=value
		else:skipped.append(key)
	return {"values":values,"random":random,"skipped":skipped}

static func navigation_state(world)->Dictionary:
	# Navigation's partially prepared cells affect route availability. Preserve
	# their decisions without serializing an AStar object or collision geometry.
	var values={};var grids=[]
	for key in ["nav_open","nav_clear_certificates","nav_clear_certificate_revision","nav_budget_active","nav_replans","nav_serial","nav_cells_left","nav_clock_ms","nav_waiting","nav_ticket_serial","nav_ticket_head","nav_frame","nav_prepare_us"]:values[key]=world.get(key)
	for bucket in world.nav_grids:
		var source:Dictionary=world.nav_grids[bucket]
		var data={};var solidity={}
		for key in source:
			if key!="grid" and pure(source[key]):data[key]=source[key]
		for id in source.filled:solidity[id]=source.grid.is_point_solid(id)
		grids.append({"bucket":bucket,"data":data,"solidity":solidity})
	return {"values":values,"grids":grids}

static func restore_navigation(world,saved:Dictionary):
	for key in saved.get("values",{}):world.set(key,saved["values"][key])
	world.nav_grids.clear()
	for item in saved.get("grids",[]):
		var data:Dictionary=item.data.duplicate(true)
		var grid=AStarGrid2D.new()
		grid.region=data.region;grid.cell_size=Vector2.ONE*world.NAV_STEP;grid.offset=Vector2.ONE*world.NAV_STEP*.5
		grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE;grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE
		grid.update();grid.fill_solid_region(data.region,true)
		for id in item.solidity:grid.set_point_solid(id,item.solidity[id])
		data.grid=grid;world.nav_grids[item.bucket]=data

static func capture(game)->Dictionary:
	var battle=game.combat;var run=game.run;var world=game.charcoal_terrain.world
	var systems={"player":game.player,"combat":battle,"run":run,
		"map":run.map_director,"director":run.director,"rewards":run.rewards,
		"encounters":run.encounters,"abilities":battle.character_abilities,
		"special":battle.special,"mutations":battle.mutation_weapons,
		"controls":battle.insect_control_system,"momentum":battle.momentum,
		"achievements":run.achievements,"player_legs":game.player_legs}
	var states={}
	for key in systems:
		states[key]=state(systems[key],["performance_samples","deployment_report","options_draft","profile_enabled","diagnostic_profile","phase_times","diagnostic_times","spatial_active","cached_player_shields","player_shield_cache_active"])
	var main_values={}
	for key in ["screen","difficulty","center","camera","aim","zoom","test_time","leg_phase","radar_mode","shown_bosses","hit_pause_left","hit_pause_cooldown","camera_recoil"]:main_values[key]=game.get(key)
	states["main"]={"values":main_values,"random":{},"skipped":["derived UI and render nodes"]}
	for key in ["spider_rig","coil_rig","flagella","fragment_recovery","motion"]:
		var child=game.player.get(key)
		if child!=null:states["player_"+key]=state(child)
	if run.rewards.get("pacing")!=null:states["pacing"]=state(run.rewards.pacing)
	var terrain={}
	for key in ["enabled","seed_value","chunks","revision","removed_count","ore_total","bite_timer","bite_serial","mining_active","mining_point","events","loot_events","nav_clock_ms"]:
		terrain[key]=world.get(key)
	return {"format":2,"scope":"Pure simulation state and RNGs with actual excavated terrain. Derived render nodes, spatial indexes and A* grids are excluded; diagnostic replay is not a complete player save or a real-clock longrun.",
		"run_elapsed":run.elapsed,"engine":Engine.get_version_info(),"states":states,"terrain":terrain,
		"navigation":navigation_state(world),
		"viewport":game.get_viewport_rect().size,"captured_frame":Engine.get_process_frames(),"save_state":game.save.state.duplicate(true)}

static func apply_state(target,data:Dictionary):
	for key in data.get("values",{}):
		if str(key).begins_with("use_") or key in ["profile_enabled","diagnostic_profile","performance_profile_enabled"]:continue
		if key=="detached_fragments" and target.get("fragment_recovery")!=null:
			target.fragment_recovery.groups=data["values"][key];continue
		target.set(key,data["values"][key])
	for key in data.get("random",{}):
		var rng=target.get(key)
		if rng is RandomNumberGenerator:rng.seed=data.random[key].seed;rng.state=data.random[key].state
