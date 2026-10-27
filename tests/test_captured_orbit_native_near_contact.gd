extends "res://tests/test_captured_orbit_near_contact.gd"
## Backup correctness fixture for the optional native prefix prototype.
## Inherited execution compares 120 production map ticks, full actor state,
## combat/loot RNGs and exact original-delta first-contact dictionaries/moves.
const NativeNearContactWorld=preload("res://tools/native_near_contact_world.gd")

func make_fixture(db,snapshot:Dictionary,prototype:bool)->Dictionary:
	# Both inherited lanes start with a production world. Only the candidate
	# is replaced by the optional native helper; no runtime file is changed.
	var fixture=super.make_fixture(db,snapshot,false)
	fixture.world.use_near_contact_probe=false
	if not prototype:return fixture
	var world=NativeNearContactWorld.new()
	check(world.native_kernel!=null,"Optional native sweep kernel is loaded; a GDScript fallback cannot pass as native coverage")
	world.use_near_contact_probe=true
	world.use_wall_overlap_memo=false
	world.reset_cave(bool(snapshot.terrain.enabled),int(snapshot.terrain.seed_value))
	for key in snapshot.terrain:world.set(key,snapshot.terrain[key].duplicate(true) if snapshot.terrain[key] is Dictionary or snapshot.terrain[key] is Array else snapshot.terrain[key])
	fixture.world=world;fixture.battle.terrain=world;fixture.body.terrain=world
	return fixture

func execute():
	# The inherited fixture reads this explicit diagnostic input. Default to
	# the complete first native 30-minute run; callers may select 915 instead.
	if OS.get_environment("RBPEW_BATTLE_SNAPSHOT").is_empty():
		OS.set_environment("RBPEW_BATTLE_SNAPSHOT","res://artifacts/cpu-depth-live-20261027/stop-states/1800-battle-state.bin")
	await super.execute()
