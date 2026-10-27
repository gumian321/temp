extends SceneTree
func _initialize():
	var path=OS.get_environment("RBPEW_BATTLE_SNAPSHOT")
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:printerr("Snapshot not found");quit(2);return
	var snapshot=file.get_var(false)
	if not snapshot is Dictionary or snapshot.get("format")!=2:printerr("Invalid diagnostic format");quit(2);return
	var report={"elapsed":snapshot.run_elapsed,"terrain_chunks":snapshot.terrain.chunks.size(),"systems":{}}
	print("SNAPSHOT_SYSTEM_KEYS=",snapshot["states"].keys())
	for key in snapshot["states"]:
		var data=snapshot["states"][key]
		if not data is Dictionary:printerr("INVALID_SYSTEM=",key," TYPE=",typeof(data));continue
		report.systems[key]={"keys":data["values"].keys(),"random":data["random"].keys(),"skipped":data["skipped"]}
	var critical={"actors":snapshot["states"]["combat"]["values"].get("enemies",[]).size(),"parts":snapshot["states"]["player"]["values"].get("parts",[]).size(),"bullets":snapshot["states"]["combat"]["values"].get("bullets",[]).size()}
	report.critical=critical
	print(JSON.stringify(report));quit(0 if critical.actors>0 and critical.parts>0 else 1)
