extends RefCounted
## Generated raster carapace, countable armor modules, and eight permanent claws.
static var pieces: Dictionary = {}
const ATLAS_PATH = "res://assets/characters/spider_segmented_parts.png"
const Feedback=preload("res://scripts/segment_feedback.gd")
const REGIONS = {
	"body": Rect2(50, 60, 1155, 615),
	"segment": Rect2(35, 730, 710, 242),
	"claw": Rect2(748, 700, 490, 410),
	"connector": Rect2(65, 990, 485, 220),
}
const ANCHORS = {
	"segment": [Vector2(70, 121), Vector2(653, 121)],
	"claw": [Vector2(65, 203), Vector2(450, 205)],
	"connector": [Vector2(77, 110), Vector2(419, 110)],
}
const SEGMENT_WIDTH = 42.0
const CLAW_WIDTH = 30.0

static func prepare():
	if not pieces.is_empty(): return
	var atlas: Texture2D
	# A fresh source-tree pull may have .import metadata without its cache.
	# Check the remap target before ResourceLoader to avoid caching a null atlas.
	var config = ConfigFile.new()
	if config.load(ATLAS_PATH + ".import") == OK:
		var imported = str(config.get_value("remap", "path", ""))
		if not imported.is_empty() and FileAccess.file_exists(imported):
			atlas = load(ATLAS_PATH)
	if atlas == null and FileAccess.file_exists(ATLAS_PATH):
		var raw = Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
		if raw != null and not raw.is_empty(): atlas = ImageTexture.create_from_image(raw)
	if atlas == null:
		# Exported PCKs can omit the original PNG and expose only the resource.
		if not FileAccess.file_exists(ATLAS_PATH) and ResourceLoader.exists(ATLAS_PATH): atlas = load(ATLAS_PATH)
	if atlas == null: return
	for key in REGIONS:
		var piece = AtlasTexture.new()
		piece.atlas = atlas
		piece.region = REGIONS[key]
		piece.filter_clip = true
		pieces[key] = piece

static func _link(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, key: String, tint: Color):
	var texture: Texture2D = pieces[key]
	var source_a: Vector2 = ANCHORS[key][0]
	var source_b: Vector2 = ANCHORS[key][1]
	var source_axis = source_b - source_a
	var direction = (b - a).normalized()
	var normal = direction.orthogonal()
	var scale_x = a.distance_to(b) / source_axis.length()
	var scale_y = width / texture.get_height()
	var source_dir = source_axis.normalized()
	var source_normal = source_dir.orthogonal()
	var basis_x = direction * source_dir.x * scale_x + normal * source_normal.x * scale_y
	var basis_y = direction * source_dir.y * scale_x + normal * source_normal.y * scale_y
	var origin = a - basis_x * source_a.x - basis_y * source_a.y
	canvas.draw_set_transform_matrix(Transform2D(basis_x, basis_y, origin))
	canvas.draw_texture(texture, Vector2.ZERO, tint)

static func _screen(point: Vector2, player, at: Vector2, zoom: float) -> Vector2:
	return at + (point - player.head) * zoom

static func draw_body(canvas: CanvasItem, player, at: Vector2, zoom: float, _clock: float,tension:Dictionary={}):
	prepare()
	if pieces.is_empty(): return
	player.spider_rig.ensure(player)
	for leg in player.spider_rig.legs:
		var foot = _screen(leg.foot, player, at, zoom)
		canvas.draw_set_transform(foot + Vector2(1, 3) * zoom, 0, Vector2(1, 0.48))
		canvas.draw_circle(Vector2.ZERO, 7.0 * zoom, Color(0.04, 0.08, 0.13, 0.19 - float(leg.lift) * 0.09))
	for leg_index in player.spider_rig.legs.size():
		var leg:Dictionary=player.spider_rig.legs[leg_index]
		var tint = Color.WHITE.lerp(Color(0.82, 0.88, 0.96), (1.0 - float(leg.lift)) * 0.12)
		_link(canvas, _screen(leg.connector.a, player, at, zoom), _screen(leg.connector.b, player, at, zoom), 18.0 * zoom, "connector", tint)
		# Exactly one distinct shell per installed module. Its rim and both sockets
		# extend beyond the 30-unit tower silhouette, even at the default zoom.
		for segment in leg.segments:
			var index=player.part_at(player.spider_mount(leg_index,int(segment.depth)))
			var part:Dictionary=player.parts[index] if index>0 else {}
			var kick=Feedback.offset(part)*zoom
			_link(canvas, _screen(segment.a, player, at, zoom)+kick, _screen(segment.b, player, at, zoom)+kick, SEGMENT_WIDTH * zoom, "segment", Feedback.tint(part,tint))
		_link(canvas, _screen(leg.claw.a, player, at, zoom), _screen(leg.claw.b, player, at, zoom), CLAW_WIDTH * zoom, "claw", tint)
	# Artwork's neck aligns with the independent hips; abdomen extends behind it.
	canvas.draw_set_transform(at+Feedback.offset(player.parts[0])*zoom, player.facing.angle(), Vector2.ONE * zoom)
	if tension.is_empty() or Vector2(tension.get("offset",Vector2.ZERO)).length_squared()<.0001:
		canvas.draw_texture_rect(pieces.body, Rect2(-65, -30.6, 115.5, 61.5), false,Feedback.tint(player.parts[0]))
	else:
		var local_offset=Vector2(tension.offset).rotated(-player.facing.angle())
		var texture:AtlasTexture=pieces.body
		# Keep the abdomen planted; neck and silk-emitting forebody lean under load.
		for row in 2:
			for column in 6:
				var points=PackedVector2Array();var uvs=PackedVector2Array()
				for corner in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
					var uv=(Vector2(column,row)+corner)/Vector2(6,2)
					var point=Vector2(-65,-30.6)+uv*Vector2(115.5,61.5)
					points.append(tension_point(point,local_offset,float(tension.twist)))
					uvs.append((texture.region.position+uv*texture.region.size)/texture.atlas.get_size())
				canvas.draw_polygon(points,PackedColorArray([Feedback.tint(player.parts[0])]),uvs,texture.atlas)
	canvas.draw_set_transform(Vector2.ZERO)

static func tension_point(point:Vector2,offset:Vector2,twist:float)->Vector2:
	var weight=smoothstep(-42,-4,point.x)
	return point.lerp(point.rotated(twist)+offset,weight)
