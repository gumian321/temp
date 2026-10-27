extends SceneTree
const World=preload("res://scripts/cave_world.gd")
class EmptyWorld extends World:
	func original_solid(_cell:Vector2i)->bool:return false
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(passed:bool,label:String):
	checks.append({"passed":passed,"label":label})
	if not passed:push_error(label)
func signature(edges:Array)->Array:
	var result:Array=[]
	for edge in edges:result.append([edge.a,edge.b,edge.delta,edge.length_squared,edge.normal,edge.bounds,edge.cell])
	return result
func execute():
	var raw=World.new();raw.use_collision_blocks=false;raw.reset_cave(true)
	var cached=World.new();cached.reset_cave(true)
	var equal=true;var comparisons=0;var rng=RandomNumberGenerator.new();rng.seed=20261026
	for repeat in 2:
		for i in 140:
			var y=rng.randi_range(-26,26);var left=rng.randi_range(-80,70);var width=[0,1,7,15,16,17,31,47][i%8]
			equal=equal and signature(raw.collision_row(y,left,left+width))==signature(cached.collision_row(y,left,left+width));comparisons+=1
	check(equal,"Cold/hot overlapping ranges preserve every ordered contour edge across positive and negative block seams")
	var entry=raw.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
	var head:Vector2=entry.position+entry.normal*.4
	for tick in 200:
		for world in [raw,cached]:world.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
		var expected=raw.move(head,head+Vector2.RIGHT*2.2,28)
		equal=equal and expected==cached.move(head,head+Vector2.RIGHT*2.2,28);head=expected;comparisons+=1
		for y in range(-2,3):
			equal=equal and signature(raw.collision_row(y,12,35))==signature(cached.collision_row(y,12,35));comparisons+=1
	check(equal and cached.removed_count>0,"Excavation refreshes changed fragments and retains exact movement at chunk seams")
	# Public revision jumps are an explicit invalidation fallback, even when a
	# diagnostic editor replaced cells without updating individual chunk versions.
	for world in [raw,cached]:
		for y in range(-3,4):
			for x in range(10,37):
				var cell=Vector2i(x,y);world.chunk_at(world.chunk_id(cell)).solid[world.cell_index(cell)]=0
		world.geometry.clear();world.collision_rows.clear();world.revision+=1
	check(signature(raw.collision_row(0,10,36))==signature(cached.collision_row(0,10,36)),"Unexplained terrain revisions cannot reuse stale fragments")
	var empty=EmptyWorld.new();empty.reset_cave(true)
	for i in World.COLLISION_BLOCK_LIMIT+101:
		var x=(i%128)*World.CHUNK;empty.collision_row(i/128,x,x+1)
	check(empty.collision_blocks.size()==World.COLLISION_BLOCK_LIMIT and empty.collision_block_ring.size()==World.COLLISION_BLOCK_LIMIT,"A fixed 2048-slot ring bounds fragment blocks without whole-cache eviction")
	cached.reset_cave(true,31415)
	check(cached.collision_blocks.is_empty() and cached.collision_block_ring.is_empty() and cached.collision_fragment_hits==0,"A new world clears all fragment geometry and counters")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"row_and_movement_comparisons":comparisons}
	FileAccess.open("res://artifacts/cave-collision-blocks-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
