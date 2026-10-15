extends RefCounted
## Generated rank artwork; live values remain accessible, bold text.
const UI=preload("res://scripts/game_ui.gd")
const GLYPHS=preload("res://assets/ui_overhaul/ranks/neon_rank_glyphs.png")
const REGIONS={"S":Rect2(68,87,357,335),"A":Rect2(471,88,401,334),"B":Rect2(915,89,389,334),"C":Rect2(1364,89,343,334),"D":Rect2(48,497,394,329),"F":Rect2(502,496,370,330),"+":Rect2(947,510,354,309),"-":Rect2(1370,598,363,134)}
static var textures:Dictionary={}

static func glyph(key:String)->AtlasTexture:
	if not textures.has(key):
		var texture=AtlasTexture.new();texture.atlas=GLYPHS;texture.region=REGIONS[key];texture.filter_clip=true
		textures[key]=texture
	return textures[key]

static func text(parent:Control,value:String,rect:Rect2,size:int=24,color:Color=UI.TEXT,align:int=HORIZONTAL_ALIGNMENT_LEFT)->Label:
	var label=UI.label(parent,value,rect.position,size,color)
	label.size=rect.size;label.horizontal_alignment=align;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.clip_text=true;label.tooltip_text=value
	return label

static func build(game,rows:Array)->Control:
	var root=Control.new();root.name="ResultScreen";root.size=Vector2(1440,900)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.panel.add_child(root);UI.protect(root)
	root.set_meta("grade",str(game.run.result.grade))
	UI.panel(root,Rect2(70,154,510,586),UI.TEAL)
	UI.panel(root,Rect2(608,154,754,130),UI.AMBER)
	UI.panel(root,Rect2(608,308,754,432),UI.TEAL)
	text(root,game.db.ui("PERFORMANCE","战斗评级"),Rect2(100,176,450,42),22,UI.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var badge=Control.new();badge.name="RankBadge";badge.position=Vector2(98,230);badge.size=Vector2(454,244);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(badge)
	badge.tooltip_text=str(game.run.result.grade)
	var grade=str(game.run.result.grade)
	var total=0.0
	for key in grade:
		if REGIONS.has(key):total+=(0.48 if key in ["+","-"] else REGIONS[key].size.x/REGIONS[key].size.y)
	var height=minf(232.0,430.0/maxf(total+0.035*(grade.length()-1),1.0))
	var x=(454.0-(total+0.035*(grade.length()-1))*height)*0.5
	for key in grade:
		if not REGIONS.has(key):continue
		var w=height*(0.48 if key in ["+","-"] else REGIONS[key].size.x/REGIONS[key].size.y)
		var h=w*REGIONS[key].size.y/REGIONS[key].size.x
		var image=TextureRect.new();image.texture=glyph(key);image.name="Glyph"+str(badge.get_child_count());image.set_meta("glyph",key)
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.position=Vector2(x,(244-h)*0.5);image.size=Vector2(w,h);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.add_child(image)
		x+=w+height*0.035
	badge.pivot_offset=badge.size*0.5;badge.scale=Vector2.ONE*0.84;badge.modulate.a=0
	var tween=badge.create_tween().set_parallel(true)
	tween.tween_property(badge,"scale",Vector2.ONE,0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge,"modulate:a",1.0,0.2)
	text(root,game.db.ui("TOTAL SCORE","总评分"),Rect2(100,505,450,38),22,UI.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	var score=text(root,str(game.run.result.score),Rect2(90,546,470,82),60,UI.TEXT,HORIZONTAL_ALIGNMENT_CENTER);score.name="Score"
	var seconds=int(game.run.result.get("time",0))
	text(root,game.db.ui("TIME %02d:%02d   ·   DEFEATED %d","用时 %02d:%02d   ·   击败 %d")%[seconds/60,seconds%60,int(game.run.result.get("kills",0))],Rect2(96,657,458,38),20,UI.MUTED,HORIZONTAL_ALIGNMENT_CENTER).name="RunSummary"
	UI.icon(root,"meta",Vector2(638,192),48,UI.AMBER)
	text(root,game.db.ui("RESEARCH EARNED","获得研究点"),Rect2(706,174,360,36),22,UI.MUTED)
	text(root,"+"+str(game.run.result.meta),Rect2(706,210,570,60),44,UI.AMBER).name="MetaReward"
	text(root,game.db.ui("SCORE BREAKDOWN","评分明细"),Rect2(640,326,650,38),22,UI.MUTED)
	for i in range(rows.size()):
		var y=376+i*47
		var row=Control.new();row.name="Breakdown"+str(i);row.position=Vector2(640,y);row.size=Vector2(690,45);row.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(row)
		row.set_meta("value",int(rows[i].value));row.set_meta("title",str(rows[i].title))
		text(row,str(rows[i].title),Rect2(0,0,480,45),23,UI.TEXT).name="Title"
		text(row,str(rows[i].value),Rect2(490,0,200,45),27,UI.TEXT,HORIZONTAL_ALIGNMENT_RIGHT).name="Value"
	if rows.is_empty():text(root,game.db.ui("NO SCORE THIS RUN","本次未获得评分"),Rect2(640,400,650,48),25,UI.MUTED)
	UI.button(root,game.db.ui("BASE","基地"),Rect2(70,786,290,76),game.show_menu,"back").name="BaseButton"
	UI.button(root,game.db.ui("EVOLVE","进化"),Rect2(670,786,320,76),game.show_lab,"research").name="EvolveButton"
	UI.button(root,game.db.ui("AGAIN","再战"),Rect2(1020,786,342,76),game.begin_run,"play",UI.AMBER).name="AgainButton"
	return root
