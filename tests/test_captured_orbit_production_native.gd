extends "res://tests/test_captured_orbit_native_near_contact.gd"

func make_fixture(db,snapshot:Dictionary,prototype:bool)->Dictionary:
	var fixture=super.make_fixture(db,snapshot,false)
	fixture.world.use_native_sweep=false;fixture.world.use_wide_near_contact=false
	if not prototype:return fixture
	var world=World.new()
	world.use_native_sweep=true;world.native_available=world.native_accel.ready()
	check(world.native_available,"Production native library is loaded")
	world.use_near_contact_probe=true;world.use_wide_near_contact=true;world.use_wall_overlap_memo=false
	world.reset_cave(bool(snapshot.terrain.enabled),int(snapshot.terrain.seed_value))
	for key in snapshot.terrain:world.set(key,snapshot.terrain[key].duplicate(true) if snapshot.terrain[key] is Dictionary or snapshot.terrain[key] is Array else snapshot.terrain[key])
	fixture.world=world;fixture.battle.terrain=world;fixture.body.terrain=world
	return fixture
