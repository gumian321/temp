extends Node
const Feedback = preload("res://scripts/weapon_feedback.gd")
var db
var save
var music: AudioStreamPlayer
var voices: Array = []
var audio_paths: Dictionary
var category = ""
var listener = Vector2.ZERO
var impact_voices: Array = []
var impact_streams: Dictionary = {}
var impact_times: Dictionary = {}
var duck_left = 0.0
var combat_bus = "Centipede Combat"
var owns_bus = false
func setup(source,persistence):
	db=source;save=persistence
	audio_paths=db.read_json("audio")
	if AudioServer.get_bus_index(combat_bus)<0:
		AudioServer.add_bus()
		var index=AudioServer.get_bus_count()-1
		AudioServer.set_bus_name(index,combat_bus)
		var limiter=AudioEffectLimiter.new()
		limiter.ceiling_db=-1.5; limiter.threshold_db=-3.0
		AudioServer.add_bus_effect(index,limiter)
		owns_bus=true
	music=AudioStreamPlayer.new();add_child(music)
	music.finished.connect(func(): change_music(category,true))
	for i in range(30):
		var voice=AudioStreamPlayer.new();voice.bus=combat_bus;add_child(voice);voices.append(voice)
	for i in range(8):
		var voice=AudioStreamPlayer.new();voice.bus=combat_bus;add_child(voice);impact_voices.append(voice)
	change_music("menu")

func _process(dt: float):
	if duck_left<=0 or music==null:return
	duck_left=maxf(0,duck_left-dt)
	refresh()
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
	music.volume_db=linear_to_db(maxf(0.00001,float(save.state.settings.volume)*float(save.state.settings.music)))-minf(1,duck_left/0.16)*3.5
func play(type:int,at:Vector2=Vector2.ZERO,gain:float=1.0,pitch:float=1.0):
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
		voice.volume_db=linear_to_db(maxf(0.00001,float(data.volume)*float(save.state.settings.volume)*float(save.state.settings.sfx)*attenuation*gain))
		voice.pitch_scale=clampf(pitch,0.75,1.2)
		voice.set_meta("type",type);voice.play();return

func play_event(event: Dictionary):
	if int(event.get("type",-1))>=0:play(event.type,event.position,float(event.get("gain",1)),float(event.get("pitch",1)))
	if event.has("feedback"): impact(str(event.feedback),event.position,float(event.get("strength",0.6)))
	if event.get("flesh",false):impact("flesh",event.position,float(event.get("flesh_strength",.8)))

func impact(family: String, at: Vector2, strength: float):
	var now=Time.get_ticks_msec()
	if now-int(impact_times.get(family,-1000))<55:return
	var attenuation=clampf(1-at.distance_to(listener)/1500.0,0,1)
	if attenuation<=0:return
	for voice in impact_voices:
		if voice.playing:continue
		impact_times[family]=now
		if not impact_streams.has(family):impact_streams[family]=make_impact(family)
		voice.stream=impact_streams[family]
		voice.pitch_scale=1.0+sin(now*0.019)*0.025
		voice.volume_db=linear_to_db(maxf(0.00001,0.36*strength*attenuation*float(save.state.settings.volume)*float(save.state.settings.sfx)))
		voice.play()
		if strength>=1.0:duck_left=0.2
		return

func make_impact(family: String) -> AudioStreamWAV:
	if family=="flesh":return preload("res://scripts/insect_hit_audio.gd").make_stream()
	# A short dry transient and a decaying body underneath the original recording.
	# Private seeded noise cannot affect combat or loot random-number sequences.
	var style=Feedback.profile(family)
	var electrical=family in ["tesla","emp","rail","sonic","blackhole"]
	var duration=0.14+style.weight*0.035
	var sample_rate=22050
	var samples=int(duration*sample_rate)
	var bytes=PackedByteArray();bytes.resize(samples*2)
	var noise=RandomNumberGenerator.new();noise.seed=family.hash()
	var phase=0.0
	var previous_noise=0.0
	for i in range(samples):
		var t=float(i)/sample_rate
		var p=t/duration
		var frequency=lerpf(180.0 if electrical else 125.0,65.0 if electrical else 42.0,p)/maxf(0.8,style.weight*0.65)
		phase+=TAU*frequency/sample_rate
		var envelope=pow(1-p,3.0)*minf(1,t*1500)
		var random=noise.randf_range(-1,1)
		var crack=(random-previous_noise)*exp(-t*(75 if electrical else 110))*0.30
		previous_noise=random
		var body=sin(phase)*0.46*envelope
		var ring=sin(t*TAU*(1250 if electrical else 740))*exp(-t*42)*0.12
		var value=(body+crack+ring)*minf(1,(duration-t)*180)
		bytes.encode_s16(i*2,int(clampf(value,-0.92,0.92)*32767))
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=sample_rate;stream.stereo=false;stream.data=bytes
	return stream
func shutdown():
	sync_loops([])
	music.stop();music.stream=null
	for voice in voices:voice.stop();voice.stream=null
	for voice in impact_voices:voice.stop();voice.stream=null
	impact_streams.clear();impact_times.clear();duck_left=0
	if owns_bus:
		var index=AudioServer.get_bus_index(combat_bus)
		if index>=0:AudioServer.remove_bus(index)
		owns_bus=false

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
			var voice=AudioStreamPlayer.new();voice.bus=combat_bus;add_child(voice)
			var path:String=audio_paths.get(data.audioClipList.pick_random(),'')
			if path.is_empty():voice.queue_free();continue
			voice.stream=load(path).duplicate();voice.stream.loop=true
			voice.set_meta('type',request.type);voice.set_meta('gain',float(data.volume));voice.play();loops[key]=voice
		var voice:AudioStreamPlayer=loops[key]
		var attenuation=clampf(1-(Vector2(request.position).distance_to(listener)/48-25)/15,0,1)
		voice.volume_db=linear_to_db(maxf(0.00001,float(voice.get_meta('gain'))*float(save.state.settings.volume)*float(save.state.settings.sfx)*attenuation))
	for key in loops.keys():
		if not alive.has(key):loops[key].stop();loops[key].stream=null;loops[key].queue_free();loops.erase(key)
