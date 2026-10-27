extends SceneTree
const World=preload("res://scripts/cave_world.gd")
func _initialize():call_deferred("execute")
func execute():
	var raw=World.new();raw.reset_cave(true);raw.use_material_certificates=false
	var current=World.new();current.reset_cave(true)
	var rng=RandomNumberGenerator.new();rng.seed=20261026
	var queries=0;var differences=0
	for i in 160:
		var base=Vector2(rng.randf_range(-1600,2400),rng.randf_range(-1000,1200)).snapped(Vector2.ONE*8)
		for r in [0.0,.0001,6.0,15.0,28.0,64.0,108.723,288.0,512.0]:
			for offset in [Vector2.ZERO,Vector2(.1,.1),Vector2(3.9,-3.8)]:
				var point=base+offset
				if current.wall_blocked(point,r)!=raw.wall_blocked(point,r):differences+=1
				queries+=1
	var edge_queries=0
	for y in range(-12,13):
		for edge in raw.collision_row(y,-18,45):
			var middle=(edge.a+edge.b)*.5
			for radius in [0.0,.0001,1.0,15.0,64.0,288.0]:
				var tangent=middle+edge.normal*radius
				current.wall_blocked(tangent-edge.normal*.1,radius)
				for epsilon in [-.01,-.0001,0.0,.0001,.01]:
					var point=tangent+edge.normal*epsilon
					if current.wall_blocked(point,radius)!=raw.wall_blocked(point,radius):differences+=1
					edge_queries+=1
			if edge_queries>6000:break
		if edge_queries>6000:break
	var edited=World.new();edited.reset_cave(true)
	var edit_raw=World.new();edit_raw.reset_cave(true);edit_raw.use_material_certificates=false
	var far=Vector2(600,600)
	var far_is_rock=edit_raw.wall_blocked(far,0)
	edited.wall_blocked(far,288)
	var hit=edit_raw.wall_hit(Vector2.ZERO,Vector2(1000,0),28)
	var head:Vector2=hit.position+hit.normal*.4
	var near=head+Vector2.RIGHT*35
	edited.wall_blocked(near,28)
	for tick in 120:
		for world in [edited,edit_raw]:world.dig(head,Vector2.RIGHT,Vector2.RIGHT,28,1.0/60)
	var before_hits=edited.material_certificate_hits
	var far_result=edited.wall_blocked(far,288)
	var distant_retained=far_is_rock and edited.removed_count>0 and edited.material_certificate_hits==before_hits+1 and far_result==edit_raw.wall_blocked(far,288)
	var before_misses=edited.material_certificate_misses
	var near_result=edited.wall_blocked(near,28)
	var nearby_invalidated=edited.material_certificate_misses==before_misses+1 and near_result==edit_raw.wall_blocked(near,28)
	edited.revision+=1;edit_raw.revision+=1
	before_misses=edited.material_certificate_misses
	var revision_result=edited.wall_blocked(far,288)
	var unknown_revision=edited.material_certificate_misses==before_misses+1 and revision_result==edit_raw.wall_blocked(far,288)
	for i in World.MATERIAL_CERTIFICATE_LIMIT+101:edited.store_material_certificate(far,Vector2i(far/World.CELL),Vector2(i*8,0))
	var bounded=edited.material_certificates.size()==World.MATERIAL_CERTIFICATE_LIMIT and edited.material_certificate_ring.size()==World.MATERIAL_CERTIFICATE_LIMIT
	edited.reset_cave(true,77);edit_raw.reset_cave(true,77)
	var reset=edited.material_certificates.is_empty() and edited.material_certificate_hits==0 and edited.wall_blocked(far,288)==edit_raw.wall_blocked(far,288)
	var report={"queries":queries,"edge_queries":edge_queries,"differences":differences,"witness_hits":current.material_certificate_hits,"witness_builds":current.material_certificate_builds,"distant_retained":distant_retained,"nearby_invalidated":nearby_invalidated,"unknown_revision":unknown_revision,"bounded":bounded,"reset":reset}
	var passed=differences==0 and distant_retained and nearby_invalidated and unknown_revision and bounded and reset
	print(JSON.stringify(report));FileAccess.open("res://artifacts/deep-clearance-certificates.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));quit(0 if passed else 1)
