extends SceneTree
const Contours=preload("res://scripts/cave_contour_mesh.gd")
const World=preload("res://scripts/cave_world.gd")
var checks:Array=[]
func _initialize():call_deferred("execute")
func check(value:bool,label:String):
	checks.append({"passed":value,"label":label})
	if not value:push_error(label)
func encoded(shape:Dictionary)->PackedByteArray:return var_to_bytes(shape)
func execute():
	Contours.use_fractured_templates=true;Contours.clear_fractured_cache()
	for mask in [0,1,510,511]:
		Contours.fractured_template(mask,Vector2i(-17,9),20261026)
	var cheap=Contours.cache_stats()
	check(cheap.entries==0 and cheap.builds==0 and cheap.misses==0,"Constant masks and extrema shortcuts never occupy the expensive final-template ring")
	var equal=true;var comparisons=0;var seed_variants=0
	var positions=[Vector2i.ZERO,Vector2i(-17,9),Vector2i(31,-32),Vector2i(-10000,9000)]
	for seed_value in [20261026,7,-43,-2147483648]:
		for cell in positions:
			for mask in 512:
				Contours.use_fractured_templates=false
				var reference=encoded(Contours.fractured_template(mask,cell,seed_value))
				Contours.use_fractured_templates=true
				var first=Contours.fractured_template(mask,cell,seed_value)
				var second=Contours.fractured_template(mask,cell,seed_value)
				equal=equal and encoded(first)==reference and encoded(second)==reference and is_same(first,second);comparisons+=2
	check(equal,"Every serialized float, polygon ordering and outline matches legacy exactly for all 512 masks, four seeds and four signed/seam/far cells; warm returns share immutable ownership")
	var differential_stats=Contours.cache_stats()
	var cell=Vector2i(-17,9)
	var old=Contours.fractured_template(16,cell,7);var held=encoded(old)
	for mask in [17,24,144,0,511]:Contours.fractured_template(mask,cell,7)
	for seed_value in [8,9,10]:
		if encoded(Contours.fractured_template(16,cell,seed_value))!=held:seed_variants+=1
	check(encoded(old)==held and seed_variants>0,"Changing the excavation mask or seed cannot overwrite a retained immutable result")
	# The older bias cache already stores seed in Vector3i. Do not claim to
	# repair that pre-existing wide-seed behavior; prove this memo adds no new
	# alias and that wide seeds execute the exact current legacy path.
	Contours.clear_fractured_cache()
	Contours.fractured_template(16,cell,1)
	var hits=Contours.cache_stats().hits;var entries=Contours.cache_stats().entries
	Contours.use_fractured_templates=false
	var wide_reference=encoded(Contours.fractured_template(16,cell,1+(1<<32)))
	Contours.use_fractured_templates=true
	var wide_result=Contours.fractured_template(16,cell,1+(1<<32))
	var wide_stats=Contours.cache_stats()
	check(encoded(wide_result)==wide_reference and wide_stats.hits==hits and wide_stats.entries==entries and wide_stats.seed_fallbacks==1,"Seeds 1 and 1+2^32 cannot alias in the new memo; out-of-int32 seeds explicitly follow existing legacy behavior")
	# The world projection reads local points then allocates its own arrays.
	# Verify that a real production caller does not mutate a shared source.
	var world=World.new();world.reset_cave(true,20261026)
	var source_cell=Vector2i.ZERO;var mask=0;var found_mixed=false
	for y in range(-20,21):
		for x in range(8,49):
			var candidate_cell=Vector2i(x,y);var candidate_mask=0
			for dy in 3:
				for dx in 3:
					if world.solid(candidate_cell+Vector2i(dx-1,dy-1)):candidate_mask|=1<<(dy*3+dx)
			if candidate_mask in [0,511]:continue
			Contours.density_samples(candidate_mask)
			var limits:Vector2=Contours.extrema[candidate_mask]
			if limits.x>=Contours.ISO+.055 or limits.y<Contours.ISO-.055:continue
			source_cell=candidate_cell;mask=candidate_mask;found_mixed=true;break
		if found_mixed:break
	var source=Contours.fractured_template(mask,source_cell,20261026);var before=encoded(source)
	world.cell_shape(source_cell)
	check(found_mixed and encoded(source)==before and is_same(source,Contours.fractured_template(mask,source_cell,20261026)),"Production world polygon projection leaves a shared mixed local-template's arrays unchanged")
	Contours.clear_fractured_cache()
	var first=Contours.fractured_template(16,Vector2i.ZERO,20261026);var first_bytes=encoded(first)
	for i in range(1,Contours.FRACTURED_TEMPLATE_LIMIT+17):Contours.fractured_template(16,Vector2i(i,-3),20261026)
	var bounded=Contours.cache_stats()
	check(bounded.entries==Contours.FRACTURED_TEMPLATE_LIMIT and Contours.fractured_template_ring.size()==Contours.FRACTURED_TEMPLATE_LIMIT and bounded.evicts==17,"An 8192-slot FIFO ring bounds all mixed final results without duplicate keys or whole-cache key snapshots")
	var last_cell=Vector2i(Contours.FRACTURED_TEMPLATE_LIMIT+16,-3)
	hits=bounded.hits
	for _repeat in 11:Contours.fractured_template(16,last_cell,20261026)
	check(Contours.cache_stats().hits==hits+11 and Contours.cache_stats().entries==Contours.FRACTURED_TEMPLATE_LIMIT and encoded(first)==first_bytes,"Hot hits do not consume slots and caller-held results survive eviction unchanged")
	var misses=Contours.cache_stats().misses
	Contours.fractured_template(16,Vector2i.ZERO,20261026)
	check(Contours.cache_stats().misses==misses+1 and Contours.cache_stats().evicts==18,"An evicted key rebuilds rather than borrowing another cell's cached template")
	var previous=Contours.cache_stats()
	Contours.use_fractured_templates=false
	Contours.fractured_template(16,last_cell,20261026)
	var disabled=Contours.cache_stats()
	check(disabled.hits==previous.hits and disabled.builds==previous.builds+1,"The legacy environment path bypasses final memo hits and retains original build logic")
	Contours.use_fractured_templates=true
	Contours.clear_fractured_cache(false)
	var preserved_stats=Contours.cache_stats()
	check(preserved_stats.entries==0 and Contours.fractured_template_ring.is_empty() and Contours.fractured_template_cursor==0 and preserved_stats.builds==disabled.builds,"Explicit cache clear releases all entries while optionally retaining measurement counters")
	Contours.clear_fractured_cache()
	var reset=Contours.cache_stats()
	check(reset.entries==0 and reset.hits==0 and reset.misses==0 and reset.builds==0 and reset.build_us==0 and reset.evicts==0 and reset.seed_fallbacks==0,"Explicit measurement reset clears all counters, slots and ownership")
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks,"strict_serialized_comparisons":comparisons,"differential_stats":differential_stats,"capacity_stats":bounded,"seed_variants":seed_variants,"scope":"Exact local-template serialization and immutable cache ownership; no frame-rate claim. Existing wide-seed bias-cache behavior is unchanged."}
	print(JSON.stringify(report));FileAccess.open("res://artifacts/deep-fractured-templates-20261026.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if report.passed else 1)
