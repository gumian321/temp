extends TextureRect
## Generated mission paintings and transparent illustrated icons.
const NAMES = ["survive", "endless", "hunt", "escort", "siege", "defend"]
const DIRECTORY = "res://assets/expedition_ink/"
static var textures: Dictionary = {}

var mission_index = 0:
	set(value):
		mission_index = clampi(value, 0, NAMES.size() - 1)
		refresh_art()
var compact = false
var selected = false:
	set(value):
		selected = value
		refresh_art()

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED if compact else STRETCH_KEEP_ASPECT_COVERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	refresh_art()

func refresh_art():
	if not is_node_ready(): return
	var path = DIRECTORY + ("icon-" if compact else "scene-") + NAMES[mission_index] + ".png"
	if not textures.has(path): textures[path] = load(path)
	texture = textures[path]
	self_modulate = Color.WHITE if not compact or selected else Color(.74, .74, .74)
