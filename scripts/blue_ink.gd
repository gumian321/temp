extends RefCounted
## Shared ink, paper and control treatment for every screen, including source UI.
const INK = Color("121212")
const BLUE = Color("ff1764")
const PAPER = Color("e1ded4")
const WASH = Color("92918b")
const MUTED = Color("8b8b87")
static var sprite_material: ShaderMaterial
static var surface_material: ShaderMaterial
static var shared_theme: Theme
static var colored_paths: Dictionary = {}

static func register_game_colors(db):
	# Keep equipment/ability identifiers consistent between the world and UI.
	for asset in db.catalog.values():
		for field in ["turretSprite", "chipSprite", "droneSprite", "projectileSprite", "mineSprite", "rewardSprite", "buffRewardSprite", "debuffRewardSprite"]:
			var sprite = db.sprites.get(str(asset.get(field, "")), {})
			if not sprite.is_empty(): colored_paths[sprite.path] = true

static func keeps_color(texture: Texture2D) -> bool:
	if texture is AtlasTexture: return keeps_color(texture.atlas)
	return texture != null and colored_paths.has(texture.resource_path)

static func fitted_size(texture: Texture2D, bounds: Vector2) -> Vector2:
	if texture == null: return Vector2.ZERO
	var original = texture.get_size()
	return original * minf(bounds.x / maxf(1, original.x), bounds.y / maxf(1, original.y))

static func illustration(surface: bool = false) -> ShaderMaterial:
	if sprite_material == null:
		sprite_material = ShaderMaterial.new()
		sprite_material.shader = load("res://shaders/blue_ink.gdshader")
	if surface_material == null:
		surface_material = sprite_material.duplicate()
		surface_material.set_shader_parameter("ui_surface", true)
	return surface_material if surface else sprite_material

static func box(fill: Color = PAPER, edge: Color = INK, width: int = 1) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

static func theme() -> Theme:
	if shared_theme != null: return shared_theme
	shared_theme = preload("res://scripts/game_ui.gd").theme()
	return shared_theme

static func style_item(node: Node):
	var ancestor=node
	while ancestor!=null:
		if ancestor.has_meta("game_ui"):return
		ancestor=ancestor.get_parent()
	if node is Label or node is RichTextLabel:
		node.add_theme_color_override("font_color", preload("res://scripts/game_ui.gd").TEXT)
		node.add_theme_color_override("default_color", preload("res://scripts/game_ui.gd").TEXT)
		node.add_theme_color_override("font_outline_color", PAPER)
		node.add_theme_constant_override("outline_size", 0)
	elif node is TextureRect:
		if node.texture is AtlasTexture: node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		node.material = null if keeps_color(node.texture) else preload("res://scripts/game_ui.gd").icon_material()
		if keeps_color(node.texture): node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node.modulate = Color(1, 1, 1, node.modulate.a)
	elif node is TextureProgressBar:
		node.material = illustration()
		node.modulate = Color(1, 1, 1, node.modulate.a)
	elif node is VideoStreamPlayer:
		node.material = illustration(true)
	elif node is Button:
		# Source UI has transparent hit areas; keep its visible art behind them.
		if not node.flat:
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				if state == "normal" and node.get_meta("ink_selected", false): continue
				node.remove_theme_stylebox_override(state)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			node.remove_theme_color_override(state)
		if node.icon != null: node.material = null if keeps_color(node.icon) else illustration()
	elif node is Panel or node is PanelContainer:
		node.add_theme_stylebox_override("panel", preload("res://scripts/game_ui.gd").style())

static func apply_tree(node: Node):
	if node.has_meta("game_ui"):return
	if node is Control: node.theme = theme()
	style_item(node)
	for child in node.get_children(): apply_tree(child)
