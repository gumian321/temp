extends RefCounted
## Charcoal/chalk comic shell with sparse rose cues.
## No full-screen refraction, blur pass, or continuously redrawing controls.
const Art=preload("res://scripts/generated_ui_art.gd")
const FONT_PATH="res://assets/fonts/NotoSansCJKsc-Bold.otf"
const BG = Color("111111")
const PANEL = Color("1c1c1b")
const TEAL = Color("ff1764")
const AMBER = Color("d9d3c4")
const TEXT = Color("efede4")
const MUTED = Color("aaa8a0")
const RED = Color("ff6c89")
const TOOLTIP_BG = Color("101010")
const TOOLTIP_TEXT = Color("efede4")

static var shared_font:FontFile
static var shared_icon_material:ShaderMaterial

static func icon_material()->ShaderMaterial:
	if shared_icon_material==null:
		shared_icon_material=ShaderMaterial.new();shared_icon_material.shader=load("res://shaders/neon_ui_icon.gdshader")
	return shared_icon_material

static func font()->FontFile:
	if shared_font==null:
		shared_font=load(FONT_PATH)
		shared_font.fallbacks=[load("res://assets/fonts/NotoSansSC-Light.otf")]
	return shared_font

static func protect(node:Node):
	node.set_meta("game_ui",true)

static func style(fill:Color=PANEL,border:Color=TEAL,radius:int=26,margin:int=0)->StyleBoxFlat:
	# Flat charcoal plates with pale borders and compact corners.
	var box=flat_style(fill,border,radius,margin)
	box.bg_color=Color(PANEL.lerp(fill,0.16),0.96)
	box.border_color=Color(border,0.48)
	box.shadow_color=Color(0,0,0,.45);box.shadow_size=3
	box.border_width_top=1
	return box

static func card_style(active:bool=false)->StyleBoxFlat:
	var box=style(PANEL,TEAL if active else MUTED,26,12)
	if active:
		box.bg_color=Color("30262a");box.border_color=TEAL;box.shadow_color=Color(TEAL,0.2)
	return box

static func card_focus_style()->StyleBoxFlat:
	var box=card_style(true);box.draw_center=false
	return box

static func hud_style()->StyleBoxFlat:
	return style(PANEL,MUTED,22,8)

static func focus_style()->StyleBoxFlat:
	var box=style(PANEL,Color("ffb6df"),22,0);box.draw_center=false
	box.set_border_width_all(2);box.border_color=Color("ffb6df");box.shadow_size=5
	return box

static func flat_style(fill:Color=PANEL,border:Color=TEAL,radius:int=16,margin:int=0)->StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=fill;box.border_color=border
	box.set_border_width_all(1);box.set_corner_radius_all(mini(radius,6))
	box.content_margin_left=margin;box.content_margin_right=margin;box.content_margin_top=margin;box.content_margin_bottom=margin
	return box

static func button_style(fill:Color=PANEL,border:Color=TEAL)->StyleBoxFlat:
	var active=fill==TEAL
	var box=style(Color("30262a") if active else PANEL,border,22,44)
	box.bg_color=Color("30262a") if active else Color("222221")
	box.border_color=Color(TEAL,0.85) if active else Color(border,0.36)
	box.shadow_color=Color(TEAL,0.18 if active else 0.06)
	box.content_margin_top=6;box.content_margin_bottom=6
	return box

static func apply_tooltip_theme(t:Theme):
	# Define the pair together: missing TooltipPanel used to inherit cream paper
	# while TooltipLabel inherited the expedition's nearly white Label color.
	var tooltip=flat_style(TOOLTIP_BG,MUTED,8)
	tooltip.content_margin_left=14;tooltip.content_margin_right=14
	tooltip.content_margin_top=9;tooltip.content_margin_bottom=9
	t.set_stylebox("panel","TooltipPanel",tooltip)
	t.set_color("font_color","TooltipLabel",TOOLTIP_TEXT)
	t.set_color("font_shadow_color","TooltipLabel",Color.TRANSPARENT)
	t.set_color("font_outline_color","TooltipLabel",Color.TRANSPARENT)
	t.set_constant("outline_size","TooltipLabel",0)
	t.set_font("font","TooltipLabel",font())
	t.set_font_size("font_size","TooltipLabel",18)

static func theme()->Theme:
	var t=Theme.new();t.default_font=font();t.default_font_size=20
	for kind in ["Label","Button","CheckButton","CheckBox","OptionButton","RichTextLabel","PopupMenu","LineEdit"]:
		t.set_color("font_color",kind,TEXT)
		t.set_color("default_color",kind,TEXT)
		t.set_color("font_hover_color",kind,TEXT)
		t.set_color("font_pressed_color",kind,TEXT)
		t.set_color("font_focus_color",kind,TEXT)
	t.set_stylebox("normal","Button",button_style(PANEL,MUTED))
	t.set_stylebox("hover","Button",button_style(TEAL))
	t.set_stylebox("pressed","Button",button_style(TEAL))
	t.set_stylebox("hover_pressed","Button",button_style(TEAL))
	t.set_stylebox("focus","Button",focus_style())
	t.set_stylebox("disabled","Button",button_style(PANEL))
	t.set_color("font_disabled_color","Button",MUTED)
	t.set_color("font_focus_color","Button",TEXT)
	t.set_color("font_hover_color","Button",TEXT)
	t.set_color("font_pressed_color","Button",TEXT)
	t.set_color("font_hover_pressed_color","Button",TEXT)
	for kind in ["Panel","PanelContainer","PopupPanel","PopupMenu"]:
		t.set_stylebox("panel",kind,style())
	for kind in ["OptionButton","CheckButton","CheckBox"]:
		for state in ["normal","hover","pressed","focus","disabled"]:
			t.set_stylebox(state,kind,t.get_stylebox(state,"Button"))
	for state in ["normal","focus","read_only"]:
		t.set_stylebox(state,"LineEdit",button_style())
	t.set_stylebox("background","ProgressBar",flat_style(Color("282827"),MUTED,5))
	t.set_stylebox("fill","ProgressBar",flat_style(TEAL,TEAL,5))
	var track=flat_style(Color("282827"),MUTED,4)
	track.content_margin_top=4;track.content_margin_bottom=4
	var fill=flat_style(TEAL,TEAL,4)
	fill.content_margin_top=4;fill.content_margin_bottom=4
	var highlight=flat_style(AMBER,AMBER,4)
	highlight.content_margin_top=4;highlight.content_margin_bottom=4
	t.set_stylebox("slider","HSlider",track)
	t.set_stylebox("grabber_area","HSlider",fill)
	t.set_stylebox("grabber_area_highlight","HSlider",highlight)
	t.set_stylebox("focus","HSlider",focus_style())
	t.set_icon("grabber","HSlider",slider_thumb(TEAL))
	t.set_icon("grabber_highlight","HSlider",slider_thumb(AMBER))
	t.set_icon("grabber_disabled","HSlider",slider_thumb(MUTED))
	apply_tooltip_theme(t)
	return t

static func slider_thumb(_color:Color)->Texture2D:
	var source=Art.icon("gear")
	if source==null:return null
	var image=source.get_image();image.resize(26,26,Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

static func icon_texture(key:String)->Texture2D:
	return Art.icon(key)

static func backdrop(parent:Control,hero:bool=false):
	protect(parent);parent.theme=theme()
	var bg=Backdrop.new();bg.hero=hero;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);parent.add_child(bg)
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE

	if hero:
		var art=TextureRect.new();art.texture=preload("res://scripts/charcoal_art.gd").texture("ground")
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		art.modulate=Color(.42,.42,.42)
		parent.add_child(art)

static func panel(parent:Control,rect:Rect2,accent:Color=TEAL)->Panel:
	var p=Panel.new();p.position=rect.position;p.size=rect.size;p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",style(PANEL,Color(accent,0.28)))
	protect(p);parent.add_child(p);return p

static func label(parent:Control,text:String,pos:Vector2,size:int=20,color:Color=TEXT)->Label:
	var l=Label.new();l.text=text;l.position=pos;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l);return l

static func button(parent:Control,text:String,rect:Rect2,callback:Callable,icon_key:String="",accent:Color=TEAL)->Button:
	var b=Button.new();b.text=text;b.position=rect.position;b.size=rect.size;b.custom_minimum_size=rect.size;b.focus_mode=Control.FOCUS_ALL;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",24);b.add_theme_stylebox_override("normal",button_style(PANEL,Color(accent,0.5)))
	b.pressed.connect(callback);protect(b);parent.add_child(b)
	if icon_key!="":
		b.alignment=HORIZONTAL_ALIGNMENT_CENTER
		if text.is_empty():
			for state in ["normal","hover","pressed","disabled","focus"]:
				var compact=button_style(TEAL if state in ["hover","pressed"] else PANEL)
				compact.content_margin_left=0;compact.content_margin_right=0;compact.content_margin_top=0;compact.content_margin_bottom=0
				if state=="focus":compact.draw_center=false
				b.add_theme_stylebox_override(state,compact)
			b.size=rect.size
		else:
			# Keep centered labels inside the content area to the right of the art.
			# Apply identical insets to every state so hover cannot shift the text.
			for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
				var inset=button_style(TEAL if state in ["hover","pressed","hover_pressed"] else PANEL)
				inset.content_margin_left=(40 if rect.size.x>=240 else 28)+38+12
				inset.content_margin_right=44 if rect.size.x>=240 else 28
				if state=="focus":inset.draw_center=false
				b.add_theme_stylebox_override(state,inset)
		icon(b,icon_key,Vector2((rect.size.x-38)/2 if text.is_empty() else (40 if rect.size.x>=240 else 28),(rect.size.y-38)/2),38,accent)
	return b

static func icon(parent:Control,key:String,pos:Vector2,extent:float=40,_color:Color=TEAL)->Control:
	var g=TextureRect.new();g.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	g.texture=Art.icon(key);g.position=pos;g.size=Vector2.ONE*extent
	g.material=icon_material()
	g.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;g.mouse_filter=Control.MOUSE_FILTER_IGNORE
	protect(g);parent.add_child(g);return g

static func header(parent:Control,title:String,back_callback:Callable):
	button(parent,"",Rect2(40,34,60,60),back_callback,"back")
	label(parent,title,Vector2(120,36),32)
	label(parent,"C H I T I N / 0 1",Vector2(1210,52),16,MUTED)

class Backdrop extends Control:
	var hero=false
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),BG)
