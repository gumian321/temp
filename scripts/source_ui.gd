extends Control
var db
var layouts:Dictionary
var controls:Dictionary={}
var components:Dictionary={}
var buttons:Dictionary={}
var action:Callable
var labels:Dictionary={}
var images:Dictionary={}
var fills:Dictionary={}
var sliders:Dictionary={}
var nodes_by_name:Dictionary={}
var animation_nodes:Array=[]
var animation_time=0.0
var font_materials:Dictionary
func setup(source,key:String,callback:Callable,bindings:Dictionary={}):
	db=source;action=callback;font_materials=db.read_json("font_materials");layouts=db.read_json("ui_layouts")
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var root:Dictionary=layouts[key]
	size=Vector2(1280,720)
	scale=Vector2(1.125,1.125)
	position=Vector2(0,45)
	for child in root.children:build(child,self,size)
	set_binding_labels(bindings)
	collect_animations(root)
func color(value:Dictionary)->Color:
	return Color(float(value.get("r",1)),float(value.get("g",1)),float(value.get("b",1)),float(value.get("a",1)))
func vector(value:Dictionary,default:float=0)->Vector2:
	return Vector2(float(value.get("x",default)),float(value.get("y",default)))
func build(data:Dictionary,parent:Control,parent_size:Vector2,forced=null):
	var node=Control.new();node.name=str(data.name).replace("/","_")
	parent.add_child(node);controls[data.id]=node
	for component in data.components.values():
		if component is Dictionary and component.has("_component_id"):components[str(component._component_id)]=component
	nodes_by_name[data.name]=node
	for id in data.get("ids",[]):controls[id]=node
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var extent=vector(data.size)+parent_size*(vector(data.anchor_max)-vector(data.anchor_min))
	if not data.rect:extent=parent_size
	extent=extent.max(Vector2.ZERO)
	var pivot=vector(data.pivot,0.5)
	var reference=parent_size*(vector(data.anchor_min)+(vector(data.anchor_max)-vector(data.anchor_min))*pivot)
	var anchor=vector(data.anchored)
	node.position=Vector2(reference.x+anchor.x-extent.x*pivot.x,parent_size.y-reference.y-anchor.y-extent.y*(1-pivot.y))
	if not data.rect:node.position=Vector2(float(data.position.get("x",0)),-float(data.position.get("y",0)))
	if forced is Rect2:node.position=forced.position;extent=forced.size
	node.size=extent
	node.pivot_offset=extent*Vector2(pivot.x,1-pivot.y)
	node.rotation=-2*atan2(float(data.get("rotation",{}).get("z",0)),float(data.get("rotation",{}).get("w",1)))
	node.scale=vector(data.scale,1)
	# Several source panels are serialized at zero before DOTween's show animation.
	if node.scale.length()<0.001:node.scale=Vector2.ONE
	node.visible=bool(data.active)
	node.clip_contents=data.has("mask")
	if data.has("image"):
		var texture=db.sprite(data.image.sprite)
		if texture!=null:
			var image=TextureRect.new();image.texture=texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			if data.image.get("preserve_aspect",false):image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.size=extent;image.visible=bool(data.get("mask",{}).get("show_graphic",true));image.modulate=color(data.image.color);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.add_child(image);images[data.id]=image
			for id in data.get("ids",[]):images[id]=image
			if int(data.image.get("type",0))==3:
				image.hide()
				var fill=TextureProgressBar.new();fill.texture_progress=texture;fill.nine_patch_stretch=true;fill.size=extent;fill.max_value=1;fill.step=0.001;fill.value=float(data.image.get("fill_amount",1));fill.tint_progress=color(data.image.color);fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
				fill.fill_mode=TextureProgressBar.FILL_BOTTOM_TO_TOP if int(data.image.get("fill_method",0))==1 else TextureProgressBar.FILL_LEFT_TO_RIGHT
				if int(data.image.get("fill_origin",0))==1:fill.fill_mode=TextureProgressBar.FILL_TOP_TO_BOTTOM if int(data.image.get("fill_method",0))==1 else TextureProgressBar.FILL_RIGHT_TO_LEFT
				node.add_child(fill);fills[data.id]=fill
				for id in data.get("ids",[]):fills[id]=fill
	if data.has("text"):
		var label=Label.new();label.size=extent;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var content=str(data.text.content) if data.text.content!=null else ""
		if data.components.has("LocalizationTextActivator"):content=db.text(str(data.components.LocalizationTextActivator.IDString).strip_edges())
		label.text=content
		label.add_theme_font_size_override("font_size",maxi(8,roundi(float(data.text.font_size))))
		label.add_theme_color_override("font_color",color(data.text.color))
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT if int(data.text.alignment)==1 else (HORIZONTAL_ALIGNMENT_RIGHT if int(data.text.alignment)==4 else HORIZONTAL_ALIGNMENT_CENTER)
		label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if data.text.wrap else TextServer.AUTOWRAP_OFF
		label.clip_text=false
		label.set_meta("extent",extent)
		var material:Dictionary=font_materials.get(data.text.get("material",""),{})
		if not material.is_empty():
			label.add_theme_color_override("font_color",color(data.text.color)*color(material.face))
			label.add_theme_color_override("font_outline_color",color(material.outline))
			label.add_theme_constant_override("outline_size",roundi(float(material.width)*20))
		var font_path="res://assets/fonts/Perfect DOS VGA 437.ttf" if "Perfect" in str(data.text.font) and db.language=="English" else ("res://assets/fonts/LiberationSans.ttf" if db.language=="English" else "res://assets/fonts/NotoSansSC-Light.otf")
		label.add_theme_font_override("font",load(font_path));node.add_child(label);fit_label(label);labels[data.id]=label
		for id in data.get("ids",[]):labels[id]=label
	var arranged:Dictionary=arrange(data,extent)
	for child in data.children:build(child,node,extent,arranged.get(child.id))
	if data.name=="Arrow" and parent.name!="Back Button":node.visible=false
	if data.has("slider"):
		var slider=HSlider.new();slider.size=extent;slider.min_value=float(data.slider.min);slider.max_value=float(data.slider.max);slider.step=0.01;slider.value=float(data.slider.value)
		slider.value_changed.connect(func(value):action.call("SliderChanged",data.id,{"value":value}))
		for child in node.get_children():child.hide()
		node.add_child(slider);sliders[data.id]=slider
		for id in data.get("ids",[]):sliders[id]=slider
	if data.has("button"):
		var button=Button.new();button.flat=true;button.size=extent;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		var hover=StyleBoxFlat.new();hover.bg_color=Color(1,1,1,0.15);button.add_theme_stylebox_override("hover",hover)
		button.pressed.connect(func():
			for call in data.button:
				if str(call.get("m_MethodName",""))!="set_interactable":action.call(call.get("m_MethodName",""),data.id,call.get("m_Arguments",{})))
		var triggers:Dictionary=data.components.get("UITriggersController",data.components.get("UIFeedback",{}))
		button.focus_entered.connect(func():feedback(data.id,int(triggers.get("hoverAudioClip",72))))
		button.button_down.connect(func():feedback(data.id,int(triggers.get("downClickAudioClip",0))))
		button.mouse_entered.connect(func():
			feedback(data.id,int(triggers.get("hoverAudioClip",72)))
			for child in node.get_children():
				if child.name=="Arrow":child.visible=true)
		button.mouse_exited.connect(func():
			for child in node.get_children():
				if child.name=="Arrow":child.visible=false)
		node.add_child(button);buttons[data.id]=button
		for id in data.get("ids",[]):buttons[id]=button
func set_text(id:String,value:String):
	if labels.has(id):labels[id].text=value;fit_label(labels[id])

func set_fill(id:String,value:float):
	if fills.has(id):fills[id].value=clampf(value,0,1)

func show_node(id:String,value:bool):
	if controls.has(id):controls[id].visible=value
func set_image(id:String,sprite):
	if images.has(id):images[id].texture=db.sprite(sprite)
func set_slider(id:String,value:float,min_value:float=0,max_value:float=1):
	if sliders.has(id):
		sliders[id].min_value=min_value;sliders[id].max_value=max_value;sliders[id].set_value_no_signal(value)
func show_all_panels():
	for name in nodes_by_name:
		if "Panel" in name:nodes_by_name[name].visible=true

func arrange(data:Dictionary,extent:Vector2)->Dictionary:
	if not data.has("layout"):return {}
	var layout:Dictionary=data.layout
	var children:Array=data.children.filter(func(c):return c.active and not c.get("layout_element",{}).get("m_IgnoreLayout",false))
	if children.is_empty():return {}
	var pad:Dictionary=layout.m_Padding
	var left=float(pad.get("m_Left",0));var right=float(pad.get("m_Right",0));var top=float(pad.get("m_Top",0));var bottom=float(pad.get("m_Bottom",0))
	var spacing=float(layout.get("m_Spacing",0))
	var vertical=int(layout.m_Script.fileID)==1297475563
	var total=0.0
	for child in children:total+=float(child.size.get("y" if vertical else "x",0))
	var available=(extent.y-top-bottom if vertical else extent.x-left-right)-spacing*(children.size()-1)
	var extra=maxf(0,available-total)/children.size() if layout.get("m_ChildForceExpandHeight" if vertical else "m_ChildForceExpandWidth",false) else 0.0
	var cursor=top if vertical else left
	var result:Dictionary={}
	for child in children:
		var size=vector(child.size)
		if vertical:
			if layout.get("m_ChildControlWidth",false):size.x=extent.x-left-right
			if layout.get("m_ChildControlHeight",false):size.y+=extra
			result[child.id]=Rect2(Vector2(left,cursor),size)
			cursor+=size.y+spacing+(extra if not layout.get("m_ChildControlHeight",false) else 0)
		else:
			if layout.get("m_ChildControlHeight",false):size.y=extent.y-top-bottom
			if layout.get("m_ChildControlWidth",false):size.x+=extra
			result[child.id]=Rect2(Vector2(cursor,top),size)
			cursor+=size.x+spacing+(extra if not layout.get("m_ChildControlWidth",false) else 0)
	return result

func fit_label(label:Label):
	var extent:Vector2=label.get_meta("extent")
	if extent.x<10 or extent.y<10:
		var font=label.get_theme_font("font")
		var px=label.get_theme_font_size("font_size")
		label.size=font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).max(Vector2(extent.x,font.get_height(px)))
		label.position=(extent-label.size)/2

func set_binding_labels(bindings:Dictionary,joy:bool=false):
	var references:Dictionary=db.read_json("input_references")
	var defaults={"MoveUp":"W","MoveDown":"S","MoveLeft":"A","MoveRight":"D","Boost":"Shift","Shoot":"LMB","Build":"LMB","OpenBuild":"E","Radar":"RMB","MenuBack":"Esc","NextTip":"D","StartGame":"LMB","Submit":"Space","Cancel":"Esc"}
	if joy:defaults={"MoveUp":"LS ↑","MoveDown":"LS ↓","MoveLeft":"LS ←","MoveRight":"LS →","Boost":"LT","Shoot":"RT","Build":"RT","OpenBuild":"B","Radar":"A","MenuBack":"Start","NextTip":"LS →","StartGame":"RT","Submit":"A","Cancel":"B"}
	var actions={"MoveUp":"move_up","MoveDown":"move_down","MoveLeft":"move_left","MoveRight":"move_right","Boost":"boost","OpenBuild":"build","MenuBack":"pause","Radar":"radar"}
	for component in components.values():
		if not component.has("inputActionReference") or not component.has("bindingImage"):continue
		var action_name=references.get(component.inputActionReference.get("guid",""),"")
		var key=defaults.get(action_name,"")
		if not joy and actions.has(action_name) and bindings.has(actions[action_name]):key=OS.get_keycode_string(int(bindings[actions[action_name]]))
		if key=="":continue
		var image_id=str(int(component.bindingImage.fileID));var text_id=str(int(component.bindingTextObject.fileID));var label_id=str(int(component.bindingText.fileID))
		var icon_name={"LMB":"Mouse_Left_Key_Dark","RMB":"Mouse_Right_Key_Dark","Shift":"Left Shift","Escape":"Esc","A":"button_xbox_digital_a_1" if joy else "A","B":"button_xbox_digital_b_1" if joy else "B","Start":"button_xbox_digital_menu_1"}.get(key,key)
		var icon=""
		for id in db.sprites:
			if db.sprites[id].name==icon_name:icon=id;break
		show_node(image_id,icon!="");show_node(text_id,icon=="")
		if icon!="":set_image(image_id,icon)
		else:
			if images.has(text_id):images[text_id].hide()
			set_text(label_id,key)
			if labels.has(label_id):labels[label_id].add_theme_font_size_override("font_size",20)

func feedback(id:String,clip:int):
	if clip!=0:action.call("HoverFeedback",id,{"type":clip})
func collect_animations(data:Dictionary):
	var definition:Dictionary=data.get('components',{}).get('BindingUIAnimation',{})
	if not definition.is_empty() and controls.has(data.id):
		animation_nodes.append({'node':controls[data.id],'base':controls[data.id].scale,'config':definition,'time':0.0})
	for child in data.children:collect_animations(child)
func _process(dt):
	for item in animation_nodes:
		if not item.node.is_visible_in_tree():item.time=0.0;continue
		item.time+=dt
		var config:Dictionary=item.config;var duration=[0.25,0.5,1.0,1.5,3.0,6.0][int(config.get('tweenDuration',2))]
		var hold=int(config.get('bindingUIAnimationType',0))==1
		var phase=fposmod(item.time/duration,6.0 if hold else 3.0)
		var amount=1.0
		if phase>=1 and phase<2:amount=lerpf(1,0.75,phase-1)
		elif hold and phase>=2 and phase<5:amount=0.75
		elif phase>=2:amount=lerpf(0.75,1,phase-(5 if hold else 2))
		item.node.scale=item.base*amount
		if hold:
			var id=str(int(config.get('holdObject',{}).get('fileID',0)));show_node(id,phase>=2 and phase<5)
			var fill_id=str(int(config.get('holdImage',{}).get('fileID',0)))
			set_fill(fill_id,clampf(phase-3,0,1))
			if fills.has(fill_id):fills[fill_id].modulate.a=clampf(phase-2,0,1) if phase<4 else clampf(5-phase,0,1)
