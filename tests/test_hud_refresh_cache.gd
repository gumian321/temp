extends SceneTree
const HUD=preload("res://scripts/battle_hud.gd")
class CountedUI extends "res://scripts/source_ui.gd":
 var fits=0
 func fit_label(label:Label):
  fits+=1
  super.fit_label(label)
var failures=0
func check(value:bool,message:String):
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("execute")
func execute():
 var meter=HUD.Meter.new("armor",HUD.TEAL,Vector2(244,38));root.add_child(meter)
 meter.reading(75,100,"75 / 100")
 var changes=[0];meter.amount.theme_changed.connect(func():changes[0]+=1)
 var start=Time.get_ticks_usec()
 for i in 10000:meter.reading(75,100,"75 / 100")
 var meter_us=Time.get_ticks_usec()-start
 var stable_meter_theme_events=changes[0]
 check(changes[0]==0,"Unchanged meter must not send theme notifications")
 meter.reading(20,100,"20 / 100")
 check(meter.warning and meter.amount.text=="20 / 100" and is_equal_approx(meter.bar.value,.2),"Damage updates value, fill and warning immediately")
 check(meter.amount.get_theme_color("font_color")==HUD.ALERT,"Warning color updates")
 meter.reading(80,100,"80 / 100")
 check(not meter.warning and meter.amount.get_theme_color("font_color")==HUD.INK,"Healing clears warning immediately")
 meter.reading(NAN,0,"—");check(meter.bar.value==0,"Invalid capacity stays finite")
 var ui=CountedUI.new();root.add_child(ui)
 var label=Label.new();label.set_meta("extent",Vector2(100,24));label.text="01:00";ui.add_child(label);ui.labels["test"]=label
 ui.fit_label(label)
 # Settle initial theme/size notifications before measuring stable refreshes.
 await process_frame;await process_frame;ui.set_text("test","01:00")
 var before=ui.fits;start=Time.get_ticks_usec()
 for i in 10000:ui.set_text("test","01:00")
 var source_us=Time.get_ticks_usec()-start
 var stable_source_fit_calls=ui.fits-before
 check(ui.fits==before,"Stable text must not repeat font measurements")
 ui.set_text("test","耐久：75 / 100")
 check(ui.fits==before+1 and label.text=="耐久：75 / 100","Language/text update refits immediately")
 before=ui.fits;label.set_meta("extent",Vector2(40,16));ui.set_text("test",label.text)
 check(ui.fits==before+1,"Extent change invalidates fit")
 before=ui.fits;label.add_theme_font_override("font",SystemFont.new());ui.set_text("test",label.text)
 check(ui.fits==before+1,"Font/theme change invalidates unchanged text")
 before=ui.fits;label.size+=Vector2(15,15);ui.set_text("test",label.text)
 check(ui.fits==before+1,"Resize invalidates unchanged text")
 before=ui.fits;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;ui.set_text("test",label.text)
 check(ui.fits==before+1,"Wrap change invalidates unchanged text")
 print(JSON.stringify({"passed":failures==0,"meter_10000_us":meter_us,"stable_meter_theme_events":stable_meter_theme_events,"source_text_10000_us":source_us,"stable_source_fit_calls":stable_source_fit_calls}))
 meter.queue_free();ui.queue_free();quit(failures)
