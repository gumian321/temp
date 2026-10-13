extends SceneTree
const Art = preload("res://scripts/insect_armaments.gd")
const Ink = preload("res://scripts/blue_ink.gd")
class Sheet extends Node2D:
	var font: Font = load("res://assets/fonts/NotoSansSC-Light.otf")
	func _draw():
		draw_rect(Rect2(0,0,1536,984),Color("111d30"))
		draw_string(font,Vector2(28,41),"虫器官武装  /  33 种独立轮廓",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("f4e8cb"))
		draw_string(font,Vector2(28,72),"上：主图标  ·  下：36 / 56 像素实装比例  ·  名称与装配、奖励、研究及战斗同步",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("8ca5b6"))
		var keys = Art.entries().keys()
		for i in keys.size():
			var key = keys[i]
			var origin = Vector2(21+(i%9)*167,99+(i/9)*216)
			draw_style_box(Ink.box(Color("192b40"),Color("31465b"),1),Rect2(origin,Vector2(157,205)))
			var texture = Art.texture(key)
			if texture == null: continue
			var big = Ink.fitted_size(texture,Vector2(128,111))
			draw_texture_rect(texture,Rect2(origin+Vector2(78,62)-big/2,big),false)
			draw_string(font,origin+Vector2(12,136),Art.entries()[key].zh,HORIZONTAL_ALIGNMENT_CENTER,133,18,Color("f4e8cb"))
			for j in range(2):
				var small = Ink.fitted_size(texture,Vector2.ONE*[36,56][j])
				draw_texture_rect(texture,Rect2(origin+Vector2(47+j*67,172)-small/2,small),false)
func _initialize(): call_deferred("execute")
func execute():
	# A fixed offscreen viewport avoids project canvas stretch and desktop window limits.
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1536,984)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var node = Sheet.new()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	viewport.add_child(node)
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		printerr("Visual lineup requires a renderer; use xvfb-run Godot.")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	var error = viewport.get_texture().get_image().save_png("res://artifacts/insect-armaments-33-lineup.png")
	print("INSECT_LINEUP ",error == OK)
	quit(0 if error == OK else 1)
