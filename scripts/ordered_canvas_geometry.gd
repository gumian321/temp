extends RefCounted
## Ordered native AA geometry for retained, source-preserving shape batches.
## Geometry port of Godot 4.6.3 renderer_canvas_cull.cpp (AA polyline/ellipse)
## and canvas_item.cpp (arc sampling), retaining command and triangle order.
## https://github.com/godotengine/godot/blob/4.6.3-stable/servers/rendering/renderer_canvas_cull.cpp
## Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
## Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
## The above copyright notice and this permission notice shall be included in
## all copies or substantial portions of the Software.
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
## THE SOFTWARE.
const FEATHER=1.25
var points=PackedVector2Array()
var colors=PackedColorArray()
var indices=PackedInt32Array()
var original_commands=0

func clear():
	points.clear();colors.clear();indices.clear();original_commands=0

func append_triangles(vertices:PackedVector2Array,tints:PackedColorArray,triangles:PackedInt32Array):
	var base=points.size()
	points.append_array(vertices);colors.append_array(tints)
	for index in triangles:indices.append(base+index)

func strip(vertices:PackedVector2Array,tints:PackedColorArray):
	var triangles=PackedInt32Array()
	for i in range(2,vertices.size()):
		if i%2==0:triangles.append_array(PackedInt32Array([i-2,i-1,i]))
		else:triangles.append_array(PackedInt32Array([i-1,i-2,i]))
	append_triangles(vertices,tints,triangles)

func uniform_colors(count:int,ink:Color)->PackedColorArray:
	var result=PackedColorArray();result.resize(count);result.fill(ink);return result

func ellipse(at:Vector2,major:float,minor:float,ink:Color):
	var vertices=PackedVector2Array();vertices.resize(66);vertices[65]=at
	var triangles=PackedInt32Array()
	var step32=_f32(TAU/64.0)
	for i in 65:
		var angle=_f32(i*step32)
		vertices[i]=Vector2(_f32(_f32(cos(angle))*major),_f32(_f32(sin(angle))*minor))+at
	for i in 64:triangles.append_array(PackedInt32Array([65,i,i+1]))
	append_triangles(vertices,uniform_colors(66,ink),triangles)
	var feather=FEATHER
	var maximum=_f32(maxf(major,minor)*2.0)
	if maximum>=0.0 and maximum<1.0:feather=_f32(feather*maximum*.5)
	vertices=PackedVector2Array();var tints=PackedColorArray()
	for i in 65:
		var angle=_f32(i*step32);var c=_f32(cos(angle));var s=_f32(sin(angle))
		vertices.append(Vector2(_f32(c*major),_f32(s*minor))+at)
		vertices.append(Vector2(_f32(c*_f32(major+feather)),_f32(s*_f32(minor+feather)))+at)
		tints.append(ink);tints.append(Color(ink,0))
	strip(vertices,tints);original_commands+=2

func _f32(value:float)->float:
	return Vector2(value,0).x

func edge_offset(direction:Vector2,previous:Vector2)->Vector2:
	var bisector=(previous*direction.length()-direction*previous.length()).normalized()
	var angle=_f32(atan2(bisector.cross(previous),bisector.dot(previous)))
	var sine=_f32(sin(angle));var length=1.0
	if not is_zero_approx(sine) and not direction.is_equal_approx(previous):length=clampf(_f32(1.0/sine),-3.0,3.0)
	else:bisector=direction.orthogonal()
	if bisector.is_zero_approx():bisector=direction.orthogonal()
	return bisector*length

func polyline(line:PackedVector2Array,ink:Color,width:float):
	assert(line.size()>=2 and width>=0)
	width=_f32(width)
	var count=line.size();var loop=line[0].is_equal_approx(line[-1])
	var first=Vector2.ZERO;var last=Vector2.ZERO
	for i in range(1,count):
		first=(line[i]-line[i-1]).normalized()
		if not first.is_zero_approx():break
	for i in range(count-1,0,-1):
		last=(line[i]-line[i-1]).normalized()
		if not last.is_zero_approx():break
	var vertices=PackedVector2Array();var tints=PackedColorArray()
	var left=PackedVector2Array();var left_tints=PackedColorArray()
	var right=PackedVector2Array();var right_tints=PackedColorArray()
	vertices.resize(count*2+(0 if loop else 4));tints.resize(vertices.size())
	left.resize(count*2+(0 if loop else 5));left_tints.resize(left.size())
	right.resize(left.size());right_tints.resize(left.size())
	var feather=_f32(FEATHER*width) if width<1.0 else FEATHER
	var transparent=Color(ink,0);var previous=Vector2.ZERO
	for i in count:
		var direction=previous if i==count-1 else (line[i+1]-line[i]).normalized()
		if direction.is_zero_approx():direction=previous
		if i==0 and loop:previous=last
		elif i==count-1 and loop:previous=first
		var base:Vector2
		if i==0 and not loop:base=first.orthogonal()
		elif i==count-1 and not loop:base=last.orthogonal()
		else:base=edge_offset(direction,previous)
		var edge=base*_f32(width*.5);var border=base*feather;var pos=line[i]
		var j=i*2+(0 if loop else 2)
		vertices[j]=pos+edge;vertices[j+1]=pos-edge
		left[j]=pos+edge;left[j+1]=pos+edge+border
		right[j]=pos-edge;right[j+1]=pos-edge-border
		tints[j]=ink;tints[j+1]=ink
		left_tints[j]=ink;left_tints[j+1]=transparent
		right_tints[j]=ink;right_tints[j+1]=transparent
		if i==0 and not loop:
			var begin_border=-direction*feather
			vertices[0]=pos+edge+begin_border;vertices[1]=pos-edge+begin_border
			tints[0]=transparent;tints[1]=transparent
			left[0]=pos+edge+begin_border;left[1]=pos+edge+begin_border+border
			right[0]=pos-edge+begin_border;right[1]=pos-edge+begin_border-border
			left_tints[0]=transparent;left_tints[1]=transparent
			right_tints[0]=transparent;right_tints[1]=transparent
		if i==count-1 and not loop:
			var end_border=previous*feather;var end=count*2+2
			vertices[end]=pos+edge+end_border;vertices[end+1]=pos-edge+end_border
			tints[end]=transparent;tints[end+1]=transparent
			left[end]=pos+edge;left[end+1]=pos+edge+end_border+border;left[end+2]=pos+edge+end_border
			right[end]=pos-edge;right[end+1]=pos-edge+end_border-border;right[end+2]=pos-edge+end_border
			left_tints[end]=ink;left_tints[end+1]=transparent;left_tints[end+2]=transparent
			right_tints[end]=ink;right_tints[end+1]=transparent;right_tints[end+2]=transparent
		previous=direction
	# Native allocates the centre command first, then left and right feathers.
	strip(vertices,tints);strip(left,left_tints);strip(right,right_tints);original_commands+=3

func arc(at:Vector2,radius:float,start:float,end:float,count:int,ink:Color,width:float):
	var line=PackedVector2Array();var delta=_f32(clampf(_f32(end)-_f32(start),-TAU,TAU))
	radius=_f32(radius);start=_f32(start)
	for i in count:
		var theta=_f32(_f32(_f32(float(i)/_f32(count-1.0))*delta)+start)
		line.append(at+Vector2(_f32(radius*_f32(cos(theta))),_f32(radius*_f32(sin(theta)))))
	polyline(line,ink,width)

func polygon(vertices:PackedVector2Array,ink:Color):
	append_triangles(vertices,uniform_colors(vertices.size(),ink),Geometry2D.triangulate_polygon(vertices));original_commands+=1

func quad(a:Vector2,b:Vector2,c:Vector2,d:Vector2,ink:Color,coverage:Vector4):
	append_triangles(PackedVector2Array([a,b,c,d]),PackedColorArray([Color(ink,ink.a*coverage.x),Color(ink,ink.a*coverage.y),Color(ink,ink.a*coverage.z),Color(ink,ink.a*coverage.w)]),PackedInt32Array([0,1,2,0,2,3]))

func aa_line(start:Vector2,finish:Vector2,ink:Color,width:float):
	# Native positive-width AA line: centre, sides, then square corner feathers.
	# Each quad uses GLES3's original (0,1,2), (0,2,3) triangulation order.
	assert(width>=0)
	width=_f32(width)
	var backwards=start-finish
	var normal=backwards.orthogonal().normalized()
	var half=normal*width*.5
	var a=start+half;var b=start-half;var c=finish-half;var d=finish+half
	var feather=FEATHER*minf(1,width)
	var lateral=normal*feather;var cap=backwards.normalized()*feather
	var edge=Vector4(1,0,0,1);var corner=Vector4(1,0,0,0)
	quad(a,b,c,d,ink,Vector4.ONE)
	quad(a,a+lateral,d+lateral,d,ink,edge)
	quad(b,b-lateral,c-lateral,c,ink,edge)
	quad(a,a+cap,b+cap,b,ink,edge)
	quad(d,d-cap,c-cap,c,ink,edge)
	quad(a,a+cap,a+lateral+cap,a+lateral,ink,corner)
	quad(b,b+cap,b-lateral+cap,b-lateral,ink,corner)
	quad(d,d-cap,d+lateral-cap,d+lateral,ink,corner)
	quad(c,c-cap,c-lateral-cap,c-lateral,ink,corner)
	original_commands+=1

