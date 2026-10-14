extends Node2D
## One bounded local contact burst per insect. Direction follows the actual hit.
var state:Dictionary
var ink=Color("173b70")
func setup(body_state:Dictionary):state=body_state
func pose():
	visible=not state.is_empty() and float(state.cue_age)<.34
	if visible:queue_redraw()
func _draw():
	if state.is_empty() or state.get("family","")=="shield":return
	var age=float(state.cue_age)
	if age>=.34:return
	var at:Vector2=state.contact
	var outward=-Vector2(state.direction)
	var side=outward.orthogonal()
	var strength=float(state.cue_strength)
	var fade=pow(1-age/.34,1.4)
	var seed=float(state.cue)*2.39996
	# Contact sparks are drawn once by WeaponFX. Keep only three blue sap chips.
	var reach=1-exp(-age*12)
	for i in range(3):
		var angle=lerpf(-1.2,1.2,i/2.0)+sin(seed+i*3.7)*.12
		var axis=outward.rotated(angle)
		var distance=(.20+.17*sin(seed+i*6.3)**2)*reach*(.7+strength*.3)
		var tip=at+axis*distance+side*sin(seed+i)*age*.15
		var tail=tip-axis*(.025+.035*fade)
		draw_line(tail,tip,Color(ink,fade),.019,true)
		draw_circle(tip,.011+.009*sin(i*2.8+seed)**2,Color("659bd0")*Color(1,1,1,fade))
