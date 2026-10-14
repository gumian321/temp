extends SceneTree
## User-requested profile change. The exact expected user directory is required.
const DB=preload("res://scripts/source_db.gd")
const Save=preload("res://scripts/save_store.gd")
func _initialize():call_deferred("execute")
func fail(message:String):
	printerr("ERROR: ",message);quit(1)
func execute():
	var args=OS.get_cmdline_user_args()
	var key=args.find("--expected-user-dir")
	if key<0 or key+1>=args.size():fail("An exact expected user directory is required");return
	var actual=OS.get_user_data_dir().replace("\\","/").trim_suffix("/")
	var expected=String(args[key+1]).replace("\\","/").trim_suffix("/")
	if actual.to_lower()!=expected.to_lower():fail("Unexpected player profile directory: "+actual);return
	var target="user://centipede-save.json"
	if not FileAccess.file_exists(target):fail("Existing player save was not found");return
	var original=JSON.parse_string(FileAccess.get_file_as_string(target))
	if not original is Dictionary or original.get("version")!=1:fail("Existing save is invalid");return
	var backup_dir=ProjectSettings.globalize_path("res://artifacts/profile-unlock")
	if DirAccess.make_dir_recursive_absolute(backup_dir)!=OK:fail("Cannot create the backup directory");return
	var backup=backup_dir+"/centipede-save-before-2026-10-14-"+str(int(Time.get_unix_time_from_system()))+".json"
	if DirAccess.copy_absolute(target,backup)!=OK:fail("Cannot back up the original save");return
	var store=Save.new(DB.new())
	if not store.unlock_all_content():fail("Cannot save unlocked content; original backup retained");return
	var after=JSON.parse_string(FileAccess.get_file_as_string(target))
	for field in ["meta","settings","scores","statistics","tutorials","achievements","blueprint"]:
		if after.get(field)!=original.get(field):fail("Unexpected change to preserved field: "+field);return
	# A game already running may later save its old in-memory profile. Replay this
	# authorized unlock once on the next normal launch, after that game exits.
	var request=FileAccess.open(Save.FULL_UNLOCK_REQUEST,FileAccess.WRITE)
	if request==null:fail("Cannot stage the next-launch unlock request");return
	request.store_string("unlock-all");request.close()
	var report={"save_path":ProjectSettings.globalize_path(target),"backup":backup,"characters":store.state.roster_unlocked,"missions":store.state.missions.size(),"unlocked_rewards":store.state.unlocked.size(),"research_nodes":store.db.research.size(),"preserved_fields_verified":true,"next_launch_request":true}
	FileAccess.open("res://artifacts/profile-unlock/unlock-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit(0)
