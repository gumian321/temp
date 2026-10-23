extends SceneTree
const UI=preload("res://scripts/game_ui.gd")
const Art=preload("res://scripts/generated_ui_art.gd")
var checks=[]
func check(ok:bool,label:String):
 checks.append({"name":label,"passed":ok})
 if not ok:push_error(label)
func contrast(foreground:Color,background:Color)->float:
 var a=background.blend(foreground).srgb_to_linear().get_luminance()
 var b=background.srgb_to_linear().get_luminance()
 return (maxf(a,b)+.05)/(minf(a,b)+.05)
func _initialize():call_deferred("execute")
func execute():
 var parent=Control.new();root.add_child(parent)
 for key in Art.KEYS:
  var graphic=UI.icon(parent,key,Vector2.ZERO,38)
  check(graphic.size==Vector2(38,38),"Actual raster node stays inside 38px: "+key)
 parent.theme=UI.theme()
 for width in [192,240]:
  var button=UI.button(parent,"战利品",Rect2(0,0,width,52),func():pass,"reward")
  await process_frame
  var artwork=button.get_child(0) as TextureRect
  var label_width=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
  check(button.size==Vector2(width,52),"Loot button retains actual bounds at "+str(width)+"px")
  for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
   var skin=button.get_theme_stylebox(state)
   var label_left=skin.content_margin_left+(button.size.x-skin.content_margin_left-skin.content_margin_right-label_width)/2.0
   check(label_left>=artwork.position.x+artwork.size.x+12,"Loot label clears actual icon by12px at "+str(width)+"px / "+state)
 parent.queue_free()
 var theme=UI.theme()
 check(theme.default_font.get_font_weight()>=600,"Readable bold font is the UI default")
 for code in "蜈蚣护甲身体无人机燃料进化图鉴设置开始远征0123456789":
  check(theme.default_font.has_char(code.unicode_at(0)),"Bold font covers "+code)
 for key in Art.KEYS:
  var icon=UI.icon_texture(key)
  check(icon is AtlasTexture and icon.get_width()>0,"Generated raster icon: "+key)
 for key in ["normal","active","hud","panel"]:
  check(Art.skin(key) is StyleBoxTexture and Art.skin(key).texture is AtlasTexture,"Generated raster skin: "+key)
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
  var color=theme.get_color(state,"Button")
  check(color.get_luminance()>.8 and color.a>0.99,"Opaque near-white text in button "+state)
 check(UI.BG.get_luminance()<.1 and UI.PANEL.get_luminance()<.15 and absf(UI.PANEL.r-UI.PANEL.b)<.03,"Shell backgrounds retain the dark charcoal palette")
 for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
  var box=theme.get_stylebox(state,"Button")
  check(box is StyleBoxFlat,"Charcoal button uses a flat plate: "+state)
  if box is StyleBoxFlat:
   var fill=UI.BG.blend(box.bg_color)
   var text_color=theme.get_color("font_disabled_color" if state=="disabled" else "font_color","Button")
   check(contrast(text_color,fill)>=4.5,"Button text meets WCAG 4.5 contrast: "+state)
   check(box.corner_radius_top_left>0 and box.corner_radius_top_left<=12 and box.border_width_top<=2,"Button has compact corners and a restrained rim: "+state)
 check(not theme.get_stylebox("focus","Button").draw_center,"Focus ring does not repaint button content")
 var active=UI.card_style(true)
 check(active is StyleBoxFlat and active.border_color==UI.TEAL and active.border_color!=UI.card_style(false).border_color,"Selected card remains distinguishable from an inactive card")
 check(UI.TEAL.r>.8 and UI.TEAL.g<.2 and UI.TEAL.b>.2,"Primary accent remains a sparse rose cue in the charcoal shell")
 check(contrast(UI.TEXT,UI.PANEL)>=4.5 and contrast(UI.MUTED,UI.PANEL)>=4.5,"Primary and secondary panel text meet WCAG 4.5")
 check(contrast(UI.TOOLTIP_TEXT,UI.TOOLTIP_BG)>=4.5,"Tooltip text meets WCAG 4.5")
 check(theme.get_color("font_color","TooltipLabel")==UI.TOOLTIP_TEXT,"Tooltip white text remains explicit")
 check(theme.get_stylebox("panel","TooltipPanel").bg_color==UI.TOOLTIP_BG,"Tooltip dark purple remains explicit")
 var label=Label.new();UI.protect(label);label.add_theme_color_override("font_color",UI.TEAL)
 preload("res://scripts/blue_ink.gd").style_item(label)
 check(label.get_theme_color("font_color")==UI.TEAL,"Legacy deferred ink styling respects protected UI")
 label.free()
 var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
 FileAccess.open("res://artifacts/generated-light-ui-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print(JSON.stringify(report));quit(0 if report.passed else 1)
