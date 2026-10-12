extends SceneTree
func _initialize():
 var db=load('res://scripts/source_db.gd').new()
 var save=load('res://scripts/save_store.gd').new(db)
 var expected=JSON.parse_string(FileAccess.get_file_as_string('res://artifacts/ui-probe.json'))
 var ok=save.state.unlocked.size()==int(expected.unlocked) and save.state.meta==int(expected.meta)
 var report={'passed':ok,'fresh_process':true,'actual_unlocked':save.state.unlocked.size(),'expected_unlocked':expected.unlocked,'actual_currency':save.state.meta,'expected_currency':expected.meta}
 print(JSON.stringify(report));FileAccess.open('res://artifacts/restart-save-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));quit(0 if ok else 1)
