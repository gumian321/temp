extends SceneTree
## Read-only movement diagnosis from an actual run, not an FPS acceptance test.
const World=preload("res://scripts/cave_world.gd")
const Pits=preload("res://scripts/chasm_world.gd")
func _initialize():call_deferred("execute")
func legacy_blocked(world,pits,point:Vector2,radius:float)->bool:
	for pit in world.nearby(Rect2(point,Vector2.ZERO).grow(radius)):
		if pits.contains(pit,point,radius):return true
	return false
func execute():
	var path=OS.get_environment("RBPEW_BATTLE_SNAPSHOT")
	if path.is_empty():path="res://artifacts/deep50-candidate3-live-20261026/stop-states/0679-battle-state.bin"
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:push_error("Captured movement snapshot missing");quit(2);return
	var snapshot=file.get_var(false);file.close()
	if not snapshot is Dictionary or snapshot.get("format")!=2:push_error("Invalid captured movement format");quit(2);return
	var player:Dictionary=snapshot.states.player["values"]
	var world=World.new();world.reset_cave(bool(snapshot.terrain.enabled),int(snapshot.terrain.seed_value))
	for key in snapshot.terrain:world.set(key,snapshot.terrain[key])
	var at:Vector2=player.head;var radius=30.0;var pits=Pits.new();var probes=[];var finite=true
	var start={"position":at,"radius":radius,"wall_blocked":world.wall_blocked(at,radius),"pit_blocked":legacy_blocked(world,pits,at,radius),"facing":player.facing,"input":player.input_velocity,"velocity":player.velocity}
	for index in 16:
		var direction=Vector2.from_angle(float(index)*TAU/16)
		for distance in [2.0,8.0,30.0,60.0]:
			var point:Vector2=world.move(at,at+direction*distance,radius)
			finite=finite and is_finite(point.x) and is_finite(point.y)
			probes.append({"heading":index,"distance":distance,"displacement":point-at,"traveled":at.distance_to(point),"wall_blocked":world.wall_blocked(point,radius),"pit_blocked":legacy_blocked(world,pits,point,radius)})
	var report={"scope":"Captured native head and excavated terrain, pure movement queries; no battle advance, health override or frame-rate claim.","passed":finite,"run_elapsed":snapshot.run_elapsed,"start":start,"probes":probes}
	FileAccess.open("res://artifacts/deep50-captured-hybrid-motion.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"passed":finite,"run_elapsed":snapshot.run_elapsed,"start":start,"probes":probes.size()}));quit(0 if finite else 1)
