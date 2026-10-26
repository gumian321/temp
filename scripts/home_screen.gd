extends RefCounted
const Guide = preload("res://scripts/field_guide.gd")
const Specimen = preload("res://scripts/field_specimen.gd")

static func build(game):
	var page: Control = game.panel
	var zh: bool = game.db.language.begins_with("Chinese")
	Guide.page(page)
	Guide.rule(page, Rect2(72, 61, 1296, 1))
	Guide.label(page, "C E N T I P E D E   /   逐 节 武 装", Rect2(74, 24, 650, 30), 15, Guide.MUTED)
	var edition = Guide.label(page, "FIELD NOTES     /     VOL. 01", Rect2(1040, 24, 328, 30), 15, Guide.MUTED)
	edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var specimen = Specimen.new()
	specimen.name = "HomeSpecimen"; specimen.character_id = str(game.save.state.selected_character); specimen.chinese = zh
	specimen.position = Vector2(530, 73); specimen.size = Vector2(800, 704)
	page.add_child(specimen)
	Guide.label(page, game.db.ui("ARMORED\nINSTINCT", "逐节\n武装"), Rect2(82, 105, 450, 247), 68 if zh else 54)
	Guide.label(page, game.db.ui("BURROW. ADAPT. SURVIVE.", "向深处去。活着回来。"), Rect2(86, 354, 410, 36), 21, Guide.MUTED)
	var deploy = Guide.button(page, game.db.ui("DEPLOY", "出击"), Rect2(80, 426, 398, 74), game.show_missions, true, 32)
	deploy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	Guide.label(deploy, "01    →", Rect2(280, 20, 95, 40), 22, Guide.ACCENT).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var nest = Guide.button(page, game.db.ui("INSECT NEST", "虫巢"), Rect2(80, 515, 398, 58), game.show_characters, false, 25)
	nest.alignment = HORIZONTAL_ALIGNMENT_LEFT
	Guide.label(nest, "02", Rect2(325, 15, 50, 32), 17, Guide.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var evolution = Guide.button(page, game.db.ui("RESEARCH", "进化"), Rect2(80, 582, 188, 55), game.show_lab, false, 22)
	evolution.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var settings = Guide.button(page, game.db.ui("SETTINGS", "设置"), Rect2(290, 582, 188, 55), game.show_options, false, 22)
	settings.alignment = HORIZONTAL_ALIGNMENT_LEFT
	Guide.button(page, game.db.ui("FIELD LOG", "记录"), Rect2(80, 654, 188, 40), game.show_changelog, false, 16)
	Guide.button(page, game.db.ui("QUIT", "退出"), Rect2(290, 654, 188, 40), game.safe_shutdown, false, 16)
	# Requested development actions remain directly reachable but secondary.
	game.debug_unlock_button = Guide.button(page, game.db.ui("DEBUG · UNLOCK ALL", "DEBUG · 一键全开"), Rect2(80, 716, 398, 34), game.debug_unlock_all_content, false, 15)
	game.debug_unlock_button.name = "DebugUnlockAll"
	game.debug_unlock_button.tooltip_text = game.db.ui("Unlock all characters, skills and evolutions, then save.", "解锁全部角色、技能和进化内容，并保存。")
	game.debug_reset_skills_button = Guide.button(page, game.db.ui("DEBUG · RESET SKILLS", "DEBUG · 恢复初始技能"), Rect2(80, 758, 398, 34), game.debug_reset_skill_progress, false, 15)
	game.debug_reset_skills_button.name = "DebugResetSkills"
	game.debug_reset_skills_button.tooltip_text = game.db.ui("Restore initial skills and filters; top up to 10,000 RP. Keep characters, missions and records.", "恢复初始技能和筛选，进化点补到至少 10,000；保留角色、关卡和成绩。")
	for button in [game.debug_unlock_button, game.debug_reset_skills_button]:
		button.add_theme_color_override("font_color", Guide.MUTED)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	Guide.rule(page, Rect2(72, 818, 1296, 1))
	game.home_points_label = Guide.label(page, str(game.save.state.meta), Rect2(82, 837, 200, 36), 24)
	Guide.label(page, game.db.ui("EVOLUTION / RP", "进化点 / RP"), Rect2(292, 843, 210, 30), 16, Guide.MUTED)
	var spider: bool = specimen.character_id == "spider"
	Guide.label(page, game.db.ui("SPECIMEN 02   /   SPIDER" if spider else "SPECIMEN 01   /   CENTIPEDE", "标本 02   /   蜘蛛" if spider else "标本 01   /   蜈蚣"), Rect2(626, 757, 680, 35), 22)
	Guide.label(page, game.db.ui("EIGHT LIMBS. ONE HUNTING INSTINCT." if spider else "EVERY SEGMENT, A NEW INSTINCT.", "八足延展，牵丝猎食。" if spider else "每一节身体，都是新的生存本能。"), Rect2(626, 792, 700, 25), 16, Guide.MUTED)
	Guide.label(page, game.db.ui("GROW  /  ARM  /  DESCEND", "生长   /   武装   /   下潜"), Rect2(985, 843, 365, 30), 16, Guide.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
