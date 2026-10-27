extends "res://tools/native_near_contact_world.gd"
## Isolated wider-radius prefix experiment. Production limits stay unchanged.
var wide_near_contact_probes=0
var wide_near_contact_hits=0
var wide_near_contact_fallbacks=0

func wall_hit(start:Vector2,finish:Vector2,radius:float=0.0)->Dictionary:
	var delta=finish-start
	var squared=delta.length_squared()
	if use_near_contact_probe and enabled and radius>64 and radius<=512 and is_finite(squared) and squared>1024 and squared<=4096.0*4096.0 and start.abs().max(finish.abs()).x<32768 and start.abs().max(finish.abs()).y<32768:
		wide_near_contact_probes+=1
		var near=near_contact_hit(start,finish,radius,delta,squared)
		if not near.is_empty():wide_near_contact_hits+=1;return near
		wide_near_contact_fallbacks+=1
	return super.wall_hit(start,finish,radius)

func native_stats()->Dictionary:
	var result=super.native_stats()
	result.wide_near_contact_probes=wide_near_contact_probes
	result.wide_near_contact_hits=wide_near_contact_hits
	result.wide_near_contact_fallbacks=wide_near_contact_fallbacks
	result.scope="Isolated native local and near-contact sweeps including64..512px actors; ordinary game unchanged"
	return result
