extends RefCounted
## Ink pictograms shared by assembly controls; equipment uses its real art.
static func draw(canvas: CanvasItem, kind: String, at: Vector2, scale_factor: float, color: Color):
	canvas.draw_set_transform(at,0.0,Vector2.ONE*scale_factor)
	match kind:
		"copy":
			canvas.draw_rect(Rect2(-10,-11,15,16),color,false,1.8)
			canvas.draw_rect(Rect2(-4,-5,15,16),color,false,1.8)
		"armor":
			canvas.draw_polyline(PackedVector2Array([Vector2(0,-13),Vector2(11,-8),Vector2(9,5),Vector2(0,13),Vector2(-9,5),Vector2(-11,-8),Vector2(0,-13)]),color,1.8,true)
			canvas.draw_line(Vector2(0,-6),Vector2(0,6),color,1.8,true)
		"pack":
			canvas.draw_polyline(PackedVector2Array([Vector2(-12,-5),Vector2(0,-12),Vector2(12,-5),Vector2(12,9),Vector2(0,16),Vector2(-12,9),Vector2(-12,-5),Vector2(0,2),Vector2(12,-5)]),color,1.8,true)
			canvas.draw_line(Vector2(0,2),Vector2(0,16),color,1.8,true)
		"range":
			canvas.draw_arc(Vector2.ZERO,10,0,TAU,40,color,1.6,true)
			for axis in [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN]: canvas.draw_line(axis*6,axis*15,color,1.6,true)
		"damage":
			canvas.draw_polyline(PackedVector2Array([Vector2(-11,8),Vector2(-3,1),Vector2(-8,-7),Vector2(1,-3),Vector2(9,-12),Vector2(5,0),Vector2(12,5),Vector2(1,6),Vector2(-3,13)]),color,1.8,true)
		"rate":
			for i in 3:
				var y = -8+i*8
				canvas.draw_line(Vector2(-12,y),Vector2(3,y),color,1.8,true)
				canvas.draw_circle(Vector2(9,y),2.5,color,true,-1,true)
		"grid":
			for i in 9: canvas.draw_rect(Rect2(Vector2(i%3-1,i/3-1)*9-Vector2(3,3),Vector2(6,6)),color,false,1.2)
		"arrow":
			canvas.draw_line(Vector2(-13,0),Vector2(12,0),color,1.8,true)
			canvas.draw_polyline(PackedVector2Array([Vector2(5,-7),Vector2(12,0),Vector2(5,7)]),color,1.8,true)
		_:
			canvas.draw_line(Vector2(-9,0),Vector2(9,0),color,1.8,true)
			canvas.draw_line(Vector2(0,-9),Vector2(0,9),color,1.8,true)
	canvas.draw_set_transform(Vector2.ZERO)
