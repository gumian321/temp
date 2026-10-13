extends RefCounted
## A low slap, wet noise and falling bubbles; generated once and cached by audio_system.
static func make_stream()->AudioStreamWAV:
	var rate=22050;var duration=.23;var count=int(rate*duration)
	var data=PackedByteArray();data.resize(count*2)
	var random=RandomNumberGenerator.new();random.seed=2026101309
	var filtered=0.0;var phase=0.0;var bubble_phase=0.0
	for i in range(count):
		var t=float(i)/rate
		filtered=lerpf(filtered,random.randf_range(-1,1),.26)
		phase+=TAU*(58+220*exp(-t*35))/rate
		bubble_phase+=TAU*(190+1250*exp(-t*24))/rate
		var attack=minf(1,t*1800);var tail=minf(1,(duration-t)*250)
		var slap=sin(phase)*exp(-t*24)*.60
		var sap=filtered*exp(-t*36)*.42
		var bubble=sin(bubble_phase)*exp(-t*21)*(.10+.06*sin(t*190))
		data.encode_s16(i*2,int(clampf((slap+sap+bubble)*attack*tail,-.92,.92)*32767))
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.stereo=false;stream.data=data
	return stream
