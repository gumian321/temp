extends RefCounted
## This thread owns every file handle. The render/game thread only queues text.
const OWNER="rbpew-performance-log-v1"
const MAX_PENDING=256
var max_part_bytes=8*1024*1024
var keep_parts=3
var keep_sessions=4
var root_path=""
var session_path=""
var header_line=""
var thread=Thread.new()
var mutex=Mutex.new()
var wake=Semaphore.new()
var pending:Array[String]=[]
var closing=false
var error_message=""
var dropped_lines=0
var flush_pending=false

func start(directory:String,session_name:String,header:Dictionary)->Error:
	root_path=directory.simplify_path();session_path=root_path.path_join(session_name)
	header_line=JSON.stringify(header)
	return thread.start(_write_loop)

func push(record:Dictionary):
	var line=JSON.stringify(record)
	mutex.lock()
	if not closing and error_message.is_empty():
		if pending.size()<MAX_PENDING:pending.append(line)
		else:dropped_lines+=1
	mutex.unlock();wake.post()

func status()->Dictionary:
	mutex.lock();var result={"error":error_message,"dropped_lines":dropped_lines,"pending":pending.size()};mutex.unlock()
	return result

func close():
	if not thread.is_started():return
	mutex.lock();closing=true;mutex.unlock();wake.post();thread.wait_to_finish()

func flush():
	mutex.lock();flush_pending=true;mutex.unlock();wake.post()

func fail(message:String):
	mutex.lock();error_message=message;pending.clear();mutex.unlock()

func _write_loop():
	if DirAccess.make_dir_recursive_absolute(session_path)!=OK:fail("Cannot create log directory");return
	var marker={"owner":OWNER,"session":session_path.get_file(),"closed":false}
	var info=FileAccess.open(session_path.path_join("session.json"),FileAccess.WRITE)
	if info==null:fail("Cannot write log metadata");return
	info.store_string(JSON.stringify(marker));info.close()
	var latest=FileAccess.open(root_path.path_join("latest-session.json"),FileAccess.WRITE)
	if latest!=null:latest.store_string(JSON.stringify(marker));latest.close()
	prune_sessions()
	var part=1;var file=open_part(part)
	if file==null:fail("Cannot open performance log");return
	var flushed=Time.get_ticks_usec()
	while true:
		wake.wait()
		mutex.lock();var batch=pending;pending=[];var finish=closing;var force_flush=flush_pending;flush_pending=false;mutex.unlock()
		for line in batch:
			if file.get_position()+line.to_utf8_buffer().size()+1>max_part_bytes:
				file.flush();file.close();part+=1;file=open_part(part)
				if file==null:fail("Cannot rotate performance log");return
				if part>keep_parts:DirAccess.remove_absolute(session_path.path_join("part-%03d.jsonl"%(part-keep_parts)))
			file.store_line(line)
		if finish or force_flush or Time.get_ticks_usec()-flushed>=1000000:
			file.flush();flushed=Time.get_ticks_usec()
		if finish:break
	file.close();marker.closed=true
	info=FileAccess.open(session_path.path_join("session.json"),FileAccess.WRITE)
	if info!=null:info.store_string(JSON.stringify(marker));info.close()

func open_part(part:int):
	var file=FileAccess.open(session_path.path_join("part-%03d.jsonl"%part),FileAccess.WRITE)
	if file!=null:file.store_line(header_line);file.store_line(JSON.stringify({"type":"part","index":part}))
	return file

func prune_sessions():
	var directory=DirAccess.open(root_path)
	if directory==null:return
	var owned:Array[String]=[]
	for name in directory.get_directories():
		if not name.begins_with("run-"):continue
		var marker=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join(name).path_join("session.json"))) if FileAccess.file_exists(root_path.path_join(name).path_join("session.json")) else null
		if marker is Dictionary and marker.get("owner")==OWNER:owned.append(name)
	owned.sort()
	while owned.size()>keep_sessions:
		var name=owned.pop_front();var folder=root_path.path_join(name).simplify_path()
		if folder==session_path or not folder.begins_with(root_path+"/"):continue
		var old=DirAccess.open(folder)
		if old==null:continue
		# Delete only this writer's exact filenames; never recursively delete a
		# directory or remove screenshots, notes or files added by the player.
		for filename in old.get_files():
			if filename=="session.json" or (filename.length()==14 and filename.begins_with("part-") and filename.ends_with(".jsonl") and filename.substr(5,3).is_valid_int()):
				DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
