extends "res://tests/test_cave_native_overlap.gd"
## Inherits the bounded exact bool/material-witness differential, including
## full-precision radii, tangencies, half-open borders, real digs and revision
## jumps. This adapter additionally enforces the native admission threshold.
var small_native_queries=0
var large_native_queries=0

func probe(raw,candidate,point:Vector2,radius:float,label:String,witness:bool=false):
	var before=int(candidate.native_accel.stats().get("overlapQueries",0))
	super.probe(raw,candidate,point,radius,label,witness)
	var after=int(candidate.native_accel.stats().get("overlapQueries",0))
	if radius<64.0:
		small_native_queries+=after-before
		if after!=before and failures.size()<12:
			failures.append({"scope":"small radius entered native overlap","radius":radius,"label":label,"native_queries":after-before})
	else:large_native_queries+=after-before

func execute():
	# The parent requires a loaded kernel and positive native overlap coverage
	# in every world. Its exact comparison report remains the full oracle.
	await super.execute()
	print(JSON.stringify({"large_native_overlap_threshold":64.0,"small_native_queries":small_native_queries,"large_native_queries":large_native_queries,"scope":"Inherited exact tangency/excavation/material-witness suite with explicit small-radius native bypass checks. No admission policy or FPS claim."}))
	if small_native_queries!=0 or large_native_queries<=0:
		printerr("Large-only native overlap coverage failed")
		quit(1)

