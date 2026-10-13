extends RefCounted
## The expedition's UI is intentionally separate from the paper-and-ink battlefield.
const BG = Color("0b1622")
const PANEL = Color("142b36")
const TEAL = Color("55e3c1")
const AMBER = Color("ffc86a")
const TEXT = Color("eff7ed")
const MUTED = Color("89a7ae")
const RED = Color("ee817d")

static func protect(node:Node):
	node.set_meta("game_ui",true)

static func style(fill:Color=PANEL,border:Color=TEAL,radius:int=16,margin:int=0)->StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=fill;box.border_color=border
	box.set_border_width_all(1);box.set_corner_radius_all(radius)
	box.content_margin_left=margin;box.content_margin_right=margin;box.content_margin_top=margin;box.content_margin_bottom=margin
	return box

static func button_style(fill:Color,border:Color)->StyleBoxFlat:
	var box=style(fill,border);box.content_margin_left=20;box.content_margin_right=20;box.content_margin_top=6;box.content_margin_bottom=6
	return box

static func theme()->Theme:
	var t=Theme.new();t.default_font=load("res://assets/fonts/NotoSansSC-Light.otf");t.default_font_size=20
	for kind in ["Label","Button","CheckButton","OptionButton"]:
		t.set_color("font_color",kind,TEXT)
	t.set_stylebox("normal","Button",button_style(PANEL,Color("31515d")))
	t.set_stylebox("hover","Button",style(Color("20424b"),TEAL))
	t.set_stylebox("pressed","Button",style(Color("2b5757"),TEAL))
	t.set_stylebox("focus","Button",style(Color(0,0,0,0),AMBER))
	t.set_stylebox("disabled","Button",style(Color("101e29"),Color("263945")))
	t.set_color("font_disabled_color","Button",MUTED)
	t.set_color("font_hover_color","Button",TEXT)
	t.set_color("font_pressed_color","Button",TEAL)
	t.set_color("font_hover_pressed_color","Button",TEAL)
	t.set_stylebox("panel","Panel",style())
	t.set_stylebox("background","ProgressBar",style(BG,Color("31515d"),5))
	t.set_stylebox("fill","ProgressBar",style(TEAL,TEAL,5))
	var track=style(BG,Color("31515d"),4)
	track.content_margin_top=4;track.content_margin_bottom=4
	var fill=style(TEAL,TEAL,4)
	fill.content_margin_top=4;fill.content_margin_bottom=4
	var highlight=style(AMBER,AMBER,4)
	highlight.content_margin_top=4;highlight.content_margin_bottom=4
	t.set_stylebox("slider","HSlider",track)
	t.set_stylebox("grabber_area","HSlider",fill)
	t.set_stylebox("grabber_area_highlight","HSlider",highlight)
	t.set_stylebox("focus","HSlider",style(Color(0,0,0,0),Color(AMBER,.7),8))
	t.set_icon("grabber","HSlider",slider_thumb(TEAL))
	t.set_icon("grabber_highlight","HSlider",slider_thumb(AMBER))
	t.set_icon("grabber_disabled","HSlider",slider_thumb(MUTED))
	return t

static func slider_thumb(color:Color)->Texture2D:
	var image=Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26"><circle cx="13" cy="13" r="10" fill="#'+BG.to_html(false)+'" stroke="#'+color.to_html(false)+'" stroke-width="3"/><circle cx="13" cy="13" r="4" fill="#'+color.to_html(false)+'"/></svg>')
	return ImageTexture.create_from_image(image)

static func backdrop(parent:Control,hero:bool=false):
	protect(parent);parent.theme=theme()
	var bg=Backdrop.new();bg.hero=hero;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);parent.add_child(bg)
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if hero and ResourceLoader.exists("res://assets/ui_overhaul/menu_hero.png"):
		var art=TextureRect.new();art.texture=load("res://assets/ui_overhaul/menu_hero.png")
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(art)
		var shade=ColorRect.new();shade.color=Color(0.025,0.06,0.09,0.28);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(shade)

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
		b.alignment=HORIZONTAL_ALIGNMENT_RIGHT
		icon(b,icon_key,Vector2((rect.size.x-38)/2 if text.is_empty() else 20,(rect.size.y-38)/2),38,accent)
	return b

static func icon(parent:Control,key:String,pos:Vector2,extent:float=40,color:Color=TEAL)->Control:
	var g=Glyph.new();g.key=key;g.tint=color;g.position=pos;g.size=Vector2.ONE*extent;g.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(g);return g

static func header(parent:Control,title:String,back_callback:Callable):
	button(parent,"",Rect2(40,34,60,60),back_callback,"back")
	label(parent,title,Vector2(120,36),32)
	label(parent,"C / 0 1",Vector2(1260,52),16,MUTED)

class Backdrop extends Control:
	var hero=false
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),BG)
		for x in range(0,int(size.x)+100,80):draw_line(Vector2(x,0),Vector2(x-250,size.y),Color(0.15,0.32,0.36,0.13),1)
		for i in range(4):draw_arc(Vector2(size.x*0.77,size.y*0.48),170+i*55,0,TAU,120,Color(0.2,0.6,0.57,0.12),1.5,true)
		if hero:
			for i in range(10):
				var p=Vector2(size.x*0.72+sin(i*0.5)*120,140+i*57)
				draw_circle(p,38,Color("173f47"));draw_arc(p,38,0,TAU,24,TEAL,2,true)
				for side in [-1,1]:draw_polyline(PackedVector2Array([p+Vector2(side*28,5),p+Vector2(side*67,21),p+Vector2(side*88,9)]),MUTED,3,true)

class Glyph extends Control:
	var key=""
	var tint=TEAL
	func _draw():
		var s=size.x;var c=size/2;var w=maxf(2,s/15)
		match key:
			"back":draw_polyline(PackedVector2Array([Vector2(s*.65,s*.2),Vector2(s*.3,s*.5),Vector2(s*.65,s*.8)]),tint,w,true)
			"play","next":draw_colored_polygon(PackedVector2Array([Vector2(s*.3,s*.17),Vector2(s*.83,s*.5),Vector2(s*.3,s*.83)]),tint)
			"pause":
				draw_rect(Rect2(s*.25,s*.2,s*.16,s*.6),tint);draw_rect(Rect2(s*.6,s*.2,s*.16,s*.6),tint)
			"research","meta":
				draw_arc(c,s*.3,0,TAU,6,tint,w,true);draw_circle(c,s*.09,tint)
				for a in range(3):var d=Vector2.from_angle(a*TAU/3-PI/2);draw_line(c+d*s*.3,c+d*s*.46,tint,w,true)
			"settings":
				for i in range(3):
					var y=s*(.25+i*.25);draw_line(Vector2(s*.12,y),Vector2(s*.88,y),tint,w,true);draw_circle(Vector2(s*(.32 if i!=1 else .68),y),s*.09,tint)
			"exit":draw_arc(c,s*.32,-PI*.32,PI*1.32,24,tint,w,true);draw_line(Vector2(s*.5,s*.08),Vector2(s*.5,s*.48),tint,w,true)
			"sound":
				draw_colored_polygon(PackedVector2Array([Vector2(s*.1,s*.4),Vector2(s*.3,s*.4),Vector2(s*.5,s*.2),Vector2(s*.5,s*.8),Vector2(s*.3,s*.6),Vector2(s*.1,s*.6)]),tint);draw_arc(Vector2(s*.5,s*.5),s*.34,-1.1,1.1,18,tint,w,true)
			"target":draw_arc(c,s*.3,0,TAU,24,tint,w,true);draw_line(Vector2(s*.5,0),Vector2(s*.5,s),tint,w,true);draw_line(Vector2(0,s*.5),Vector2(s,s*.5),tint,w,true)
			"shield":draw_polyline(PackedVector2Array([Vector2(s*.5,s*.1),Vector2(s*.83,s*.25),Vector2(s*.76,s*.65),Vector2(s*.5,s*.9),Vector2(s*.24,s*.65),Vector2(s*.17,s*.25),Vector2(s*.5,s*.1)]),tint,w,true)
			"time":draw_arc(c,s*.37,0,TAU,32,tint,w,true);draw_polyline(PackedVector2Array([Vector2(s*.5,s*.2),c,Vector2(s*.72,s*.58)]),tint,w,true)
			"wing":
				for side in [-1,1]:
					draw_colored_polygon(PackedVector2Array([c, c+Vector2(side*s*.43,-s*.34),c+Vector2(side*s*.30,s*.18),c+Vector2(0,s*.35)]),tint)
			"burst":
				for i in range(8):
					var d=Vector2.from_angle(i*TAU/8);draw_line(c+d*s*.2,c+d*s*.45,tint,w,true)
				draw_circle(c,s*.12,tint)
			"orbit":
				draw_arc(c,s*.34,0,TAU,32,tint,w,true);draw_circle(c,s*.13,tint);draw_circle(c+Vector2(s*.34,0),s*.09,tint)
			"reward":
				draw_rect(Rect2(s*.15,s*.32,s*.7,s*.52),tint,false,w);draw_line(Vector2(s*.5,s*.3),Vector2(s*.5,s*.84),tint,w,true)
				draw_polyline(PackedVector2Array([Vector2(s*.5,s*.32),Vector2(s*.25,s*.1),Vector2(s*.15,s*.26),Vector2(s*.85,s*.26),Vector2(s*.75,s*.1),Vector2(s*.5,s*.32)]),tint,w,true)

			"check":draw_polyline(PackedVector2Array([Vector2(s*.16,s*.5),Vector2(s*.4,s*.73),Vector2(s*.84,s*.23)]),tint,w,true)
			_:
				draw_arc(c,s*.35,0,TAU,6,tint,w,true);draw_line(Vector2(s*.35,s*.5),Vector2(s*.65,s*.5),tint,w,true);draw_line(Vector2(s*.5,s*.35),Vector2(s*.5,s*.65),tint,w,true)
