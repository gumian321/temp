extends RefCounted
## One persistent material mask drives both the cutout and swept bullet hits.
## CPU copies are allocated on first damage; GPU uploads happen only on redraw.
const Art = preload("res://scripts/charcoal_art.gd")
const RESOLUTION = 128
const STRIDE = RESOLUTION * RESOLUTION
const ALPHA = .12
static var bases: Dictionary = {}

static func base(actor: Dictionary) -> Dictionary:
	var variant = int(actor.uid) % 4
	if bases.has(variant): return bases[variant]
	var source = Art.cutout("rocks",variant)
	var image = source.get_image()
	var size = Vector2i((source.get_size() * (RESOLUTION / float(maxi(image.get_width(),image.get_height())))).round())
	image.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	image.clear_mipmaps()
	var cells = PackedByteArray(); cells.resize(size.x*size.y)
	var roughness = PackedFloat32Array(); roughness.resize(cells.size())
	var count = 0
	for y in size.y:
		for x in size.x:
			var index = y*size.x+x
			cells[index] = 1 if image.get_pixel(x,y).a >= ALPHA else 0
			if cells[index]: count += 1
			else: image.set_pixel(x,y,Color.TRANSPARENT)
			# Fixed small facets, independent of combat RNG and of camera position.
			roughness[index] = .87 + float(((x/4)*73 ^ (y/4)*151 ^ variant*37) & 31)/100.0
	var result = {"image":image,"cells":cells,"size":size,"total":count,"remaining":count,"roughness":roughness}
	bases[variant] = result
	return result

static func state(actor: Dictionary) -> Dictionary:
	return actor.get("mineral",base(actor))

static func bounds_radius(actor: Dictionary, db) -> float:
	# The diagonal encloses every visible corner, including the largest variant.
	return Art.rock_extent(actor,db)*.71

static func pixel_scale(actor: Dictionary, db) -> float:
	return Art.rock_extent(actor,db)/RESOLUTION

static func world_pixel(actor: Dictionary, pixel: Vector2, db) -> Vector2:
	return Vector2(actor.position)+(pixel-Vector2(base(actor).size)*.5)*pixel_scale(actor,db)

static func aim_position(actor: Dictionary, db) -> Vector2:
	if not actor.has("mineral"): return actor.position
	return world_pixel(actor,actor.mineral.aim,db)

static func solid_near(data: Dictionary, point: Vector2, radius: float) -> int:
	var size: Vector2i = data.size
	var cells: PackedByteArray = data.cells
	var low = Vector2i((point-Vector2.ONE*(radius+.5)).floor()).max(Vector2i.ZERO)
	var high = Vector2i((point+Vector2.ONE*(radius+.5)).floor()).min(size-Vector2i.ONE)
	var best = -1
	var distance = INF
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var index = y*size.x+x
			if cells[index] == 0: continue
			var delta = (point-Vector2(x+.5,y+.5)).abs()-Vector2.ONE*.5
			var squared = delta.max(Vector2.ZERO).length_squared()
			if squared <= radius*radius and squared < distance:
				best=index; distance=squared
	return best

static func sweep(actor: Dictionary, start: Vector2, finish: Vector2, radius: float, db) -> Dictionary:
	var scale = pixel_scale(actor,db)
	var data = state(actor)
	var half = Vector2(data.size)*.5
	var from = (start-Vector2(actor.position))/scale+half
	var delta = (finish-start)/scale
	var reach = maxf(0,radius)/scale
	# Clip long/high-speed paths before sampling. No tunnelling through thin chips.
	var enter = 0.0; var leave = 1.0
	for axis in 2:
		if absf(delta[axis])<.00001:
			if from[axis]<-reach or from[axis]>data.size[axis]+reach: return {}
		else:
			var a = (-reach-from[axis])/delta[axis]
			var b = (data.size[axis]+reach-from[axis])/delta[axis]
			enter=maxf(enter,minf(a,b)); leave=minf(leave,maxf(a,b))
	if enter>leave: return {}
	var steps = maxi(1,ceili(delta.length()*(leave-enter)*2.0))
	for step in range(steps+1):
		var point = from+delta*lerpf(enter,leave,float(step)/steps)
		var index = solid_near(data,point,reach+.36)
		if index<0: continue
		var pixel = Vector2(index%int(data.size.x)+.5,index/int(data.size.x)+.5)
		var direction = (finish-start).normalized()
		if direction.is_zero_approx(): direction=Vector2.RIGHT
		var normal = (point-pixel).normalized()
		if normal.is_zero_approx(): normal=-direction
		return {"position":world_pixel(actor,pixel,db),"direction":direction,"normal":normal}
	return {}

static func contact(actor: Dictionary, shot: Dictionary, db) -> Dictionary:
	var start = Vector2(shot.get("previous",shot.get("position",actor.position)))
	var finish = Vector2(shot.get("position",actor.position))
	var direction = Vector2(shot.get("velocity",Vector2.RIGHT)).normalized()
	if start.distance_squared_to(finish)<.001:
		finish=Vector2(actor.position)
		if start.distance_squared_to(finish)<.001: start=finish-direction*bounds_radius(actor,db)*2
	var result = sweep(actor,start,finish,float(shot.get("radius",0)),db)
	if not result.is_empty(): return result
	# Area/continuous attacks can strike a remaining fragment off the center ray.
	var data=state(actor)
	var best=INF; var nearest=Vector2(actor.position)
	var scale=pixel_scale(actor,db)
	var origin=Vector2(actor.position)-Vector2(data.size)*.5*scale
	for index in data.cells.size():
		if data.cells[index]==0: continue
		var at=origin+Vector2(index%int(data.size.x)+.5,index/int(data.size.x)+.5)*scale
		var distance=start.distance_squared_to(at)
		if distance<best: best=distance; nearest=at
	direction=start.direction_to(nearest)
	if direction.is_zero_approx(): direction=Vector2.RIGHT
	return {"position":nearest,"direction":direction,"normal":-direction}

static func erode(actor: Dictionary, at: Vector2, db) -> int:
	var original=base(actor)
	var data=state(actor)
	# A surviving sliver remains targetable even at fractional HP; healing never regrows it.
	var target=ceili(original.total*clampf(float(actor.hp)/maxf(.001,float(actor.max_hp)),0,1))
	var count=int(data.remaining)-target
	if count<8 and actor.hp>0: return 0
	if count<=0: return 0
	if not actor.has("mineral"):
		data={"image":original.image.duplicate(),"cells":original.cells.duplicate(),"size":original.size,"remaining":original.total,"revision":0}
		actor.mineral=data
	var center=(at-Vector2(actor.position))/pixel_scale(actor,db)+Vector2(data.size)*.5
	var ranked=PackedInt64Array()
	var cells: PackedByteArray=data.cells
	var width=int(data.size.x)
	var height=int(data.size.y)
	var roughness: PackedFloat32Array=original.roughness
	# Native integer sort selects exactly the damage budget. Faceted distance
	# creates irregular, local bites instead of shrinking the whole sprite.
	for index in cells.size():
		if cells[index]==0: continue
		var offset=Vector2(index%width+.5,index/width+.5)-center
		var rank=int(offset.length_squared()*roughness[index]*16.0)
		ranked.append(rank*STRIDE+index)
	ranked.sort()
	var removed=mini(count,ranked.size())
	var image: Image=data.image
	var pixels=image.get_data()
	for i in removed:
		var index=int(ranked[i]%STRIDE)
		cells[index]=0
		var rgba=index*4
		pixels[rgba]=0; pixels[rgba+1]=0; pixels[rgba+2]=0; pixels[rgba+3]=0
	# Broken stone gets a narrow chalk face with dark ink flecks at the cut.
	var neighbors=PackedInt32Array([-width,width,-1,1])
	for i in removed:
		var index=int(ranked[i]%STRIDE)
		for step in neighbors:
			var n=index+step
			if n<0 or n>=cells.size() or (absi(step)==1 and n/width!=index/width) or cells[n]==0: continue
			var rgba=n*4
			var dark=(n*13)%7<2
			pixels[rgba]=54 if dark else 183; pixels[rgba+1]=54 if dark else 181; pixels[rgba+2]=51 if dark else 169; pixels[rgba+3]=255
	# Discard stale mip levels here; the renderer regenerates them once per frame.
	pixels.resize(width*height*4)
	image.set_data(width,height,false,Image.FORMAT_RGBA8,pixels)
	# Auto-aim must follow real material after the old center has been mined away.
	var aim: Vector2=data.get("aim",Vector2(data.size)*.5)
	var aim_index=clampi(int(aim.y),0,height-1)*width+clampi(int(aim.x),0,width-1)
	if cells[aim_index]==0:
		var best=INF
		for i in range(removed,ranked.size()):
			var index=int(ranked[i]%STRIDE)
			var point=Vector2(index%width+.5,index/width+.5)
			var distance=point.distance_squared_to(Vector2(data.size)*.5)
			if distance<best: best=distance; aim=point
	data.aim=aim
	data.cells=cells; data.remaining-=removed; data.revision+=1; data.dirty=true
	return removed

