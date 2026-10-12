extends Node
var db
var save
var music: AudioStreamPlayer
var voices: Array = []
var audio_paths: Dictionary
var category = ""
var listener = Vector2.ZERO
func setup(source,persistence):
	db=source;save=persistence
	audio_paths=db.read_json("audio")
	music=AudioStreamPlayer.new();add_child(music)
	music.finished.connect(func(): change_music(category,true))
	for i in range(30):
		var voice=AudioStreamPlayer.new();add_child(voice);voices.append(voice)
	change_music("menu")
func change_music(value: String,force: bool=false):
	if category==value and not force:return
	category=value
	var field={"menu":"MainMenuBackgroundAudioClipsList","game":"InGameAudioClipsList","boss":"InGameBossAudioClipsList"}.get(value,"MainMenuBackgroundAudioClipsList")
	var ids: Array=db.stores.AudioDataStore[field]
	if ids.is_empty():return
	var path:String=audio_paths.get(ids.pick_random(),"")
	if path.is_empty():return
	music.stop();music.stream=load(path);refresh();music.play()
func refresh():
	music.volume_db=linear_to_db(maxf(0.00001,float(save.state.settings.volume)*float(save.state.settings.music)))
func play(type:int,at:Vector2=Vector2.ZERO):
	var candidates=db.kind("AudioClipObject").filter(func(c):return int(c.audioClipEnum)==type)
	if candidates.is_empty():return
	var data:Dictionary=candidates[0]
	if voices.filter(func(v):return v.playing and v.get_meta("type",-1)==type).size()>=int(data.copiesPlayedAtOnce):return
	for voice in voices:
		if voice.playing:continue
		var path:String=audio_paths.get(data.audioClipList.pick_random(),"")
		if path.is_empty():return
		var attenuation=clampf(1-(at.distance_to(listener)/48-25)/15,0,1) if at!=Vector2.ZERO else 1.0
		voice.stream=load(path)
		voice.volume_db=linear_to_db(maxf(0.00001,float(data.volume)*float(save.state.settings.volume)*float(save.state.settings.sfx)*attenuation))
		voice.set_meta("type",type);voice.play();return
func shutdown():
	sync_loops([])
	music.stop();music.stream=null
	for voice in voices:voice.stop();voice.stream=null

var loops:Dictionary={}
func sync_loops(requests:Array):
	var alive:Dictionary={}
	for request in requests:
		var key:String=request.key
		alive[key]=true
		if not loops.has(key):
			var matches=db.kind('AudioClipObject').filter(func(c):return int(c.audioClipEnum)==int(request.type))
			if matches.is_empty():continue
			var data:Dictionary=matches[0]
			if loops.values().filter(func(v):return v.get_meta('type')==request.type).size()>=int(data.copiesPlayedAtOnce):continue
			var voice=AudioStreamPlayer.new();add_child(voice)
			var path:String=audio_paths.get(data.audioClipList.pick_random(),'')
			if path.is_empty():voice.queue_free();continue
			voice.stream=load(path).duplicate();voice.stream.loop=true
			voice.set_meta('type',request.type);voice.set_meta('gain',float(data.volume));voice.play();loops[key]=voice
		var voice:AudioStreamPlayer=loops[key]
		var attenuation=clampf(1-(Vector2(request.position).distance_to(listener)/48-25)/15,0,1)
		voice.volume_db=linear_to_db(maxf(0.00001,float(voice.get_meta('gain'))*float(save.state.settings.volume)*float(save.state.settings.sfx)*attenuation))
	for key in loops.keys():
		if not alive.has(key):loops[key].stop();loops[key].stream=null;loops[key].queue_free();loops.erase(key)
