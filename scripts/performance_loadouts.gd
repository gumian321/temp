extends RefCounted
## Reconstructed from the player's two screenshots. Exact reward history is
## unknown; the optional mine-capacity bonus reproduces the roughly 30 eggs.
const MODULES=[
	["Core_Gun_Tesla",2], ["Core_Gun_Shotgun",1], ["Core_Drones_Engineer",1],
	["Core_Clocking",2], ["Core_Gun_Tesla",1], ["Core_Drones_Scrapper",1],
	["Core_MinesField",1], ["Core_Gun_Rocket",1], ["Core_Gun_Flak",1],
	["Core_Drones_Attack",2], ["Core_Gun_Sniper",1]]

static func install(player,db,capacity_bonus:bool=true):
	for module in MODULES:
		player.append_segment(db.named(module[0]).id)
		player.parts[-1].fusion_level=module[1]
	if capacity_bonus:
		var id="fixture-mine-capacity"
		db.catalog[id]={"id":id,"name":"Fixture_MineCapacity","class":"FixtureReward","coresList":[db.named("Core_MinesField").id],"maxMinesCountPercent":.5}
		player.levels[id]=1
	player.refresh_upgrades();player.refresh_positions()

static func names()->Array:
	return MODULES.map(func(module):return module[0])
