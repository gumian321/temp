extends SceneTree
func _initialize():call_deferred('execute')
func execute():
 var db=load('res://scripts/source_db.gd').new();var fx=load('res://scripts/particle_effects.gd').new();root.add_child(fx);fx.setup(db)
 for type in range(300,310):fx.play(type,Vector2.ZERO)
 await process_frame
 var count=fx.get_child_count();var finite=true
 for node in fx.get_children():finite=finite and node.amount>0 and node.lifetime>0 and is_finite(node.scale_amount_max)
 fx.clear();await process_frame;await create_timer(0.15).timeout
 var report={'source_effects':fx.definitions.size(),'source_emitters':count,'valid_properties':finite,'cleared':fx.get_child_count()==0,'passed':count==24 and finite and fx.get_child_count()==0,'scope':'Imported ten source particle presets and 24 emitters instantiate and clean up; visual shader/noise equivalence is not asserted.'}
 FileAccess.open('res://artifacts/particles-test-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));fx.queue_free();await process_frame;quit(0 if report.passed else 1)
